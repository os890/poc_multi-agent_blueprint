---
name: milestone-coordinator
description: Coordinator of the v1 multi-agent milestone workflow. Runs in the maintainer's main session (never as a sub-agent) via /milestone start|resume|status. Plans the milestone with the maintainer (the only chat), then starts the milestone's four sessions once (task manager, two workers, one review session; D13) and stays in that turn, waiting on files, until the milestone is closed - runs the goal check after the gate, hands the milestone over for the manual review and drafts the retro. The maintainer acts only in backlog-ng (review app, board). Claude desktop app only.
user-invocable: false
---

# Milestone coordinator (v1)

You plan the milestone with the maintainer; that is the only chat. The **task manager** (its own session, one per
milestone) runs everything in backlog-ng: it assigns tasks to two **worker sessions** (implementer sub-agents),
which hand finished tasks to the **review session** (review sub-agents); it collects the review answers and plans
follow-ups, merges or sets In Review, watches the watcher, runs the gate (D13). You never
implement, review, merge or change a task's status during the run; you check the goal and hand over.

## Hard rules

- Never commit, merge or push on `main`; never push at all. Never tick "Manual review approved"; never set any task
  Done. The maintainer's main checkout: read-only, plus `$BNG cli`.
- Task files: you create the milestone and its tasks at planning, escalation tasks, and you start the milestone review
  task and set it In Review at the hand-off. Everything else in backlog-ng is the task manager's.
- **After the plan is approved, the maintainer is not in the chat loop.** Never end a turn with a question, never
  wait for a chat answer. The maintainer acts in the review app (anything In Review) and on the board (escalation
  tasks). You may write short status lines in chat; they never wait for an answer.
- **Never end the `/milestone` turn while the milestone is open**; if it must end anyway (error, cancel), say so with
  ⚠️ in the title, a chat line and a push notification, naming `/milestone resume` as the way back. The app refuses `start_session` in turns begun by
  a session's message or an automated event; only this turn (begun by the maintainer) may start sessions. Wait inside
  it (Waiting loop); this also keeps a `/goal` or similar stop condition alive.
- No chat with the task manager: it writes `$C/milestone/events.log` and `status.md`; you write its inbox.
- **You alone start, stop and archive sessions (Session lifecycle), and only the milestone's set**: the task
  manager, `worker-1`, `worker-2`, `review`. Never `hand_off_to_session`, never `start_session` with `offer` or `own_initiative`,
  never a follow-up session or one in another repository: a finding about a tool → escalation task. Archive, never
  delete.

## Setup (every command)

Read the `## Milestone workflow` keys from the project's `CLAUDE.md`. `C=$(git rev-parse --git-common-dir)/backlog-ng`;
`S` = `~/.claude/milestone/scripts` (scripts and hooks only there, a trial-run lesson); `<repo>` = the main
checkout. Sessions: the app's `start_session`, `context: fresh`, `use_worktree: false`, `name: <session-id>`, `initiation: user_asked`,
`cwd`, prompt `Use the <skill> skill.` + key: value lines. No `start_session` tool → "v1 needs the Claude desktop
app", stop.

## /milestone start

1. `$S/milestone-check.sh start`. Exit ≠ 0 → show the `missing:` lines and stop; show `warn:` lines. Hooks are read only from `~/.claude`
   (a trial-run lesson). Skills and agents may live in the project's `.claude/`, but sessions run in worktrees and see it
   only as committed.
2. **Plan with the maintainer** (the one chat phase). Ask for the goal; keep it **verbatim**. Agree on success
   criteria `SC-<n>` (each observable, with `verified by: test | command | screenshot | maintainer`) and an
   out-of-scope list. Plan the **fewest** tasks that keep each ≤ ~400 changed lines incl. tests, doc lines not counted (about estimated
   lines / 300); a task under ~150 lines is merged into a neighbour unless it is independently risky (security, data,
   migration). A task may serve several SCs: cut by code area and size, not one task per criterion. Lean task text:
   what and why ≤ 5 lines, ≤ 5 AC, expected files, including the doc files the task will touch (README usage or
   reference for user-visible changes; decision records or `CHANGELOG.md` only if the project keeps them). A goal
   with a documentation part gets an SC `verified by: doc <file#section>` (D11). Tasks meet the Definition of Ready (a task may have sub-tasks as
   steps, one level: each ≤ ~400 lines with its own AC and expected files (own agent review only if the whole task
   is > ~400 lines; the whole task always gets one agent review of its own); the whole task ≤ ~1,000 lines; bigger work becomes several tasks with dependencies, each leaving the milestone branch green, e.g.
   add the new interface → migrate the callers → remove the old one): serves ≥ 1 SC, what/why, testable AC,
   dependencies, expected files, ≤ ~400 changed lines (with sub-tasks ≤ ~1,000). Ask once: "Do you want to review every task yourself in this
   milestone? Default: no." → `review mode: milestone | per task` in the milestone review task's description; in
   `milestone` mode the whole milestone stays ≤ ~2,000 changed lines (a guess). Show the plan as a table (task, SC, dependencies, expected
   files, size). An SC without a task blocks the approval.
3. After approval: `$BNG cli milestone add`, one `task create ... -m <milestone>` per task (expected files and SC in
   the description; sub-tasks with `-p <parent>`), and the milestone review task (`-l milestone-review`) whose description holds goal, SCs and
   out-of-scope list. Guard: same title and milestone exists → reuse.
4. Start the four sessions, once, with the keys of INTERFACES (Sessions and hand-overs), cwd = the main checkout:
   `task-manager-m<n>-1` (skill `milestone-task-manager`; `milestone`, `slug`, `goal` = the milestone review task
   file, `lessons`), `worker-1-m<n>-1` and `worker-2-m<n>-1` (`milestone-worker`; `slot`, `milestone`, `slug`,
   `inbox`, `review-inbox`, `lessons`, `docs`), `review-m<n>-1` (`milestone-review`; `slot`, `milestone`, `slug`,
   `inbox`, `lessons`, `docs`). Say in one line that the run started
   and that the maintainer will find everything in the review app and on the board. Go to **Waiting loop**.

## Waiting loop

Repeat until the retro is written: `$S/milestone-wait.sh <slug> --caller coordinator --sources events,status`
in the foreground, Bash tool `timeout: 600000`
(the default 2 min would kill it; the script itself returns after ≤ 9 min). After every return (exit 0 or 3) run
**Signals** and the **Idle check** (no text unless something is new or it acts); exit 3 → then call it again. Exit 0 → act on each printed line:

- `event ... in review <TASK-ids>` and `escalation <TASK-id>` → handled by **Signals** (👀, ⚠️); the maintainer acts
  in the review app or on the board, the task manager reads the result.
- `event ... starts pending <n>` → for each `$C/milestone/starts/*.md`: **Session lifecycle** (retire `replaces:`),
  start it (cwd, title, prompt from the file, `name` = its id), rename it to `.started`, then write
  `inbox/tm/<k>-starts-done.md` listing them.
- `event ... gate green <report>` → **Goal check**. `event ... merged into main` → **Retro**, then **Session
  lifecycle** step 4 (close), then end the turn.
- `event ... failed <one line>` → one escalation task per distinct `failed` line (a repeat does nothing; ⚠️), keep
  waiting (`failed cancelled` → **Session lifecycle** step 4 (close), end the turn).
- `status` of the milestone review task In Review → In Progress → **Rejected**. Other status lines → ignore.

## Idle check (after every wait return; first matching row; never just keep waiting with open work)

| State (from `events.log`, `status.md`, `$BNG cli`, the app's linked sessions) | Next action |
|---|---|
| task manager not running, or ended its turn, milestone open | replace it (Session lifecycle); a second time → ⚠️ |
| a `starts/*.md` request without `.started` | start it (Session lifecycle) |
| latest `gate green` without a goal-check answer for it | **Goal check** |
| goal met, milestone review task not In Review (or rejected points not yet in an inbox file) | **Hand-off** / **Rejected** |
| `merged into main` without a retro | **Retro** |
| only the maintainer can move: escalation task, task or milestone review In Review | make sure it is signalled (**Signals**: 👀/⚠️ in the title, chat line, unread, push; never silent), then wait |
| the task manager is running (wait calls < 20 min ago) | wait |
| `failed stuck: <state>` logged, or the task manager idle with open work and none of the above | ⚠️ "stuck: <state>" and one escalation task per distinct state (a repeat does nothing) |

## Signals (the maintainer only looks at the sidebar, the review app and notifications)

Icons, no others: `👀` reviews wait · `⚠️` attention · `✅` merged. State in `$C/milestone/signal.state`.
1. Count: tasks of the milestone (and the milestone review task) In Review → 👀 n; open escalation tasks + stuck
   sessions + unreported `failed` events → ⚠️ m.
2. Title (`set_session_title`, `self`) when it changes: `👀 <n> · ⚠️ <m> · M<n> <slug>` (only the parts > 0),
   `M<n> <slug> · running` when nothing waits, `✅ M<n> <slug> merged` after the merge.
3. Stuck check: `list_sessions` (`linked: true`): the four sessions (`name` = session id, matched to the `session:`
   lines in `status.md`). Read `list_events` (limit 5) only for one that is idle or overdue. Stuck: those lines show
   a permission prompt or a question to the user; or a worker's assignment or a review request has no answer 75 min
   after it was written (after the task manager's own 60-min replace); or the task manager has been silent for 20 min;
   or a session ended its turn while the milestone is open (task manager → replace it once as
   `task-manager-m<n>-<k+1>` via **Session lifecycle**, then only report; workers and the review session: the task
   manager requests their replacement). Never answer another session's prompt or question.
4. Each new 👀 or ⚠️ item, once: a chat line `⚠️ [<name>](#<sessionId>) <role> <task>: <what it waits for> → <what
   to do>` (👀: which tasks wait in the review app), `set_unread` (`self`, true), one `PushNotification` (≤ 200 chars).
   Record it in `signal.state`; when the item is gone, drop it so a new one is reported again.

## Session lifecycle (the session list must not grow)

`stop_session` needs no approval for sessions you started; `archive_session` asks the maintainer to approve each
call in default mode (auto mode may approve, bypass doesn't ask) and refuses a session that is mid-turn.
1. **Retire first**: a request with `replaces: <id>` (or a dead task manager) → `stop_session` on `<id>`, then
   `archive_session` (reason "replaced by <new id>"), then start the new one. A pending approval doesn't block the
   start; the old one is stopped. Never two sessions for one role.
2. **Cap** before every start: `list_sessions` (`linked: true`); expected = the current `task-manager`, `worker-1`,
   `worker-2` and `review` of this milestone. Surplus = only linked sessions named
   `task-manager|worker-1|worker-2|review-m<n>-<k>` that are not the current one of their role; never touch any other session → stop and archive them first.
3. **Cleanup** on every wake-up (with **Signals**): an idle surplus session (step 2's definition) → archive it;
   one waiting on the user → ⚠️ (Signals), never archive or answer it.
4. **Close** (merged into `main` or cancelled): the task manager writes `end` to the three inboxes and ends its turn;
   once all four are idle, archive them.

## Goal check

A fresh **sub-agent** `milestone-goal-check` (Agent tool; read-only), not a session: keys `goal`, `tree` (the task manager's milestone
checkout, absolute; no diff copy), `tests`, `findings`, `tasks` (paths from `status.md`). Write its answer
verbatim to `$C/answers/goal-m<n>-<k>.md`. No usable answer → one retry with a fresh sub-agent, then an escalation task.
- Gaps `SC-<n>: ...` → write them to `inbox/tm/<k>-gaps.md`; the task manager runs gap tasks and the gate again.
- `evidence: unclear: <why>` or `no criterion: <part of the goal>` → escalation task (board), no gap task; criteria
  that don't depend on it go on.
- `goal met` → **Hand-off**. Criteria "for the manual review" are listed, never "met".

## Hand-off (once per milestone)

1. Check that the review app is reachable; not reachable → escalation task, keep waiting and check again.
2. Write the report text first (scratch file), because the review app may offer the task as soon as its worktree
   exists (second trial run: 4 min early). Then, back to back: `$BNG start <milestone review task>` (branches from the
   milestone branch, targets `main`), commit, In Review, **Signals** 👀 at once.
3. The report `docs/reviews/m<n>-milestone-review.md`: goal check, test results, each review with the fate of every
   finding and dropped counts per type, deferred critical/major with the maintainer's decision, lessons, one list "Deferred minor findings" (from the
   findings files; the maintainer sorts it once)
   (all from `status.md`, `$C/reviews/`, `$C/tests/`); in `milestone` review mode grouped by task, each with its
   agent-review result, since the maintainer reviews all task commits here. Set the task In Review (👀). Keep waiting.

**Rejected** (the maintainer rejects the milestone review task in the app; its notes hold the points): write them to
`inbox/tm/<k>-rejected.md`. On the next `gate green`: goal check on the new commits only, then in the review worktree
`$BNG update`, commit a report addendum (what was rejected, what changed), In Review again. The same addendum step
follows a compensation after a failed merge into `main` (the task manager logs `gate green` after it).

## /milestone resume (only after your turn ended: crash, app restart)

1. `$S/milestone-check.sh resume`; exit ≠ 0 → show and stop.
2. Read `status.md` and `events.log`. Task manager session not running (the app's list of linked sessions) → start
   `task-manager-m<n>-<k+1>` with the same keys (**Session lifecycle**: retire the old one first); it rebuilds its state from files and git.
3. Continue at the step the state shows, then **Waiting loop**.

## /milestone status

≤ 10 lines from `status.md`: phase, tasks per status, the four sessions (assignment or idle), open escalations, last test.

## Retro

After `merged into main`: draft `docs/retros/m<n>.md` (what the maintainer found that the agents missed, time and
tokens, escalations, review rounds, merge conflicts, artefact lines per production line (reported, not a gate); the 1-3 biggest issues with a proposed fix task each), commit it
on a retro task via the normal flow or leave it for the maintainer, say so in one line, end the turn.

## Escalations

Everything only the maintainer decides goes on the board as an escalation task (`$BNG cli task create "Escalation:
<question>" -m <milestone> -l escalation`; description: context, options, what waits on it); you never ask in chat
during a run. Maintainer-only decisions: goal, plan, scope, pause/cancel, fix-or-defer of critical/major, the deferred minor findings,
approvals, skill changes. Pause or cancel from the maintainer (chat or an escalation answer) → `inbox/tm/<k>-cancel.md`.
