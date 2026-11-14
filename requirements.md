# Requirements and process definition (draft)

Requirements view of the [multi-agent milestone workflow](multi-agent-workflow.md): what the workflow must achieve,
who decides what, and when each phase starts and ends. The workflow doc and the skills describe *how*; this file is
the yardstick to check them against. Proposals for open points are marked `Proposed (RE)` here and in
[open-points.md](open-points.md); they become rules once the maintainer accepts them.

## 1. Goals

Each goal has a check, so a dry run (`#36`) or a retrospective can say whether it is met.

| # | Goal | Check |
|---|---|---|
| G1 | **Low maintainer effort**: agents work through a milestone on their own; the maintainer is involved only at the decision points in section 4. | Every maintainer interaction of a milestone maps to a row of the decision table. Retro metric: interactions per milestone. |
| G2 | **Nothing unchecked reaches `main`**: every change passes task review, merge gate, full suite, milestone review, goal check and the maintainer's manual review. | The milestone review report has evidence for every gate; the watcher merges only approved milestone review branches. |
| G3 | **Traceability**: goal → success criterion → task → commits → reviews → findings and their fate → decisions. | For any line in the milestone diff, the report and task notes name the task, the review rounds and every decision about it. |
| G4 | **Recoverability**: any agent can crash or be replaced mid-milestone without losing work. | Dry run: kill each role once while it has work; the run continues from the task files and the review folder only. |
| G5 | **Bounded cost and time**: no endless review rounds, chat loops or retries. | Every loop in the flow has a limit and an escalation (section 7); retro metric: tokens/time per task. |
| G6 | **Continuous improvement without growth**: each milestone runs smoother than the previous one. | Retro metrics trend; skills do not grow in total size over 3 milestones. |

## 2. Scope and non-goals

In scope: one milestone at a time, from the maintainer's goal to the retrospective, in one repository with
backlog-ng milestone branches.

Not in scope (non-goals):

- Agents never merge into `main`, release or deploy. Releases (`#33`) are the maintainer's, after the milestone.
- No audits of the whole code base: every review is about the diff only.
- No replacement of the maintainer's manual review; agents prepare it, they don't do it.
- No self-modification: agents change skills, hooks and limits only through an improvement task the maintainer
  approves.
- `Proposed (RE)` for v1: no parallel milestones (`#19`). One milestone branch at a time keeps the merge into `main`,
  the lessons file and the retrospective metrics unambiguous. Revisit after 3 milestones.

## 3. Actors

| Actor | Kind | Responsible for | Never |
|---|---|---|---|
| Maintainer | human | goal, plan approval, scope changes, fix-or-defer, drafts, manual review, improvement approval | – |
| Coordinator | agent | planning with the maintainer, escalations, loop guard, goal check, hand-off, status | code, reviews, task status |
| Task manager | agent | dispatch, review requests, Pareto rule, merge queue, milestone gate, lessons, merge recovery, retrospective | implementing, reviewing, deciding scope or deferrals |
| Worker (1..n) | agent | one task at a time: implement, test, commit, fix findings | merging, setting Done, out-of-scope fixes |
| Reviewer | agent | one sub-agent per review type, validation of findings, findings file | reviewing itself, git |
| Review type | sub-agent | findings of one type on one diff | anything else |
| Test runner | agent | suites, flaky check, bisect, reproductions | changing code or tests |
| backlog-ng | system | task files, branches, worktrees, milestone review task | – |
| Watcher | system | merging the approved milestone review branch into `main` (`$BNG update` merges the milestone branch into it) | committing board changes on `main` or `milestone-*` |
| Review app | system | the maintainer's manual review and approval | – |
| Hooks, monitor, tick | system | enforcing hard rules and limits; turning external events into messages (`#38`) | – |

## 4. Decision rights

`Proposed (RE)` for `#24`. Prepares = writes the options and evidence; decides = owns the outcome.

| Decision | Decides | Prepares | When the maintainer is asked |
|---|---|---|---|
| Milestone goal and success criteria | maintainer | coordinator | always (planning) |
| Task split, order, dependencies | maintainer (approves plan) | coordinator | always (planning) |
| Scope, goal or priority change during a run | maintainer | coordinator | always, immediately |
| Pause, resume, cancel | maintainer | – | always |
| Review types for a task | task manager (rules in `reviews.md`) | – | never |
| Finding valid, severity | reviewer | review-type sub-agents | never |
| Worker disputes a confirmed finding | task manager | worker, reviewer's findings file | never (recorded for the retro) |
| Blocking or not (Pareto rule) | task manager | – | never |
| Defer a critical or major finding | maintainer | task manager → coordinator | always |
| Keep or discard minor drafts | maintainer | coordinator (list at hand-off) | once per milestone, batched |
| Record a lesson | task manager | – | sees it in the manual review; rejects it there |
| Reassign or stop a stalled task | task manager | – | never |
| Deadlock, loop limit reached | coordinator | – | if it is not a coordination question |
| Unclear requirement | maintainer | worker → task manager → coordinator | always; no guessing |
| Approve the milestone | maintainer | task manager (report), coordinator (summary) | always |
| Change a skill, limit or the flow | maintainer | task manager (improvement task) | always (review app) |

**Batching** (`#24`): the coordinator collects maintainer questions and asks them together. A question is asked
**immediately** only if it blocks all running work, concerns a broken hard rule or data at risk, or is a scope,
pause or cancel decision. Otherwise it goes out with the next batch: when no other work can proceed, at `gate green`,
or at the hand-off, at the latest once per working day of the run. Every question and its answer is written to the
task notes (or the milestone description) so the decision is traceable (G3).

## 5. Hard constraints

Not subject to retrospective improvements (see the workflow doc). Each must be enforced by a hook as well as stated
in the skills (`#35`).

| # | Constraint | Applies to |
|---|---|---|
| C1 | Never merge into, commit on or push `main`; never push or force-push anything | all agents |
| C2 | Only the maintainer approves the manual review and sets the milestone review task Done | all agents |
| C3 | Never rewrite commits merged into the milestone branch (no rebase, reset, force push) | task manager, workers |
| C4 | Package installs only with `--ignore-scripts`; web access only to whitelisted domains | all agents |
| C5 | Reviewers and review types run no git commands and no Bash | reviewer, review type |
| C6 | Agents without Edit/Write write no files, also not through Bash; agents with a limited Write write only in their folder (reviewer: review folder, test runner: test folder) | coordinator; reviewer, test runner |
| C7 | Agents never defer a critical or major finding | task manager, coordinator |
| C8 | Task files only via `$BNG cli`, never by hand | all agents |
| C9 | The maintainer's main checkout is never cleaned, reset or switched | all agents |
| C10 | Agents change no skill, hook or limit except through an approved improvement task | all agents |

## 6. Phases: entry and exit criteria

A phase starts only when all entry criteria hold and ends only when all exit criteria hold. "Fails" names where the
flow goes otherwise.

| Phase | Owner | Entry | Exit | Fails → |
|---|---|---|---|---|
| P0 Run start | maintainer | agents started | task manager has `ready` from reviewer, test runner, ≥ 1 worker | `escalate M<n>: missing <role>` |
| P1 Planning | coordinator | maintainer states a goal | goal verbatim + success criteria in the milestone description (section 8); every criterion mapped to ≥ 1 task and every task to ≥ 1 criterion; all tasks meet the DoR (section 9); maintainer approved the plan; milestone review task created | maintainer rejects → replan |
| P2 Implementation | worker | task meets DoR, dependencies merged, no expected overlap with a running task, free worker | `done`: minimal suite green, AC ticked, notes written, committed | `blocked` → section 7 |
| P3 Task review | reviewer, task manager | `done` with commit, diff file written | findings file; Pareto decision recorded in the task notes | blocking → `fix` (P2); limit → escalate |
| P4 Merge into milestone branch | task manager | no blocking findings; escalated findings decided or merged-then-escalated per `reviews.md` | merge committed after a green minimal suite on the merged result; task meets the DoD | conflict or red → abort, `fix` |
| P5 Milestone gate | task manager, test runner, reviewer | all tasks of the milestone merged; no task in progress; no open escalation | full suite green (flaky tests listed); milestone review: no critical/major left that the maintainer has not deferred; no lesson violations | regression/fix tasks (P2); after the fix round → escalate |
| P6 Goal check | coordinator | `gate green` | every success criterion has evidence, is marked "maintainer verifies", or the maintainer accepted the gap | `gaps` → gap tasks (P2) |
| P7 Hand-off | task manager, coordinator | `goal met` | report committed; milestone review task In Review; coordinator summary sent | – |
| P8 Manual review | maintainer | milestone review task In Review | approved, or `rejected <list>` | rejected → fix tasks (P2), then P5 on the new commits |
| P9 Merge into `main` | watcher | milestone review branch approved; no non-draft task of the milestone open | `main` contains the merge of the milestone review branch | `merge-recovery.md` |
| P10 Retrospective | task manager | merge into `main` seen | retro file; improvement task or "none"; earlier improvements checked | – |

The milestone is **closed** when P10 is done. It is **cancelled** only by the maintainer (section 7).

## 7. Exception paths

Every loop has a limit, and every limit leads to an escalation (G5). `Proposed (RE)` rows answer open points.

| Event | Detected by | Handling | Limit → then |
|---|---|---|---|
| Task unclear or contradicting | worker | `blocked`; task manager answers from the plan or escalates | 1 round → coordinator → maintainer |
| Worker disputes a confirmed finding | worker | `blocked ... finding <n> wrong`; task manager decides, records it | – |
| Blocking findings | reviewer | `fix`, re-review of the fix diff (Pareto rounds) | 3 rounds → escalate fix or defer |
| Red minimal suite or conflict when merging | task manager | abort, `fix`, worker merges the milestone branch in; re-review of the whole task diff, **not counted as a Pareto round** (`Proposed (RE)`: the cause is another task) | 2 failed merges of the same task → serialize it: merge it next, no other task merged in between |
| Full suite red | test runner | regression task per failing test (bisected) | after the fix round still red → escalate fix or defer (`Proposed (RE)`) |
| Flaky test (`#13`) | test runner | `Proposed (RE)`: one rerun alone; flaky tests never block but are listed in the report; a test flaky in 2 milestones gets a fix task; quarantine only with the maintainer's decision | – |
| Test runner cannot run a suite (environment broken) | test runner | `Proposed (RE)`: new result `error` (not `red`) with the log; task manager escalates instead of creating regression tasks | – |
| Reviewer cannot start sub-agents | reviewer | `blocked <review>`; task manager escalates; no merge without review (pause) | – |
| Stalled worker (`#20`) | tick (`#38`) | `Proposed (RE)`: no commit, note or message for 30 min → `stop TASK-<id>`; no `stopped` within 10 min → take the task back from its notes and branch, assign it again | 2 stalls of the same task → escalate (task too big or unclear) |
| Agent crash (`#22`) | missing answer to a request within its time limit, tick | `Proposed (RE)`: coordinator asks the maintainer to restart the role; the restarted agent sends `ready <role>`; the task manager re-sends the open request for that role (requests are idempotent: state is in files) | same role crashes twice in a milestone → maintainer |
| Task manager crash | coordinator: no answer to a message within its time limit | `Proposed (RE)`: maintainer restarts it; coordinator sends `start M<n>` again, which means *resume*: the task manager rebuilds its state from task statuses, task notes, the review folder and git | – |
| Budget per task reached | task manager | `stop`, escalate (task too big or unclear) | – |
| Message limit reached | hook | blocked; coordinator decides | – |
| Maintainer rejects | maintainer | fix task per point; P5 on the new commits only | – |
| Merge into `main` fails | watcher log | `merge-recovery.md` | same merge fails twice → maintainer |
| Scope change (`#25`) | maintainer | `Proposed (RE)`: coordinator replans with the maintainer; new tasks must meet the DoR; a removed task that runs → `stop`, branch kept unmerged, task archived; a removed task already merged → `git revert -m 1 <merge>` as a new commit on the milestone branch; a priority change affects only the order of To Do tasks | – |
| Cancel (`#25`) | maintainer | `Proposed (RE)`: `cancel M<n>`: no new tasks, running tasks `stop`, no more merges; the milestone branch stays unmerged; report of what is merged and what not; maintainer decides keep (resume later) or delete | – |

## 8. Goal capture and evidence

`Proposed (RE)` for `#26`. The milestone description holds:

```markdown
## Goal (verbatim)
<the maintainer's words, never reworded>

## Success criteria
- SC-1: <observable result> | verified by: test <name> | command <cmd> | screenshot | maintainer
- SC-2: ...

## Out of scope
- <what the maintainer explicitly does not want in this milestone>
```

- Each criterion is observable (input or action → result), not an activity ("refactor X" is a task, not a
  criterion).
- Accepted evidence: a named test in the full suite, a command with its output in the report, a screenshot or
  recording for UI behaviour, a doc section for documentation goals. "Task done" alone is not evidence.
- Criteria only a human can judge are marked `verified by: maintainer`; the goal check lists them as "for the
  manual review", never as "met".
- "Out of scope" stops gap tasks for things the maintainer did not want.

## 9. Definition of Ready and Done (task)

`Proposed (RE)` for `#34` and `#16`.

**Ready** (the coordinator checks it at planning; the task manager before dispatch):

- serves ≥ 1 success criterion (named in the task)
- what and why in the description; acceptance criteria that are observable and testable
- dependencies listed; expected files or modules listed (the overlap check of `#16` uses them)
- small enough for one reviewable branch: target ≤ 400 changed lines without tests and generated files, and within
  the per-task budget; bigger → split
- no open question

**Done** (the task manager checks it before the merge commit):

- each acceptance criterion is ticked and covered by a test, or the notes say why it cannot be tested
- minimal suite green on the task branch and on the merged result
- no blocking confirmed finding; minor findings are drafts; critical/major left have a recorded maintainer decision
- task notes: what was done, tested and not tested, review rounds with the fate of each finding
- merged into the milestone branch with `--no-ff`

## 10. Process inconsistencies (resolved)

The check of the skills against sections 6 and 7 found 11 inconsistencies (I1-I11: `stop` answered with `done`, no
`error` test result, the message limit worded four ways, the coordinator writing task files without the tool for
it, minor drafts sorted three ways, ...). All are fixed in the skills, the workflow doc and the diagram; their
provisional rules carry `OPEN(#n)` markers until the maintainer decides the open points.
