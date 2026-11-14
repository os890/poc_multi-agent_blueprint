# Retrospective after the merge into main

Goal: each milestone runs a bit more smoothly than the previous one, without the workflow growing more complex.

## 1. Collect the metrics

Write `docs/retros/m<n>.md` with this table (sources: task notes, git history, watcher log, test reports,
loop-guard events, token usage if available). `OPEN(#28)` sources and thresholds.

| Metric | Value | Previous milestones |
|---|---|---|
| tasks, of which gap/fix/regression tasks | | |
| review rounds per task (avg, max), tasks that hit the Pareto limit | | |
| findings per review type: confirmed / dropped by the reviewer, confirmed but overturned on a worker's dispute | | |
| findings of the maintainer's manual review the agents missed | | |
| lessons learned: new, repeated (per lesson) | | |
| merge-queue conflicts, red minimal suites after a merge | | |
| full-suite failures, regressions, flaky tests | | |
| failed merges into `main` and causes | | |
| escalations, loop-guard events, stalled workers | | |
| time or tokens per task (avg, max) | | |

## 2. Find the inefficiencies

An inefficiency is a metric clearly worse than in the previous milestones, or a problem that occurred more than
once in this milestone. Typical ones and where to fix them:

| Symptom | Likely change |
|---|---|
| maintainer finds what the agents missed | the review type's checklist, the review-type selection |
| a review type produces mostly dropped findings | its checklist (too vague), or run it less often |
| confirmed findings overturned, or maintainer finds what the reviewer dropped | the reviewer's validation rules |
| many review rounds per task | task sizing, acceptance criteria, worker skill (test first) |
| merge conflicts between parallel tasks | dispatch (overlap check), task cut |
| regressions found only by the full suite | the minimal suite's content |
| loop-guard events, escalations about the same kind of question | message protocol, a rule that decides it |
| a lesson learned is seen again | automate it (test, lint rule, hook) or sharpen its rule |

Take only the **1-3 issues with the biggest effect** (Pareto), each with its evidence. A repeated lesson is
always one of them.

Lessons-learned file housekeeping (`lessons-learned.md`): propose general lessons for the reviewer checklists,
retire lessons that no longer apply, keep at most 30 active ones.

## 3. Propose the changes

- One improvement task (milestone of the next run, label `workflow`) with the concrete edits to the skills, the
  reference files, the agent definitions or the limits. Change the flow itself (the workflow doc) only if a skill
  change cannot fix it.
- The improvement task gets a consistency review: no contradiction between the skills, shared rules identical in
  every skill, skills not longer than needed.
- Never part of an improvement: the hard rules, the maintainer's manual review, the hooks that enforce them.
- The maintainer approves the improvement task in the review app like any change; agents never change their own
  skills otherwise.

## 4. Check earlier improvements

For each improvement of the previous retrospectives: did its metric get better? No → propose to revert it.
`OPEN(#30)`

Send `retro done docs/retros/m<n>.md` to the coordinator.
