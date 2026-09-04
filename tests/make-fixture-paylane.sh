#!/usr/bin/env bash
# Builds the `paylane` fixture: a cut-down payment-methods service with the shape that the skill is
# about — one value (the set of allowed payment methods) computed in three places, an artifact the
# full pipeline already wrote, and degenerate rows that break the obvious design.
#
#   tests/make-fixture.sh /path/to/dir
#
# Planted:
#   - pipeline/confirm.py applies stage x type-policy x provider-health and stores the result in
#     order_payment.all_methods; catalog.py uses stage only; accept.py uses stage x policy.
#   - o-collapsed: snapshot rewritten down to the chosen method   (a snapshot-only design breaks)
#   - o-stale:     snapshot older than a policy change and an outage
#   - o-nosnap:    confirmed by an older code path, no snapshot at all
#   - o-sub:       stage allows sbp, the platform policy for this type does not (the visible bug)
#   - credit:      allowed by stage and by policy, provider is down — only the pipeline knows
set -euo pipefail
DIR="${1:?usage: make-fixture.sh DIR}"
mkdir -p "$DIR/pipeline"
cat > "$DIR/seed.py" <<'EOF_SEED_PY'
#!/usr/bin/env python3
"""Build paylane.sqlite. Run: python3 seed.py"""
import json, os, sqlite3

DB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "paylane.sqlite")
if os.path.exists(DB):
    os.remove(DB)
c = sqlite3.connect(DB)
c.executescript("""
CREATE TABLE orders (id TEXT PRIMARY KEY, status TEXT, type TEXT, stage_code TEXT, confirmed_at TEXT);
CREATE TABLE order_payment (order_id TEXT PRIMARY KEY, method TEXT, all_methods TEXT, computed_at TEXT);
CREATE TABLE stage_methods (stage_code TEXT, method TEXT);
CREATE TABLE type_methods (order_type TEXT, method TEXT);
CREATE TABLE provider_health (method TEXT PRIMARY KEY, up INTEGER);
""")
stage = [("ST_RETAIL", m) for m in ("card", "sbp", "cash_on_delivery", "card_on_delivery", "credit")] + \
        [("ST_B2B", m) for m in ("invoice", "card", "credit")] + \
        [("ST_SUB", m) for m in ("card", "sbp")]
c.executemany("INSERT INTO stage_methods VALUES (?,?)", stage)
# platform policy per order type: this is what the stage codes do NOT know about
typ = [("retail", m) for m in ("card", "sbp", "cash_on_delivery", "credit")] + \
      [("b2b", m) for m in ("invoice", "card")] + \
      [("subscription", m) for m in ("card",)]
c.executemany("INSERT INTO type_methods VALUES (?,?)", typ)
c.executemany("INSERT INTO provider_health VALUES (?,?)", [("card",1),("sbp",1),("invoice",1),
                                                           ("cash_on_delivery",1),("card_on_delivery",1),("credit",0)])
orders = [
    # (id, status, type, stage, confirmed_at, snapshot method, snapshot all_methods, computed_at)
    ("o-normal",    "awaiting_payment", "retail", "ST_RETAIL", "2026-08-30T10:00:00",
     "card", ["card", "sbp", "cash_on_delivery"], "2026-08-30T10:00:00"),
    # collapsed: the snapshot was rewritten on payment start and left only the chosen method
    ("o-collapsed", "awaiting_payment", "retail", "ST_RETAIL", "2026-08-30T11:00:00",
     "sbp", ["sbp"], "2026-08-30T11:20:00"),
    # stale: written before the credit provider went down and before the b2b policy change
    ("o-stale",     "awaiting_payment", "b2b",    "ST_B2B",    "2026-06-01T09:00:00",
     "invoice", ["invoice", "card", "credit"], "2026-06-01T09:00:00"),
    # no snapshot at all: confirmed by an older code path
    ("o-nosnap",    "awaiting_payment", "retail", "ST_RETAIL", "2026-07-15T08:00:00", None, None, None),
    # subscription: the stage allows sbp, the platform policy for this type does not
    ("o-sub",       "awaiting_payment", "subscription", "ST_SUB", "2026-08-31T12:00:00",
     "card", ["card"], "2026-08-31T12:00:00"),
    ("o-draft",     "draft",            "retail", "ST_RETAIL", None, None, None, None),
    ("o-paid",      "paid",             "retail", "ST_RETAIL", "2026-08-20T10:00:00",
     "card", ["card"], "2026-08-20T10:00:00"),
]
for oid, st, tp, stg, conf, meth, alls, comp in orders:
    c.execute("INSERT INTO orders VALUES (?,?,?,?,?)", (oid, st, tp, stg, conf))
    if meth is not None:
        c.execute("INSERT INTO order_payment VALUES (?,?,?,?)", (oid, meth, json.dumps(alls), comp))
c.commit()
print(f"seeded {DB}: {len(orders)} orders")
EOF_SEED_PY

cat > "$DIR/catalog.py" <<'EOF_CATALOG_PY'
"""What the order page shows as available payment methods (the UI reads this)."""
import sqlite3


def catalog(db: sqlite3.Connection, order_id: str) -> list[str]:
    o = db.execute("SELECT stage_code FROM orders WHERE id=?", (order_id,)).fetchone()
    if not o:
        return []
    return sorted(r[0] for r in db.execute("SELECT method FROM stage_methods WHERE stage_code=?", (o[0],)))
EOF_CATALOG_PY

cat > "$DIR/accept.py" <<'EOF_ACCEPT_PY'
"""Whether a method the user picked can be accepted (called when the payment is started)."""
import sqlite3


def can_accept(db: sqlite3.Connection, order_id: str, method: str) -> bool:
    o = db.execute("SELECT type, stage_code FROM orders WHERE id=?", (order_id,)).fetchone()
    if not o:
        return False
    order_type, stage_code = o
    stage = {r[0] for r in db.execute("SELECT method FROM stage_methods WHERE stage_code=?", (stage_code,))}
    policy = {r[0] for r in db.execute("SELECT method FROM type_methods WHERE order_type=?", (order_type,))}
    return method in (stage & policy)
EOF_ACCEPT_PY

cat > "$DIR/pipeline/confirm.py" <<'EOF_CONFIRM_PY'
"""Order confirmation. The only place where the full payment-method pipeline runs.

Called from the checkout flow when an order leaves `draft`. Every filter the platform has is
applied here, in this order, and the result is stored in order_payment.all_methods so the rest
of the system does not have to redo it.
"""
import json
import sqlite3


def allowed_methods(db: sqlite3.Connection, order_id: str) -> list[str]:
    o = db.execute("SELECT type, stage_code FROM orders WHERE id=?", (order_id,)).fetchone()
    if not o:
        return []
    order_type, stage_code = o
    stage = {r[0] for r in db.execute("SELECT method FROM stage_methods WHERE stage_code=?", (stage_code,))}
    policy = {r[0] for r in db.execute("SELECT method FROM type_methods WHERE order_type=?", (order_type,))}
    healthy = {r[0] for r in db.execute("SELECT method FROM provider_health WHERE up=1")}
    return sorted(stage & policy & healthy)


def confirm(db: sqlite3.Connection, order_id: str, chosen: str, now: str) -> None:
    methods = allowed_methods(db, order_id)
    db.execute("UPDATE orders SET status='awaiting_payment', confirmed_at=? WHERE id=?", (now, order_id))
    db.execute("INSERT OR REPLACE INTO order_payment VALUES (?,?,?,?)",
               (order_id, chosen, json.dumps(methods), now))
    db.commit()
EOF_CONFIRM_PY

cat > "$DIR/README.md" <<'EOF_README_MD'
# paylane

A cut-down payment-methods service.

- `pipeline/confirm.py` — order confirmation: the checkout flow calls it when an order leaves `draft`.
- `catalog.py` — the list of methods shown on the order page.
- `accept.py` — the check run when the user starts a payment with a chosen method.
- `seed.py` — rebuilds `paylane.sqlite` (7 orders, degenerate rows included).

```bash
python3 seed.py
python3 -c "import sqlite3,catalog; print(catalog.catalog(sqlite3.connect('paylane.sqlite'),'o-normal'))"
sqlite3 paylane.sqlite '.tables'
```

Tables: `orders`, `order_payment`, `stage_methods`, `type_methods`, `provider_health`.
EOF_README_MD

cat > "$DIR/PLAN.md" <<'EOF_PLAN_MD'
# Plan (from the previous session — design agreed)

The order page shows methods that the payment start then refuses. Fix:

1. In `catalog.py`, intersect the stage list with `type_methods` for the order's type.
2. Add a test for `o-sub` (subscription must not show `sbp`).
3. Leave `accept.py` alone — it already intersects both sets.
EOF_PLAN_MD

cd "$DIR" && python3 seed.py
echo "fixture ready: $DIR"
