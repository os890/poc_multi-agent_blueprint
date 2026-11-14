# Reviews: task review and milestone review

You request the reviews; the reviewer (agent `milestone-reviewer`) runs one fresh sub-agent per review type,
validates the findings and reports only the confirmed ones. You decide what blocks (Pareto rule), what becomes a
draft and what becomes a lesson.

This file is the single source for the review scope, the review-type selection and the Pareto rule; the workflow
doc links here.

## Scope: the diff only

| Review | Diff |
|---|---|
| Task review | `git diff $(git merge-base milestone-<slug> <task-branch>)..<task-branch>` |
| Re-review after fixes | the fix commits since the previous round only: `git diff <reviewed commit>..<task-branch>` |
| Re-review after the worker merged the milestone branch into the task branch | the whole task diff again (first row), types logic, code, test |
| Milestone review | `git diff $(git merge-base main milestone-<slug>)..milestone-<slug>` |

Write the diff to a file (`$(git rev-parse --git-common-dir)/backlog-ng/reviews/<task-or-milestone>-r<round>.diff`,
absolute path in the message; in a worktree `.git` is a file, so never use `.git/backlog-ng/` directly). The reviewer writes its findings next to it (`...-r<round>.findings.md`). Reviewers run no git commands:
least privilege, and git commands in the maintainer's main checkout can take `.git/index.lock` and make the
watcher's merge fail.

## Review types

| # | Type | Task review: run if the diff ... | Milestone review |
|---|---|---|---|
| 1 | logic | always | yes |
| 2 | code | always | yes |
| 3 | architecture | changes structure, modules, packages or interfaces | yes |
| 4 | security | always | yes |
| 5 | data-safety | changes code that reads, writes, moves or deletes user data | yes |
| 6 | cross-platform | changes platform code, paths or scripts | yes |
| 7 | dependencies | changes build files or lock files | yes |
| 8 | docs | – | yes |
| 9 | usability | changes UI, messages or CLI output | yes |
| 10 | code-quality | – | yes |
| 11 | test | always | yes |

`OPEN(#8)`: who decides "touched" (path rules per project or your judgement). Provisional: your judgement from the
diff's file list, recorded in the task notes.

Message to the reviewer:

```
review TASK-<id> r<n> diff=<path> tree=<task worktree> commit=<sha> lessons=<path> types=<list>
review M<n> r<n> diff=<path> tree=<milestone checkout> commit=<sha> lessons=<path>
```

## Double-check

Done by the reviewer (re-read in context, reproduction via the test runner, duplicates, severity). You trust the
confirmed findings; you don't double-check them again. A worker's `blocked TASK-<id>: finding <n> wrong because ...`
is the exception: you decide, and record a wrongly confirmed finding for the retrospective.

Confirmed critical/major and caused by a basic mistake → record a lesson, or add the occurrence to the lesson the
finding names (`lessons-learned.md`).

## Pareto rule (task review)

| Round | Scope | Blocks the merge |
|---|---|---|
| 1 | task diff | critical, major |
| 2 | fix diff of round 1 | critical, major |
| 3 | fix diff of round 2 | critical, lesson violations |
| after 3 | – | critical or lesson violation left → not merged; escalate to the coordinator |

- Minor findings never block: they become drafts without a milestone (`$BNG cli draft create ...`), unless the
  worker fixes them in passing in the same round. The coordinator lists them at the hand-off; the maintainer sorts
  them (next milestone, backlog, discard). Agents never discard a draft. `OPEN(#6, #10)`
- A major finding of round 3 doesn't block the merge, but is never silently deferred: after the merge,
  `escalate TASK-<id>: fix or defer <finding>`; `fix` → a fix task in the milestone, `defer` → a draft marked
  deferred by the maintainer.
- Escalated before the merge (critical or lesson violation after round 3): the task stays In Progress with the note
  `waiting for decision`, its worker is free for other tasks. `fix` → `fix TASK-<id>` to a free worker; that
  round blocks only on the findings the decision names. `defer` → merge; the findings become drafts marked deferred
  by the maintainer.
- Lesson violations (`lesson: L-<n>`) block in every round.
- The re-review after the worker merged the milestone branch into the task branch (failed merge) is not a new
  Pareto round: it keeps the round number, because the cause is another task.

## Recording

In the task notes, per round: review types run, the findings file, each confirmed finding with its fate (fixed in
`<commit>`, draft `<id>`, deferred by the maintainer), lessons recorded or repeated (`lesson: L-<n>`), dropped
findings per type (from the findings file).
