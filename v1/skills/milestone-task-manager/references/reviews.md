# Reviews, Pareto rule and lessons (task manager reference)

`C=$(git rev-parse --git-common-dir)/backlog-ng`; `S` = `~/.claude/milestone/scripts` (scripts and hooks only there, a trial-run lesson)
(`<repo>` = the main checkout; skills such as the review-type checklists: the project copy first, then `~/.claude`). Review id: `task-<id>-r<n>` (task review round n) or `m<n>-g<k>`
(milestone review, gate run k). "Escalate" always means an escalation task on the board (SKILL.md Reporting),
never a chat question. You decide the review id and the diff base (§1) in each assignment; the worker writes the
task diff and hands it to the review session, which writes the other review files (D13). You write only the
milestone review's diff and request.

## 1. Diff (scope: only what the task or milestone changed; the assignment's `diff-base`)

| Review | Diff written to `$C/reviews/<review>.diff` (by the worker; milestone: by you) | `tree` |
|---|---|---|
| task, round 1 | `git diff $(git merge-base milestone-<slug> <task>)..<task>` | task worktree |
| task, round 2/3 | the fix commits only: `git diff <reviewed commit>..<task>` | task worktree |
| sub-task, round 1 (only for a parent > ~400 lines) | its commits only: `git diff <parent head before the sub-task>..<task>` (types as a task) | parent's worktree |
| parent with sub-tasks (after the last sub-task) | the whole parent diff (round-1 command): the full task review, all fitting types, rounds as a task (the whole picture, also when its sub-tasks had their own reviews) | parent's worktree |
| task, after `merge-in` (not a round) | the whole task diff again (round-1 command) | task worktree |
| task, after a rejection (not a round) | the fix commits only: `git diff <commit set In Review>..<task>` | task worktree |
| milestone, gate run 1 | `git diff $(git merge-base main milestone-<slug>)..milestone-<slug>` | milestone checkout |
| milestone, gate run k > 1 | `git diff <commit of the last milestone review>..milestone-<slug>` | milestone checkout |

## 2. Review types

The review session selects them (its skill holds the table: `combined` for diffs ≤ ~150 lines, otherwise
`logic-code-test` + `security` + the triggered conditional types; the milestone review is always `milestone` = 01
across tasks, 03, 08). You never select types and never start review sub-agents.

## 3. The milestone review request (gate c; task reviews are handed over by the workers)

Write the diff (§1, milestone rows), then `$C/milestone/inbox/review/m<n>-g<k>.md` (`.tmp`, then `mv`):

```
id:      review-m<n>-g<k>
answer:  $C/answers/review-m<n>-g<k>.md
review:  m<n>-g<k>
types:   milestone
diff:    $C/reviews/m<n>-g<k>.diff
tree:    <milestone checkout, absolute>
scope:   M<n> g<k>
lessons: <lessons file in the milestone checkout>
docs:    <"Docs to check against" from CLAUDE.md>
```

Every review answer (`review`, `result: <c> confirmed, <d> dropped`, `findings: <path>`) is read the same way: only
the confirmed findings in the findings file count; you don't double-check them. A worker's later `blocked: finding
<k> wrong because ...` is the exception: you decide and note it for the retro.

## 4. Pareto rule (task review)

| Round | Scope | Blocks In Review |
|---|---|---|
| 1 | task diff | critical, major |
| 2 | fix diff of round 1 | critical, major |
| 3 | fix diff of round 2 | critical, lesson violations |
| after 3 | – | critical or lesson violation left → escalate "fix or defer" before In Review or your merge (task stays In Progress, note "waiting for decision", no assignment open); major left → In Review or your merge with the finding in the notes, and an escalation task "fix or defer" |

- Blocking findings → copy them into the task notes, a worker assignment `mode: fix`, `findings: <.findings.md>`,
  `review:` the next round, `diff-base:` the reviewed commit.
- Minor findings never block and become no tasks (overhead cut 5): keep them in the findings file; the coordinator
  lists them all once in the milestone report ("Deferred minor findings"), and the maintainer sorts them there.
- Lesson violations (`lesson: L-<n>`) block in every round. Agents never defer critical/major findings.
- Milestone review: confirmed critical/major → fix tasks in the gate's one fix round; its re-review blocks only on
  critical and lesson violations; anything critical/major left → escalate "fix or defer".

Task notes per round: types run and why, findings file, each confirmed finding's fate (fixed in `<sha>`, minor →
milestone report, deferred by the maintainer), lessons, dropped count per type.

## 5. Lessons file entry (`Lessons file` from CLAUDE.md; create it with the first lesson)

```markdown
## L-<n>: <short title>
- applies to: <review types> | workflow
- severity:   critical | major
- seen:       M<n> TASK-<id> (<task review | milestone review | full suite | manual review | merge into main>)
- rule:       one sentence, checkable on a diff
- check:      how to spot it in a diff
- status:     active | automated (<test, lint rule or hook>) | retired (<reason>)
```

Record only when all three hold: a basic cause a one-line rule could have prevented; critical/major impact;
confirmed (validator, failed test or the maintainer). Sources: confirmed critical/major findings, full-suite
failures, the maintainer's rejected points (always check these), failed merges into `main`.
