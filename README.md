# evidence-first-design

**A design you reasoned out is a hypothesis. What the running system already computed is evidence.**
This is a skill for coding agents that makes the executor collect the second before writing code —
and it exists because a strong model, given the same task, beat a settled design by refusing to
trust it.

<p>
  <a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-1b2a41?style=flat-square"></a>
  <img alt="no tooling" src="https://img.shields.io/badge/requires-nothing-1b2a41?style=flat-square">
  <img alt="agent skill" src="https://img.shields.io/badge/agent-skill-e5674f?style=flat-square">
  <img alt="tested on two fixtures" src="https://img.shields.io/badge/tested-2%20fixtures%20%C2%B7%2016%20runs-1b2a41?style=flat-square">
  <a href="docs/ru/SKILL.md"><img alt="Русская версия" src="https://img.shields.io/badge/docs-%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9-5c6b7c?style=flat-square"></a>
</p>

## The failure it is written against

An agent asked "what is the correct value here" reaches for the primary sources and derives it. Its
attention is on the code in front of it, and the code in front of it is the code that *reads* the
value. Meanwhile the system has usually already computed the same value somewhere — at a commit, an
install, a build, a publish — with every rule applied, and stored it. Deriving by hand reproduces
those rules one at a time, and every rule you miss becomes a defect.

The failure is not that the agent doesn't know this. In the baseline runs it repeatedly **found** the
stored artifact and put it aside:

> *"That's a separate pipeline, out of scope for this task."*
> *"The plan doesn't raise this and doesn't ask me to solve it."*
> *"A candidate for refactoring later, outside the current plan."*

Noticed and filed. Then the incomplete fix shipped. That is a discipline failure under the pressure
of a design that is already settled, and it is what the skill is built to interrupt.

## What it asks for

Five steps, four of them before any code: inventory what the system already computed (**and who
writes it, and when**), measure the worst real inputs and show the output, state the invariant and
then try to falsify it, enumerate the state space, and — after the fix — pass over your own work
again. Full text in [SKILL.md](SKILL.md) ([по-русски](docs/ru/SKILL.md)).

The load-bearing part is not "prefer the stored artifact". It is that **the measurement decides**.
You may reject the artifact — but then you inherit every rule it applied, so you list those rules
from the writer's code and name the ones your own construction does not apply. That list is where
the missed rule hides. The answer is usually a hybrid.

## Does it work

Measured, not asserted: [tests/results.md](tests/results.md). Two fixtures in unrelated domains,
16 baseline-vs-skill runs, blinded grading against criteria registered before the runs.

| | baseline | with the skill |
|---|---|---|
| `paylane` — payment methods, dictated fix / inherited plan | 3/5, 2/5 | **5/5, 5/5** |
| `deplock` — dependency resolution, dictated fix (3 reps) | 4, 4, 5 | **5, 5, 5** |
| `deplock` — inherited plan (3 reps) | 4, 2, 4 | 4, 4, 3 |

The honest reading: the clearest effect is **convergence** — the skill arm has no weak runs, the
baseline arm does. On `deplock`'s inherited-plan scenario there is no clear separation, one
pre-registered criterion turned out to be unsound and was split, and steps that happen after the code
were never exercised. All of that is written up in the results, including what it means.

## Install

The skill is plain prose — no runtime, no dependencies, nothing to configure. Clone it and symlink it
where your agent looks for skills:

```bash
git clone https://github.com/genhoi/evidence-first-design.git ~/src/evidence-first-design
mkdir -p ~/.agents/skills ~/.claude/skills
ln -s ~/src/evidence-first-design ~/.agents/skills/evidence-first-design   # Codex, Gemini, grok, kimi
ln -s ~/src/evidence-first-design ~/.claude/skills/evidence-first-design   # Claude Code
```

`~/.agents/skills/` is the cross-runtime location; Claude Code reads `~/.claude/skills/`. Because it
is only text, any model can follow it — and any model can be handed it with "read this file and work
by it" in a runtime that has no skill loader at all.

## Testing it yourself

```bash
tests/make-fixture-deplock.sh /tmp/efd/deplock
tests/make-fixture-paylane.sh /tmp/efd/paylane
```

Each fixture has the same shape in a different domain: one value computed in three places, an
artifact the full pipeline already wrote, degenerate inputs that break the obvious design, and an
inherited `PLAN.md` dictating a plausible but incomplete fix. In both, neither obvious design is
right on its own. Scenarios, protocol and pass criteria: [tests/README.md](tests/README.md)
([по-русски](docs/ru/tests-README.md)).

If you change the skill, re-run both fixtures baseline-vs-skill and add the numbers to
`tests/results.md`. A change to a discipline skill that was not measured is a hypothesis.

## Related

[external-review](https://github.com/genhoi/external-review) runs other model families as reviewer
agents. Its `--mode plan` reviews a design before it is implemented, and sections 1–4 of its
plan-mode prompt mirror this skill deliberately: this one is what the executor does, for free, every
time; that one is a second opinion worth its cost when the blast radius is large. The artifacts this
skill produces are what make that review specific instead of a matter of taste.

## License

MIT.
