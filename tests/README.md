# Testing the skill

This skill is about discipline: a model knows these techniques and skips them under the pressure of
a design that is already settled. So it is tested the way discipline skills are tested — the same
prompt is run twice, without the skill (baseline) and with it, and what is compared is not the
quality of the prose but the behaviour.

```bash
tests/make-fixture-deplock.sh /tmp/efd/deplock     # dependency resolution
tests/make-fixture-paylane.sh /tmp/efd/paylane     # payment methods
# then two agents per scenario, the SAME model for both:
#   baseline: the task only
#   skill:    "first read <repo>/SKILL.md and work strictly by it", then the task
```

Each agent gets its own copy of the fixture (agents write into it), a budget of about 25 tool calls,
and a fixed answer shape: `## План` / `## Что я проверил` / `## Риски`. Do not ask for an
implementation: what is being tested is what happens **before** the code.

## The two fixtures

Both have the same shape and share no domain: one value computed in three places, an artifact the
full pipeline already wrote, degenerate inputs that break the obvious design, and an inherited
`PLAN.md` dictating a plausible but incomplete fix. In both, **neither obvious design is right on
its own** — the answer is a hybrid, which is what makes step 1 a hypothesis rather than an
instruction.

### `deplock` — dependency resolution

The value is "the version of package P this project actually builds with". It is a map produced by
**precedence**, not a set produced by intersection, so "intersect one more table" is not even
expressible as the answer.

| Place | What it applies | Writes? |
|---|---|---|
| `pipeline/install.py` | range × registry × not-yanked × platform, then **overrides win outright**, even outside the range | **writes `.buildcache/resolved.json`** on install |
| `check.py` (CI drift gate) | range × registry × not-yanked | no |
| `render_sbom.py` (release report) | range × registry | no |

Degenerate entries: `hotfix-http` (resolved by an override to a version outside the manifest range),
`legacy-xml` (locked to a version yanked afterwards; re-resolving returns nothing at all),
`winmetrics` (win32-only, so absent from a linux lock — absence with a healthy cause), `plotkit` (in
the lockfile, removed from the manifest), `dataframe` (in the manifest, absent from the lockfile),
`netclient` (`"version": null` with a git ref — degenerate form, healthy origin). `corelib` is the
boring row where everything agrees.

Staleness is objectively checkable here: `install.py::manifest_hash` recomputed over today's
`manifest.json` does not match the hash stored in the lockfile.

The trap: the fix `PLAN.md` dictates drops the `hotfix-http` override, so the SBOM would report
1.9.3 while the build ships 2.0.1; reading the lockfile alone keeps installing the removed `plotkit`,
misses `dataframe` and crashes on `netclient`'s null version.

### `paylane` — payment methods

The value is the set of payment methods available on an order.

| Place | What it applies | Writes? |
|---|---|---|
| `pipeline/confirm.py` | stage × order-type policy × provider health | **writes `order_payment.all_methods`** on confirmation |
| `catalog.py` (display) | stage only | no |
| `accept.py` (accept) | stage × type policy | no |

Degenerate rows: `o-collapsed` (snapshot rewritten down to the chosen method), `o-stale` (snapshot
older than a policy change and an outage), `o-nosnap` (confirmed by an older code path, no snapshot),
`o-sub` (the stage allows `sbp`, the type policy does not). Separately: `credit` is allowed by both
the stage and the policy, but its provider is down — only the confirmation pipeline knows.

Here staleness is **not** expressible: `stage_methods`, `type_methods` and `provider_health` have no
version or timestamp column, so nothing says when the snapshot's inputs last changed. That is the
fixture's deepest point, and the reason its correct answer is a hybrid rather than snapshot-only.

The trap: intersecting stage with the type policy (what `PLAN.md` asks for) still ships `credit`;
reading only the snapshot breaks on every degenerate row.

## Scenarios

| # | Prompt | What it tests |
|---|---|---|
| A | the fix is dictated in the prompt itself | step 1 under the pressure of a ready-made solution |
| B | an open design task, no plan given | steps 3–4: invariant, single source, matrix |
| C | "continue from the previous session, the design is agreed and written in `PLAN.md`" | the plan-inertia section |

## Pass criteria

Fixture-independent, graded binary, registered before any run:

1. **Inventory.** The already-computed artifact is named, **with who writes it and when**. Naming
   the file without its writer does not count.
2. **Worst inputs.** At least three degenerate inputs are read and answered in writing: what would
   my construction return here.
3. **The missed rule.** The rule that the fix proposed in the prompt or the plan drops is named,
   together with where it is visible.
4. **Invariant.** It is stated that the consumers compute one value in different ways, and one
   source is proposed for all of them.
5. **Fifth**, by scenario — A: the artifact is applied as a hypothesis, not as an instruction
   (measured, then deliberately adopted **or** deliberately rejected on the evidence); B: the matrix
   is enumerated and the uncovered cell named; C: the inherited plan is rebuilt from step 1 rather
   than executed.

Score each criterion on its own. An earlier version of criterion 5 for scenario C was conjunctive —
it also demanded that a named line of the plan be called an error — and the 2026-09-05 runs showed
why that is unsound: on `deplock` the plan's "leave `pipeline/install.py` alone" is a legitimate
constraint that the correct design satisfies by *calling* the resolver rather than editing it. A
criterion that bakes in one expected answer measures the fixture, not the behaviour. See `results.md`.

Measured runs: `results.md`.
