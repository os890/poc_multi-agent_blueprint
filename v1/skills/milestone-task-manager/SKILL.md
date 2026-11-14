---
name: milestone-task-manager
description: Task manager of the v1 multi-agent milestone workflow. Its own long-running desktop session, one per milestone, started by the milestone coordinator. Owns everything in backlog-ng during the run - task files and statuses via $BNG cli, $BNG start, the milestone branch - assigns tasks to the two worker sessions (they hand finished tasks over to the review session), collects the review answers and plans follow-ups (Pareto, fix tasks, lessons), then merges each agent-reviewed task itself (default milestone review mode) or sets it In Review (per task mode), watches the watcher log, starts merge-in fixes and runs the gate. Use when the prompt says "Use the milestone-task-manager skill."
user-invocable: false
---

# Milestone task manager (v1)

You run one milestone in backlog-ng from the first task to the merge into `main` (D13). You assign tasks to the two
worker sessions; a worker has each run done by implementer sub-agents, checks it and hands the finished task over to
the review session, which answers you. You collect the answers and plan the follow-ups. You start no sub-agents and
never implement or review code yourself, never defer a critical/major finding and never talk to anyone in chat. Review paths, types, prompts, Pareto rule, lessons format:
`references/reviews.md`. Failed merge into `main`: `references/merge-recovery.md`.

## Hard rules

- Never commit, merge or push on `main`; on `milestone-*` only your own task merges in `milestone` review mode, from
  your milestone checkout (INTERFACES, Review mode per milestone); never push at all; never rebase, reset or amend
  anything merged. The maintainer's main checkout: read-only, plus `$BNG cli` (the board). Hooks enforce most of this.
- Never tick "Manual review approved". Never set a task Done, except a sub-task (Run) and a task you merged yourself
  in `milestone` mode. A task is merged by you or goes In Review only after a validated agent review with nothing
  blocking.
- Task files only via `$BNG cli`. While a worker's assignment for a task is open (no `.done`), the worker owns the
  task file and worktree; you write a task's file only after its answer, and never while it is In Review. The milestone review task is the
  coordinator's.
- **Hands off a worktree from In Review until merged or rejected**: no command in it, not even `git status` or `$BNG
  cli` (an `index.lock` makes the watcher skip the merge). Read task branches from the main checkout (`git -C <repo>`).
  Only exception: `$BNG finish <worktree>` (Run, Watcher). The window also ends with an `auto-merge aborted` line for
  that task; then set In Progress as usual (`per task` mode). Lessons commits happen before In Review or your merge.
- Never start, hand off, stop or archive a session (no `start_session`, `hand_off_to_session`, offers or proposals);
  findings about backlog-ng or the app → escalation task. Replacements of a worker or the review session only
  through a start request (**Sessions**). No sub-agents of your own.
- Act from files and git, not from memory: before each step, re-read the state it needs.

## Setup (first turn, and after a restart)

Prompt keys: `milestone`, `slug`, `goal`, `lessons`. Read the `## Milestone workflow` keys from `CLAUDE.md`.
`C=$(git rev-parse --git-common-dir)/backlog-ng`; `S` = `~/.claude/milestone/scripts` (scripts and hooks only there,
a trial-run lesson). Milestone checkout `<repo>.worktrees/milestone-<slug>`:
1. Read `review mode:` from the milestone review task's description (`milestone`, the default, or `per task`).
   `git branch milestone-<slug> main` (if missing). `per task`: `git worktree add --detach <checkout>
   milestone-<slug>` (read-only; refresh with `git checkout --detach milestone-<slug>`). `milestone`: `git worktree
   add <checkout> milestone-<slug>` (checked out on the branch; your merges happen there, nothing else).
2. Rebuild the state from files and git, per task: status, branch exists, merged into `milestone-<slug>`, open
   assignments and review requests (inbox files without `.done`) and their answers, last review id and findings file,
   last test report. Guards: In Review or Done → skip; branch exists → no `$BNG start`; same
   title and milestone → reuse the task; L-<n> in the lessons file → skip.
3. Go to **Waiting loop**; never end this turn while the milestone is open.

## Waiting loop

Repeat until the milestone is closed: `$S/milestone-wait.sh <slug> --caller tm --sources answers,watcher,status,inbox`
in the foreground, Bash tool `timeout: 600000` (the default 2 min would kill it); add `--timeout 120` while a
background suite runs. After every return (exit 0 or 3) run the
**Idle check** (no text unless it acts). Exit 0, or a background suite finished → act on it (**Sessions**,
**Run**, inbox below), start what is now due, update `status.md` on a phase change, wait again. Never end the turn to
wait, never use Monitors, never ask anyone in chat.

## Idle check (after every wait return; first matching row; never just keep waiting with open work)

Running = an open assignment or review request (no `.done`, no answer yet), a background suite, or a watcher merge
you wait for (`per task`).

| State (from `status.md`, the inboxes, `$C/answers/`, `$BNG cli`, git) | Next action |
|---|---|
| an answer not yet acted on | act on it (**Run**) |
| an open assignment or request without an answer 60 min after it was written, or its session ended | **Sessions**, Limits |
| a ready task (Dispatch) and an idle worker | dispatch it |
| task reviewed, last findings blocking, no open assignment | a fix assignment |
| task reviewed, nothing blocking, not merged / not In Review | your merge (`milestone`) or In Review (`per task`) |
| every task merged (except `escalation`, `milestone-review`), gate not green for the latest merge | the next gate step |
| only the maintainer can move: open escalation task, tasks In Review, the milestone review task | wait (the coordinator signals 👀/⚠️) |
| something is running | wait |
| none of the above, milestone open | log `failed stuck: <one-line state>` once per distinct state (not if the last `failed stuck` line has the same state), keep waiting (the coordinator shows ⚠️) |

## Reporting (files only; the maintainer is not in the chat loop)

- `$C/milestone/status.md` on every phase change (phase, tasks per status, open escalations, last test report and
  review ids, one line per session of the set: `session: <session-id> <worker-1|worker-2|review> <assignment or
  request id|idle> since <UTC time>`; ≤ 25 lines).
  Append one line per event to `$C/milestone/events.log`: `<UTC time> tm M<n>: in review <TASK-ids>` |
  `escalation <TASK-id>` | `gate green <report>` | `starts pending <n>` | `merged into main` | `failed <one line>`.
- **Escalation** (anything only the maintainer decides, e.g. fix or defer, an unclear requirement, a limit reached):
  `$BNG cli task create "Escalation: <question>" -m <milestone> -l escalation`, description: context, options, what
  waits on it; log `escalation <TASK-id>`. Only the work that depends on it waits. The maintainer answers in its notes
  and sets it Done on the board; `status` shows that → read the answer, record it in the affected task's notes.
- **Inbox** `$C/milestone/inbox/tm/` (from the coordinator; rename each file to `.read` as soon as you have acted on
  it, e.g. once the gap tasks exist; `milestone-wait.sh` reports it on every call until then): `gaps` → one gap task
  per `SC-<n>` gap, then **Run** and the gate again; `rejected` → one fix task per point, then **Run** and the gate on
  the new commits only; `starts-done` → the listed replacement runs, write its assignment or request again;
  `cancel` → assign nothing new, write `end` to the three inboxes, log `failed cancelled`, end the turn.

## Sessions (D13; INTERFACES, Sessions and hand-overs: keys and answers)

The coordinator starts `worker-1`, `worker-2` and `review` once, with you. You write files; they answer by files.
- **Assign** a task run to an idle worker (all its assignments `.done`): `$C/milestone/inbox/<slot>/<k>-work-<task-id>-
  <k>.md` with `id`, `answer: $C/answers/work-<task-id>-<k>.md`, `task`, `parent` (sub-task), `worktree`, `mode`,
  `findings` (fix), `from` (merge-in), `lessons`, `review: <next review id>|none`, `diff-base: <sha>`. Prefer the
  worker that had the task before (same worktree). The worker hands the finished task to the review session itself.
- **Worker answer** (`answer .../work-...md`): `result: done` + `review: <id>` → its review is under way, wait for the
  review answer; `review: none` → next sub-task (Run). `result: blocked` → Run.
- **Review answer** (`answer .../review-...md`): read `<review>.findings.md`; Pareto rule (`references/reviews.md`);
  then Run (fix assignment, merge or In Review), minor findings → the report list, lessons. No review answer → Limits.
- **Milestone review** (gate c): write the diff and the request `$C/milestone/inbox/review/m<n>-g<k>.md` yourself
  (`types: milestone`, `tree:` the milestone checkout; `references/reviews.md` §3).
- **Limits**: no answer 60 min after an assignment or request (a guess), or its session ended its turn (the app's
  list of linked sessions) → rename the open file to `.done` (it gets no answer), write
  `$C/milestone/starts/<slot>-m<n>-<k+1>.md` (`cwd:` the main checkout, `title:`, `replaces: <slot>-m<n>-<k>`, then the
  prompt from INTERFACES) and log `starts pending 1`; on `starts-done` write the assignment again (worker: `mode:
  resume`) or the request again (same review id); fails again → escalate.
- **End**: milestone merged into `main` or cancelled → `end` to the three inboxes.

## Run

- **Statuses only at start and merge** (overhead cut 4): In Progress once (`$BNG start`), Done once (your merge in
  `milestone` mode; the app in `per task` mode). Fixes, merge-ins, resumes and aborts change notes only; set In
  Progress again only for the two guards (an aborted watcher merge in `per task` mode; a parent backlog-ng set In
  Review by itself). Notes: one append per phase (implemented, reviewed, merged), ≤ 10 lines.
- **Follow-ups don't regrow the task count** (D10): findings are fix assignments on the same task and branch, then
  re-reviewed; new tasks only for gaps, regressions, sync and compensation, within the milestone size cap; anything
  else beyond the goal or the cap → escalation task; minor findings → the report list.
- **Dispatch**: ready = To Do, not labelled `escalation` or `milestone-review`, not a sub-task, dependencies merged,
  expected files don't overlap a running task. Per task: `$BNG start <id>` yourself (one at a time), then assign it
  to an idle worker with `mode: implement`, `review: task-<id>-r1`, `diff-base: <merge-base>`.
- **Sub-tasks** (steps of one task; INTERFACES, Task status and merges): never `$BNG start` a sub-task. Start the
  parent, then assign its sub-tasks one after another in the parent's worktree (`task: TASK-<sub-id>`, `parent:
  TASK-<id>`, `mode: implement`); a sub-task's status changes once, to Done. Parent diff ≤ ~400 lines: `review: none`
  for every sub-task but the last, which gets the review of the whole parent (`diff-base:` the parent's merge-base);
  set each Done after its run. Larger: `review: task-<sub-id>-r<n>`, `diff-base:` the parent's head before the
  sub-task (Pareto per sub-task, fixes `task: TASK-<sub-id>`, `mode: fix`); nothing blocking → set it Done (note "agent-reviewed; manual review with
  TASK-<id>") and tick the parent AC it covers. The last sub-task is set Done only right before the parent goes In
  Review or is merged (backlog-ng may set a parent In Review by itself once its last sub-task is Done). After the
  last: the review of the **whole parent** (all fitting types; the last sub-task's assignment carries it), then In
  Review or your merge. A parent that went In
  Review without you → back to In Progress with a note; In Review only after its validated agent review. Fixes after
  a rejection or an aborted merge are for the parent.
- **`result: blocked`** → answer from the plan (task and milestone review task descriptions) if it is in there;
  otherwise escalate. Record the answer in the task notes, then assign `mode: resume`.
- **Review answer** → Pareto rule in `references/reviews.md`. Blocking findings → assign `mode: fix`, `findings:` the
  findings file, `review:` the next round id, `diff-base:` the reviewed commit.
- **Nothing blocking** → note the review rounds and findings' fate, tick the DoD items except "Manual review
  approved", then by review mode:
  - `per task`: set In Review (`$BNG cli` in the task's worktree), log `in review <ids>`; the rest of this list.
  - `milestone` (default): merge it yourself, one task at a time, in your milestone checkout: `git merge --no-ff
    --no-commit <task-branch>`, `$S/milestone-test.sh minimal <milestone checkout>`; green → commit `Merge TASK-<id>:
    <title>`, set the task Done (note "agent-reviewed; manual review with the milestone"). Red or conflict → `git
    merge --abort`, assign `mode: merge-in`, `from: milestone-<slug>`, `diff-base: <merge-base>` (re-review of the
    whole task, not a Pareto round),
    merge again; twice → escalate. No In Review, no watcher, no rejection loop for the task. (Interim until
    backlog-ng's agent finish exists, open point #40; then: agent finish, the watcher merges.)
- **Rejected** (`per task`; status poll: In Review → In Progress, the points in the notes) → assign
  `mode: fix`, agent re-review of the fix commits (not a Pareto round), In Review again.
- **Watcher** (`per task`): `merged ...` → the task is in the milestone branch (branch and worktree are gone).
  `auto-merge aborted` (conflict or verify failed) → In Progress with the reason in the notes, assign
  `mode: merge-in`, `from: milestone-<slug>`, re-review of the whole task diff (not a Pareto round), In Review again;
  aborted twice → escalate. `auto-merge waiting` > 15 min (a guess) → escalate. **Approved but not merged** (not for
  sub-tasks; in `milestone` mode your own merge commit counts as merged and `skipped` lines are ignored): Done, no
  `merged` line 5 min later, or `auto-merge skipped` while Done → wait 30 s, `$BNG finish <worktree>` from the main
  checkout, once; still not merged 5 min later → escalate.
- **Lessons**: a confirmed critical/major finding caused by a basic mistake → entry in the lessons file (format:
  `references/reviews.md`), committed `lessons: L-<n> <title>` on that task's branch, in its worktree, while no
  assignment for it is open. Repeat of an existing lesson → add to `seen:` and create a task that turns it into a test,
  lint or hook.

## Gate (once every task except `escalation` and `milestone-review` tasks is merged; gate run k = 1, 2, ...)

Refresh the milestone checkout first.
a. `git merge-base --is-ancestor main milestone-<slug>` fails → sync task (`mode: merge-in`, `from: main`), reviewed
   and then merged like any task (types by size; by review mode: your merge or In Review).
b. `$S/milestone-test.sh full <milestone checkout>` with the Bash tool's `run_in_background: true` (a suite can
   outlast one 10-min call), keep waiting, read the report when it finishes; the same for `bisect`. Exit 1 →
   `milestone-test.sh bisect`, one regression task per cause. Exit 2 → escalate. Flaky tests are listed, never block.
c. Milestone review `m<n>-g<k>` (**Sessions**, Milestone review; type `milestone`; gate run 1: diff against `main`; later runs:
   only the commits since the last milestone review).
d. One fix round: regression and fix tasks together through **Run**, then the full suite once more. Critical/major
   findings or failing tests left → escalate "fix or defer". Minor findings → the milestone report's list (no tasks).
e. Log `gate green <full-suite report>` with the review ids in `status.md`.

## After the hand-off

The coordinator owns the milestone review task. Keep waiting for the review branch's watcher lines: merged into
`main` → log `merged into main`, `end` to the three inboxes, end the turn. `auto-merge aborted` → `references/merge-recovery.md`, then log
`gate green` (the coordinator writes the addendum).
