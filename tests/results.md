# Measured runs

## 2026-09-05 — the rewritten (English) skill, on two fixtures

Model: Sonnet, general-purpose agent, for every run. Budget ~25 tool calls, own copy of the fixture
per agent. Baseline = the task only; skill = the same task plus "first read SKILL.md and work
strictly by it". Prompts in Russian, skill text in English — that is the real usage pattern here.

Grading was blinded: each grader received all runs for one scenario under opaque ids, with the answer
key and the five criteria, and was not told which arm any run belonged to. Partial unblinding is
unavoidable — a skill-arm answer sometimes names the steps — and is noted as a limitation.

### `deplock` (dependency resolution), 3 reps per cell

| Criterion | A-base | A-skill | C-base | C-skill |
|---|---|---|---|---|
| 1 inventory (artifact **and its writer**) | 2/3 | **3/3** | 2/3 | 2/3 |
| 2 worst inputs measured | 3/3 | 3/3 | 3/3 | 3/3 |
| 3 the rule the dictated fix drops | 3/3 | 3/3 | 3/3 | 3/3 |
| 4 invariant and one source | 2/3 | **3/3** | 2/3 | **3/3** |
| 5 artifact as hypothesis (A) / plan rebuilt (C) | 3/3 | 3/3 | 2/3 | **3/3** |
| **totals** | 4, 4, 5 | **5, 5, 5** | 4, 2, 4 | 4, 4, 3 |

### `paylane` (payment methods), 1 rep per cell — a regression check on the rewrite

| | A-base | A-skill | C-base | C-skill |
|---|---|---|---|---|
| total | 3/5 | **5/5** | 2/5 | **5/5** |

## What this shows, and what it does not

**The steps transfer to a domain with no money in it.** On `deplock` the value is a map produced by
precedence, the artifact is a file on disk written by a different command, and the staleness signal
is a hash — none of which resembles the payments fixture. The skill arm still produced the same
behaviour: inventory with a named writer, measurements on named packages, one source for three
consumers.

**The clearest effect is convergence, not score.** A-skill was 5, 5, 5 — three reps, no variance.
A-base was 4, 4, 5 and C-base 4, 2, 4. The skill arm never produced a weak run; the baseline arm
sometimes did. That matches what the paylane regression shows more sharply (base 3/5 and 2/5 against
skill 5/5 and 5/5), on a fixture where the baseline has less to go on.

**On `deplock` the baseline is strong, so the margin is small.** A-base averaged 4.33/5. Criterion 3
was 6/6 in both arms and did not discriminate at all: `manifest.overrides` sits in plain sight in
`manifest.json`, so the missed rule is much easier to find here than `provider_health` is in paylane.
A fixture where the trap is visible from the file the prompt names measures less than it looks like
it does.

**The criterion that fired hardest is #4, the invariant.** It separated the arms on both scenarios,
and the baseline failure was verbatim the rationalization the skill lists: *«рефакторить в общий
хелпер за рамками задачи»* — refactoring into a shared helper is outside the scope of this task.

## Honest reservations

1. **A pre-registered criterion turned out to be unsound, and it is the one that would have been the
   headline.** Criterion 5 for scenario C originally also required naming "leave
   `pipeline/install.py` alone" as an error in the plan. It scored **0/6 — in both arms**. The reason
   is not that the skill failed: on `deplock` that constraint is legitimate, and five of six runs
   satisfied it correctly by importing `resolve()` instead of editing the file. The criterion had one
   expected answer baked into it. It has been split; the surviving half (was the inherited plan
   rebuilt rather than executed) is what the table above reports, and there the split is base 2/3
   against skill 3/3.
2. **Scenario C on `deplock` shows no clear separation** (4, 2, 4 against 4, 4, 3). One baseline run
   scored 2/5 and the rest are within noise of each other. C separates cleanly on paylane and not
   here; a single fixture cannot tell you which of the two is the outlier.
3. **Three reps per cell, one model, two fixtures.** Enough to say the behaviour changes and to see
   variance shrink. Not enough to state an effect size, and not a significance test.
4. **The 2026-09-04 runs measured a different file.** The earlier six runs (below) were made against
   the Russian text that has since been rewritten in English and materially changed. They are kept as
   the record of why the skill exists, not as evidence about the current text; the paylane rows above
   are the re-measurement.
5. **Never exercised:** step 5 (the second pass over your own fix) and the reversible-probe half of
   step 2 — the answer form stops before code, and both fixtures are read-only in practice. Nobody in
   12 runs noticed the `platform` field in the lockfile that no consumer reads.

## 2026-09-04 — the original Russian text, `paylane` only

One run per cell, Sonnet, same protocol. Kept for provenance.

| Criterion | A-base | A-skill | B-base | B-skill | C-base | C-skill |
|---|---|---|---|---|---|---|
| artifact named with its writer | no | **yes** | yes | **yes** | deferred | **yes** |
| measured on degenerate rows | no | **yes** | yes | **yes** | partly | **yes** |
| the missing `provider_health` rule | yes (in "Risks") | yes | yes | **yes, as the headline** | no | **yes, as the headline** |
| invariant, one source | duplicated it | **yes** | yes | **yes, separate module** | "some day later" | **yes** |
| matrix / uncovered cells | no | yes | partly | **yes** | no | yes |
| inherited plan rebuilt, not executed | — | **yes** | — | yes | **no** | **yes** |

Both plan-shaped scenarios (A, where the fix is dictated; C, where it is inherited) failed the same
way in the baseline: **the artifact was noticed and deliberately set aside.**

- A-base: *«pipeline/confirm.py — отдельный пайплайн подтверждения, это вне рамок задачи»*; on the
  snapshot, *«отдельная колонка для другой цели, риска пересечения нет»*.
- C-base: *«PLAN.md эту тему не поднимает и не просит её решать»*; the duplication between `catalog`
  and `accept` — *«кандидат на рефакторинг в будущем, вне текущего плана»*.

That is not ignorance of the technique. It is refusal of it under the pressure of a settled plan,
which is the failure the skill is written against — and it is where the rationalization table came
from.

**B-base was strong.** On the open design task, with no plan handed to it, the baseline found the
snapshot, the three diverging definitions and proposed a shared function by itself. The skill earns
its keep first where a plan is **given or inherited**.
