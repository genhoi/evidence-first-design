#!/usr/bin/env bash
# Builds the `deplock` fixture: a cut-down dependency resolver with the same shape as the skill's
# other fixture, in a domain that shares nothing with it — no money, no orders, no user data.
#
#   tests/make-fixture-deplock.sh /path/to/dir
#
# One value ("the version of package P this project actually builds with") computed three ways:
#   pipeline/install.py  range x registry x not-yanked x platform, then OVERRIDES WIN OUTRIGHT
#                        -- and it writes the result to .buildcache/resolved.json
#   check.py             range x registry x not-yanked                  (CI drift gate)
#   render_sbom.py       range x registry                               (release report)
#
# Degenerate entries:
#   hotfix-http  resolved by an override to a version OUTSIDE the manifest range
#   legacy-xml   locked to a version yanked after the lock was written; re-resolving returns nothing
#   winmetrics   win32-only, so it has no entry at all on this linux lock
#   plotkit      in the lockfile, removed from the manifest      (provable via manifest_hash)
#   dataframe    in the manifest, never installed, absent from the lockfile
#   netclient    "version": null with a git ref -- degenerate form, healthy origin
#   corelib      the boring row where everything agrees
#
# The lockfile is written as a literal, NOT by running install.py: a freshly generated one would
# destroy every staleness row.
set -euo pipefail
DIR="${1:?usage: make-fixture-deplock.sh DIR}"
mkdir -p "$DIR/pipeline" "$DIR/.buildcache"

cat > "$DIR/registry.json" <<'EOF_REGISTRY'
{
  "corelib":      {"versions": {"5.1.0": {}, "5.2.0": {}}},
  "hotfix-http":  {"versions": {"1.9.3": {}, "2.0.1": {}}},
  "legacy-xml":   {"versions": {"0.9.0": {"yanked": true, "yanked_at": "2026-08-12"}, "1.2.0": {}}},
  "winmetrics":   {"platform": "win32", "versions": {"3.4.0": {}}},
  "plotkit":      {"versions": {"4.0.0": {}}},
  "dataframe":    {"versions": {"2.2.0": {}, "2.3.0": {}}},
  "netclient":    {"versions": {"1.0.0": {}}}
}
EOF_REGISTRY

cat > "$DIR/manifest.json" <<'EOF_MANIFEST'
{
  "platform": "linux",
  "requires": {
    "corelib": "^5.1",
    "hotfix-http": "^1.4",
    "legacy-xml": "^0.9",
    "winmetrics": "^3.0",
    "netclient": "^1.0",
    "dataframe": "^2.2"
  },
  "overrides": {
    "hotfix-http": "2.0.1"
  }
}
EOF_MANIFEST

cat > "$DIR/semver.py" <<'EOF_SEMVER'
"""Minimal semver helpers shared by every consumer, so the three differ in their FILTERS, not here."""


def parse(v: str) -> tuple[int, int, int]:
    major, minor, patch = (v.split("-")[0].split(".") + ["0", "0"])[:3]
    return int(major), int(minor), int(patch)


def satisfies(version: str, spec: str) -> bool:
    """Supports `^X.Y` only: >= X.Y.0, and < X+1.0.0 (or < X.Y+1.0 when X is 0)."""
    if not spec.startswith("^"):
        return version == spec
    lo = parse(spec[1:])
    v = parse(version)
    if v < lo:
        return False
    hi = (lo[0] + 1, 0, 0) if lo[0] > 0 else (0, lo[1] + 1, 0)
    return v < hi


def highest(versions: list[str]) -> str | None:
    return max(versions, key=parse) if versions else None
EOF_SEMVER

cat > "$DIR/pipeline/install.py" <<'EOF_INSTALL'
"""Installation. The only place where the full resolution pipeline runs.

`deplock install` calls this. Every rule the project has is applied here, in this order, and the
result is written to .buildcache/resolved.json so nothing else has to redo the work:

    manifest range -> registry -> drop yanked -> drop packages for another platform
    -> overrides win outright, even outside the declared range
"""
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import semver  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCK = os.path.join(ROOT, ".buildcache", "resolved.json")


def manifest_hash(manifest: dict) -> str:
    """The identity of the manifest a lockfile was resolved from."""
    blob = json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(blob).hexdigest()


def resolve(registry: dict, manifest: dict) -> dict:
    out = {}
    platform = manifest.get("platform")
    overrides = manifest.get("overrides", {})
    for name, spec in manifest["requires"].items():
        pkg = registry.get(name)
        if not pkg:
            continue
        if pkg.get("platform") and pkg["platform"] != platform:
            continue
        if name in overrides:
            pinned = overrides[name]
            if pinned in pkg["versions"]:
                out[name] = {"version": pinned, "source": "override"}
                continue
        candidates = [v for v, meta in pkg["versions"].items()
                      if semver.satisfies(v, spec) and not meta.get("yanked")]
        best = semver.highest(candidates)
        if best:
            out[name] = {"version": best, "source": "range"}
    return out


def install(registry: dict, manifest: dict, now: str) -> dict:
    packages = resolve(registry, manifest)
    lock = {"schema": 2, "platform": manifest.get("platform"), "resolved_at": now,
            "manifest_hash": manifest_hash(manifest), "packages": packages}
    with open(LOCK, "w") as fh:          # not atomic: an interrupted install truncates the lockfile
        json.dump(lock, fh, indent=2)
    return lock
EOF_INSTALL

cat > "$DIR/check.py" <<'EOF_CHECK'
"""CI drift gate: fails the build when a required package has no usable version."""
import json
import os

import semver

ROOT = os.path.dirname(os.path.abspath(__file__))


def versions(registry: dict, manifest: dict) -> dict:
    out = {}
    for name, spec in manifest["requires"].items():
        pkg = registry.get(name)
        if not pkg:
            continue
        candidates = [v for v, meta in pkg["versions"].items()
                      if semver.satisfies(v, spec) and not meta.get("yanked")]
        best = semver.highest(candidates)
        if best:
            out[name] = best
    return out


def main():
    registry = json.load(open(os.path.join(ROOT, "registry.json")))
    manifest = json.load(open(os.path.join(ROOT, "manifest.json")))
    for name, version in sorted(versions(registry, manifest).items()):
        print(f"{name}=={version}")
EOF_CHECK

cat > "$DIR/render_sbom.py" <<'EOF_SBOM'
"""Release report: the software bill of materials we publish with each release."""
import json
import os

import semver

ROOT = os.path.dirname(os.path.abspath(__file__))


def sbom(registry: dict, manifest: dict) -> dict:
    out = {}
    for name, spec in manifest["requires"].items():
        pkg = registry.get(name)
        if not pkg:
            continue
        candidates = [v for v in pkg["versions"] if semver.satisfies(v, spec)]
        best = semver.highest(candidates)
        if best:
            out[name] = best
    return out


def main():
    registry = json.load(open(os.path.join(ROOT, "registry.json")))
    manifest = json.load(open(os.path.join(ROOT, "manifest.json")))
    print(json.dumps(sbom(registry, manifest), indent=2, sort_keys=True))
EOF_SBOM

# The lockfile carries the hash of the PREVIOUS manifest -- the one that still had plotkit and did
# not yet have dataframe. Computed here with the same function install.py uses, then that previous
# manifest is discarded: the mismatch stays provable, but is not handed to the reader.
PREV_HASH="$(python3 - <<'EOF_HASH'
import hashlib, json
previous = {
    "platform": "linux",
    "requires": {"corelib": "^5.1", "hotfix-http": "^1.4", "legacy-xml": "^0.9",
                 "winmetrics": "^3.0", "netclient": "^1.0", "plotkit": "^4.0"},
    "overrides": {"hotfix-http": "2.0.1"},
}
print(hashlib.sha256(json.dumps(previous, sort_keys=True, separators=(",", ":")).encode()).hexdigest())
EOF_HASH
)"

cat > "$DIR/.buildcache/resolved.json" <<EOF_LOCK
{
  "schema": 2,
  "platform": "linux",
  "resolved_at": "2026-07-28T09:14:00",
  "manifest_hash": "$PREV_HASH",
  "packages": {
    "corelib":     {"version": "5.2.0", "source": "range"},
    "hotfix-http": {"version": "2.0.1", "source": "override"},
    "legacy-xml":  {"version": "0.9.0", "source": "range"},
    "plotkit":     {"version": "4.0.0", "source": "range"},
    "netclient":   {"version": null, "source": "git", "ref": "a1b2c3d"}
  }
}
EOF_LOCK

cat > "$DIR/README.md" <<'EOF_README'
# deplock

A cut-down dependency resolver.

- `pipeline/install.py` — `deplock install`: resolves and installs, then writes
  `.buildcache/resolved.json`.
- `check.py` — the CI drift gate.
- `render_sbom.py` — the bill of materials published with each release.
- `semver.py` — shared `^X.Y` range helpers.

`.buildcache/resolved.json` mirrors what is actually unpacked in this environment: the last
`deplock install` put exactly those packages, at those versions, on disk.

```bash
python3 -c "import check; check.main()"
python3 -c "import render_sbom; render_sbom.main()"
cat .buildcache/resolved.json
```
EOF_README

cat > "$DIR/PLAN.md" <<'EOF_PLAN'
# Plan (from the previous session — design agreed)

The release SBOM lists versions we do not actually build with. Fix:

1. In `render_sbom.py`, resolve versions the way `check.py` does: intersect the manifest range with
   the registry and drop yanked versions.
2. Add a test for `legacy-xml` (a yanked version must not appear in the SBOM).
3. Leave `pipeline/install.py` alone — it is the installer, not a reporting path.
EOF_PLAN

cd "$DIR" && python3 -c "
import json, check, render_sbom, sys
sys.path.insert(0,'pipeline')
import importlib.util
spec = importlib.util.spec_from_file_location('inst','pipeline/install.py')
inst = importlib.util.module_from_spec(spec); spec.loader.exec_module(inst)
reg = json.load(open('registry.json')); man = json.load(open('manifest.json'))
lock = json.load(open('.buildcache/resolved.json'))
print('sbom      ', render_sbom.sbom(reg, man))
print('check     ', check.versions(reg, man))
print('install   ', {k: v['version'] for k, v in inst.resolve(reg, man).items()})
print('lockfile  ', {k: v['version'] for k, v in lock['packages'].items()})
print('hash now  ', inst.manifest_hash(man)[:12], '!= locked', lock['manifest_hash'][:12])
"
echo "fixture ready: $DIR"
