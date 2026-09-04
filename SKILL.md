---
name: evidence-first-design
description: Use when a design or fix was settled before the code was read — inherited from an earlier session, dictated by a review, carried across a context break — or when the same value is derived in more than one place (what is shown / what is accepted / what is executed): irreversible paths, state machines, config and dependency resolution, caches and indexes, migrations. Not for a local change with one consumer and no state. Триггеры те же по-русски. Works from any model.
---

# Evidence-first design

**Read this if** the value you are about to compute is already computed somewhere else, or you
arrived at this task with the design already decided.

A design you reasoned out is a hypothesis. A measurement on the running system, and an artifact its
own full pipeline already computed, are evidence. This converts the first into the second **before**
any code is written.

One gap and only that gap: between what you decided the value is and what the running system can
already tell you it is. Run it once, before the first line of code.

**Not for** a local change with one consumer, no stored state and a reversible effect.

## 1. Inventory what is already computed

Before deriving a value from primary sources, find where the system **already stored** the answer,
computed by the full pipeline: snapshots written at a transition (commit, apply, publish, build),
journals, recomputation caches, materialized columns, lock files, build artifacts, resolved-config
dumps, plan output, indexes.

Bound the search to two passes, then write down what you found **and what you did not**: who
**writes** the store the value lives in (search by write, not by read), and who **reads** the value.
Absence is a conclusion about the system, not an exemption — "didn't find one" without those two
lists means the step was not done.

An artifact that looks defective — collapsed to one element, empty, older than its inputs — is not
disqualified by looking that way. Find out which branch writes it, and when.

**The measurement decides, not the preference.** You may reject the artifact — but then you take on
every rule it applied. List those rules from the writer's code, and name the ones your own
construction does not apply. That list is where the missed rule hides. The answer is often a hybrid:
the artifact as the foundation, a staleness rule, the missing rules on top.

**A staleness rule must be expressible on the data you actually have.** Name the signal that marks
the artifact stale — input version, hash, its timestamp against its inputs' timestamps. If the
inputs are not versioned, the artifact cannot be the single source. That is a conclusion of this
step, not an implementation detail.

If there is no artifact, write down why you derive rather than read. It is the first thing a second
model will check.

## 2. Measure the worst real inputs — before code

Take 3–5 of the most degenerate real inputs — a stale snapshot, a set collapsed to one element, a
record written by an older code path, a config layer nobody overrides, a pinned transitive
dependency — and answer in writing for each: **what would my construction return here?** Those
answers become the tests.

Show the command and its literal output. A paraphrase ("the snapshot is stale") is not a measurement.

If the system is live and allows it, probe inside something reversible: a transaction with a
guaranteed rollback, `--dry-run` / `plan`, a throwaway branch or worktree, a copy of a snapshot. That
proves acceptance or refusal without leaving a trace. The rollback protects stored state — **not**
the external effects inside the probe: network calls, mail, queues, third-party APIs.

With no way to measure, do not substitute reasoning: ask for the worst inputs, or say plainly that
the design is unverified. And scrub identifiers — real records leave your machine the moment you
paste them into a document or hand them to another model.

## 3. State the invariant first — then falsify it

Open the design with the property that must hold: "what is shown = what is accepted = what is
executed", "what CI builds = what a developer builds", "what the UI hides = what the API refuses".
The design question then becomes "which **one** source do all consumers read", not "how does each
consumer compute it correctly". A rule two places need goes into one implementation both call: two
computations drift, then behavior drifts.

Then check the invariant against the same 3–5 inputs. If a legitimate input violates it, narrow its
scope — for which states, as of when — rather than discarding the input. An invariant stated
confidently and never falsified causes a wrong design.

## 4. Enumerate the state space

If the product of the dimensions (state × current value × target value × artifact present ×
mode/flag × …) is under ~500, enumerate the cells explicitly, at least in tests. Walking one
end-to-end scenario checks one row of the matrix; the defects live in the other rows.

Make **who else writes this value in parallel** one of the dimensions: background jobs, retries,
external callbacks, concurrent writers. That is a pre-code question, not a code-review question.

## 5. After the fix — a second pass over your own work

A fix is new code and earns the same hard pass the defect got. Re-run the matrix with the fix in
place and ask which cells the fix itself broke — in the post-mortem this came from, up to half of the
second-round defects were introduced by the first fix.

Your own recent commits are hypotheses, not assets: if a better mechanism has appeared, replace
yesterday's code instead of building on it. Reverting your own change back to the base branch is a
normal move.

Steps 1–4 happen before code and are what the fixtures measure; step 5 happens after.

## Checklist

- [ ] Writers and readers of the value both listed; the already-computed artifact named, or a written
      reason why we derive rather than read.
- [ ] Rules the found artifact applies, listed from its writer's code; the ones my construction does
      **not** apply, named. An empty line here is itself a finding.
- [ ] Staleness signal named — or stated that the inputs are not versioned.
- [ ] 3–5 worst inputs: the command and its literal output, and what my construction returns.
- [ ] Invariant in one sentence, checked against those inputs, with its scope named.
- [ ] One source for all consumers; a shared rule lives in one implementation.
- [ ] Matrix enumerated, parallel writers included — or a written reason why enumeration is unneeded.
- [ ] Real data scrubbed before it leaves the machine.

## Rationalizations

Every line on the left was said verbatim by a model that had already found the evidence and put it
aside. Recognizing your own sentence here means the step is not done.

| What you are about to say | What is actually true |
|---|---|
| "That's a separate pipeline, out of scope for this task" | The pipeline that writes the artifact is the only place the full rule set exists. Reading it **is** the task. |
| "The plan doesn't raise this and doesn't ask me to solve it" | An inherited plan is a hypothesis from a session that had less evidence than you have now. |
| "That column serves another purpose, there is no overlap risk" | You are inferring purpose from a name. Read the writer. |
| "A candidate for refactoring later, outside the current plan" | One value computed in several places is the defect itself, not a cleanup task. |
| "Noting it as a potentially open design question" | Noticed-and-filed is the failure mode, not the fix. In the baseline runs the missing rule was noticed, written under "Risks", and the incomplete fix shipped anyway. |
| "The scenario passes" | One scenario is one cell of the matrix. |

## Red flags — stop

- Your answer names no concrete record, file or key — only classes and functions.
- You know who reads the value; you have not looked for who writes it.
- The plan arrived from an earlier session and you have not redone steps 1–2.
- You are about to add a third place that computes the same value.
- You wrote "it is stale" without showing the value and its timestamp.
- The artifact was found, mentioned under "Risks", and not used.

## When the blast radius is large, send the design out

If the change is irreversible (money, mail, deletion, publication, release), spans an invariant
between several consumers, a state machine or a migration, package the output of steps 1–4 as a
document and give it to a second model **before** implementing — for example the plan mode of the
`external-review` skill (<https://github.com/genhoi/external-review>). The artifacts collected here
are what make that review specific instead of a matter of taste. A finding in the plan costs a
paragraph; the same finding in code costs a rewrite. A local change does not need this.

## Designs carried across a context break

A design dragged through a context break quietly turns into plan-inertia: later sessions execute it
instead of re-examining it. If a design-sensitive fix began in a session that ran out of context,
redo steps 1 and 2 from a blank page regardless of what is "already decided", and ask for a focused,
whole run rather than carrying the design across another break.

## Tested on

`tests/` holds two fixtures in different domains, each shaped the same way: one value computed in
three places, an artifact the full pipeline already wrote, degenerate inputs that break the obvious
design, and an inherited plan dictating a plausible but incomplete fix. Scenarios and pass criteria
in `tests/README.md`, measured baseline-vs-skill runs in `tests/results.md`.
