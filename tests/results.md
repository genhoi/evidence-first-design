# Measured runs

## 2026-09-05 — the rewritten (English) skill, on two fixtures

Model: Sonnet, general-purpose agent, for every run. Budget ~25 tool calls, own copy of the fixture
per agent. Baseline = the task only; skill = the same task plus "first read SKILL.md and work
strictly by it". Prompts in Russian, skill text in English — that is the real usage pattern here.

Grading was blinded: each grader received all runs for one scenario under opaque ids, with the answer
key and the five criteria, and was not told which arm any run belonged to. Partial unblinding is
unavoidable — a skill-arm answer sometimes names the steps — and is noted as a limitation.

### `deplock` (dependency resolution), 3 reps per cell

All 15 deplock answers were re-graded by a single grader on one scale after the first pass showed
the criteria could be read two ways (see reservation 1). These are the re-graded numbers.

| Criterion | A-base | A-skill | C-base | C-skill |
|---|---|---|---|---|
| 1 inventory (artifact **and its writer**) | 3/3 | 3/3 | 3/3 | 3/3 |
| 2 worst inputs measured | 3/3 | 3/3 | 3/3 | 3/3 |
| 3 the rule the dictated fix drops | 3/3 | 3/3 | 3/3 | 3/3 |
| 4a invariant named | 3/3 | 3/3 | 3/3 | 3/3 |
| 4b one source read by **every** consumer | 1/3 | 0/3 | 1/3 | 2/3 |
| 5 artifact as hypothesis (A) / plan rebuilt (C) | 3/3 | 3/3 | 3/3 | 3/3 |
| **totals** | 5, 5, 6 | 5, 5, 5 | 6, 5, 5 | 6, 5, 6 |

### `paylane` (payment methods), 1 rep per cell — a regression check on the rewrite

One grader scored all four against the same key, so the comparison inside this table is on one scale.

| | A-base | A-skill | C-base | C-skill |
|---|---|---|---|---|
| total | 3/5 | **5/5** | 2/5 | **5/5** |

## What this shows, and what it does not

**`deplock` does not demonstrate an effect.** Under one strict grader the arms are indistinguishable:
A-base averages 5.33 against A-skill 5.00, C-base 5.33 against C-skill 5.67. Five of the six criteria
are 3/3 in *every* arm — they do not discriminate at all on this fixture. Only "one source for every
consumer" varies, and it varies without a pattern (1/3, 0/3, 1/3, 2/3 on n=3).

**The steps do transfer, which is a weaker claim than "the skill works".** In `deplock` the value is a
map produced by precedence, the artifact is a file written by a different command, the staleness
signal is a hash — nothing resembling payments. The behaviours the skill asks for all appear there,
in both arms. What `deplock` shows is that the fixture's baseline already produces them: the trap is
too visible. `manifest.overrides` sits in plain sight in the file the prompt names, and every one of
the 15 runs found it. A fixture whose trap is reachable from the file you were told to edit measures
the fixture, not the discipline.

**The demonstrated effect rests on `paylane`** (3/5 and 2/5 against 5/5 and 5/5), where the missing
rule lives behind a pipeline the prompt never mentions — and on the 2026-09-04 baselines below, where
the artifact was found and deliberately set aside in the plan-shaped scenarios. One model, small n.

**The criterion that discriminates anywhere is the single source.** Where an arm loses it, the
reasoning is verbatim the rationalization the skill lists: *«не пытаться „заодно“ рефакторить в общий
хелпер за рамками задачи»*, *«check.py — намеренно более узкий инструмент»*, *«фиксируется отдельно,
не в этой задаче»*. That is the behaviour worth measuring, and it needs a fixture built to force it.

## Honest reservations

1. **Grader variance dominated the first `deplock` numbers, and they were published before this was
   caught.** The first pass used one grader per scenario and reported A-base 4, 4, 5 against A-skill
   5, 5, 5. Re-graded on one scale the same nine answers come out 5, 5, 6 against 5, 5, 5 — the
   opposite direction. The cause was criterion 4: "one source is proposed for all of them" did not say
   whether covering a subset of consumers counts, and the two graders read it differently, producing a
   3/3 against 0/3 swing on equivalent answers. It is now split into "named" and "one source for
   **every** consumer". Any comparison across differently-graded batches in this file is worthless;
   only within-table comparisons hold.
2. **Two more pre-registered criteria turned out to be unsound**, both by baking in an expected
   answer. Criterion 5 for scenario C also demanded that "leave `pipeline/install.py` alone" be called
   an error in the plan: it scored 0/6 in both arms, because on `deplock` that constraint is legitimate
   and five of six runs satisfied it correctly by importing `resolve()` instead of editing the file.
   The stretch criterion asked whether anyone noticed that the lockfile's `platform` field "is read by
   no consumer" — but in the shipped fixture *no consumer reads any lockfile field*, so it is trivially
   true of every field. Both are restated in `README.md`. Three of six criteria needed correction: the
   grading harness was the weakest part of this exercise, not the runs.
3. **A rule was added to the skill and then reverted, because the measurement did not support it.**
   After the stretch criterion was restated ("does the design check the conditions recorded in the
   artifact before trusting it"), a clause was added to step 1 telling the reader to name the
   conditions the artifact was computed under. Re-tested on three fresh runs it scored 1/3, against
   2/3 for the same scenario *without* the clause. No demonstrated failure to fix, and no measured
   benefit — so it came out again. The episode is kept here because it is the more useful result.
4. **Three reps per cell, one model, two fixtures.** Enough to see that behaviours appear and that
   grader wording moves numbers more than the arms do. Not an effect size, not a significance test.
5. **The 2026-09-04 runs measured a different file** — the Russian text since rewritten in English and
   materially changed. They are provenance, not evidence about the current text; the `paylane` rows
   above are the re-measurement.
6. **Never exercised:** step 5 (the second pass over your own fix) and the reversible-probe half of
   step 2 — the answer form stops before code and both fixtures are read-only in practice.

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
