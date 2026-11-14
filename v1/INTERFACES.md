# v1 interfaces (binding for all v1 files; owner: architect)

Spec: `../blueprint-v1-draft.md`. This file fixes only names, formats and paths. Questions → architect, once.
**Runtime (decided by the maintainer): Claude desktop app only.** The coordinator is the maintainer's main session;
per milestone it starts **four sessions once**: the task manager, two worker sessions and one review session (D13,
maintainer: "workers should still be sub-sessions but they can create sub-agents per task and once ready hand over to
the review-sub-session which can use sub-agents for the different review topics and the task-manager collects the
results and plans followup tasks"). **Sessions supervise, sub-agents work.** No CLI fallback.

## Layout (skills, agents, command: `~/.claude/` or a project's `.claude/`, the project copy wins; scripts and hooks: always `~/.claude/milestone/`, a trial-run lesson)

| In `v1/` | Installed to | Owner |
|---|---|---|
| `skills/milestone-coordinator/` (main session; `/milestone` loads it) | `~/.claude/skills/` | architect |
| `skills/milestone-task-manager/` (SKILL.md, `references/reviews.md`, `references/merge-recovery.md`) | `~/.claude/skills/` | architect |
| `commands/milestone.md` (`/milestone start\|resume\|status`, main session) | `~/.claude/commands/` | architect |
| `skills/milestone-worker/` (worker session: one assignment at a time, implementer sub-agents, check, hand-over to review) | skills/ | architect |
| `skills/milestone-review/` (review session: review requests from workers and the task manager, review-type and validator sub-agents, answer to the task manager) | skills/ | architect |
| `skills/milestone-implementer/`, `agents/milestone-implementer.md` (the worker session's sub-agent: implements, fixes, merges in) | skills/, agents/ | re |
| `skills/milestone-goal-check/`, `agents/milestone-goal-check.md` (the coordinator's sub-agent) | skills/, agents/ | re |
| `skills/milestone-validator/`, `agents/milestone-validator.md` | skills/, agents/ | docs |
| `skills/milestone-review-type/` (+ `references/types/01-logic.md` … `11-test.md`), `agents/milestone-review-type.md` | skills/, agents/ | docs |
| `scripts/milestone-test.sh`, `scripts/milestone-check.sh`, `scripts/milestone-wait.sh` | `~/.claude/milestone/scripts/` | critic |
| `hooks/guard-main.sh`, `guard-rewrite.sh`, `guard-install.sh`, `guard-web.sh`, `settings-snippet.json` | `~/.claude/milestone/hooks/` | critic |
| `README.md` (install, `CLAUDE.md` keys, Known gaps) | – | docs |

Agent files exist only for sub-agents, each preloading its skill: implementer (`Read, Grep, Glob, Bash, Edit,
Write`), review-type, validator and goal-check (`Read, Grep, Glob`). A sub-agent never starts sessions or agents and
never messages anyone; it answers in its response to the session that started it.
Sessions exchange only files (Sessions and hand-overs); no session messages another.

## Project `CLAUDE.md` keys (section `## Milestone workflow`, one `- Key: value` line each)

`BNG`, `Minimal test command`, `Full test command`, `Single test command` (contains `{test}`), `Test reports`
(JUnit XML glob), `Docs to check against`, `Lessons file` (default `docs/lessons-learned.md`), `Watcher log`,
`Supported platforms`.

## Paths (`<C>` = `$(git rev-parse --git-common-dir)/backlog-ng`, shared by all worktrees, not versioned)

| What | Path | Written by |
|---|---|---|
| review ids | `task-<id>-r<n>` (task review round n), `m<n>-g<k>` (milestone review, gate run k) | – |
| diff | `<C>/reviews/<review>.diff` | the worker session (task reviews), the task manager (milestone review) |
| raw findings | `<C>/reviews/<review>.raw.md` (all review-type answers, each under `type: <type>`; only if one has a finding) | review session |
| reproductions | `<C>/reviews/<review>.repro.md` (one line per finding: `<type> f<k>: reproduced\|not reproduced\|error <log>`) | review session |
| validated findings | `<C>/reviews/<review>.findings.md` (the validator's answer verbatim, or `result: 0 confirmed, 0 dropped`; the merge hook needs it) | review session |
| answers | `<C>/answers/<id>.md` (worker: `work-<task-id>-<k>`; review: `review-<review id>`; coordinator: `goal-m<n>-<k>`), written last, atomically (`.tmp`, then `mv`); its existence means done | each session |
| test log and report | `<C>/tests/<suite>-<short-sha>.log`, `.md` | test script |
| task notes, AC | task file via `$BNG cli` in the task's worktree | the worker's implementer sub-agent while its assignment runs; task manager otherwise; never while In Review |
| lessons file | committed on the task branch of the task where the lesson was found (reaches the milestone branch with that task) | task manager |
| milestone review report | `docs/reviews/m<n>-milestone-review.md` on the review task's branch | coordinator |
| retro note | `docs/retros/m<n>.md` | coordinator + maintainer |
| task manager status | `<C>/milestone/status.md` (phase, tasks per status, pending starts, open escalations, then one line per session of the set: `session: <session-id> <worker-1\|worker-2\|review> <assignment or request id\|idle> since <UTC time>`; ≤ 25 lines, rewritten after every step) | task manager |
| signal state | `<C>/milestone/signal.state` (last title, flags already reported) | coordinator |
| events | `<C>/milestone/events.log`, one line appended per event: `<UTC time> tm M<n>: <event>` (events below) | task manager |
| inbox | `<C>/milestone/inbox/<reader>/`, one folder per reader: `tm/<k>-<kind>.md` (`gaps`, `rejected`, `cancel`, `starts-done`; from the coordinator), `worker-1/`, `worker-2/` (`<k>-work-<task-id>-<k>.md` assignments, `<k>-end.md`; from the task manager), `review/` (`<review id>.md` requests from a worker or the task manager, `<k>-end.md`). The reader renames each to `.read` (assignments and requests to `.done` once answered) | see per folder |
| start request | `<C>/milestone/starts/<session-id>.md`: `cwd:`, `title:`, `replaces: <session-id>`, then the prompt; only for replacing a dead or hung worker or review session; renamed to `.started` by the coordinator | task manager |
| escalation | a **board task**: `$BNG cli task create "Escalation: <question>" -m <milestone> -l escalation`, description: context, options, what waits on it. The maintainer answers in its notes and sets it Done on the board | task manager or coordinator, then the maintainer |

Review types (overhead cut 2/3; the review session selects them, the milestone review is always `milestone`): task review with a diff ≤ ~150 lines → one sub-agent `combined` (checklists 01, 02,
11, 04); larger → `logic-code-test` (01, 02, 11), `security` (04), and only if their trigger files changed
`architecture` (03), `data-safety` (05), `cross-platform` (06), `dependencies` (07), `usability` (09). Milestone review:
one sub-agent `milestone` (01 across tasks + 03 + 08 product docs, D11), `dependencies` only if lock files changed. The validator runs only if
there is at least one raw finding; otherwise the review session writes the findings file itself (`result: 0 confirmed, 0
dropped`), because the merge hook needs it.

## Roles and reporting

| Role | Kind, started by | Owns |
|---|---|---|
| worker session (`worker-1-m<n>-<k>`, `worker-2-m<n>-<k>`) | started once by the coordinator; cwd = the main checkout | one assignment at a time: implementer sub-agents in the task's worktree, the check, the diff and the review request (hand-over), its answer to the task manager |
| review session (`review-m<n>-<k>`) | started once by the coordinator; cwd = the main checkout | one review request at a time (from a worker or the task manager): type selection, review-type sub-agents, reproductions, validator, findings file, answer to the task manager |
| coordinator | the maintainer's main session (`/milestone`) | planning with the maintainer (the only chat), goal check, hand-off (milestone review task, report, In Review), rejection of the milestone, retro |
| task manager | one session per milestone (`task-manager-m<n>-<k>`, k = 2, ... after a restart; cwd = the main checkout), started by the coordinator | everything in backlog-ng during the run: task files and statuses via `$BNG cli`, `$BNG start`, the milestone branch and its milestone checkout, assignments to the worker sessions, the milestone review request, collecting review answers and planning follow-ups (Pareto, fix tasks, lessons, minor list), In Review, the watcher log, merge-in fixes, the gate (test script, milestone review), merge recovery |

- **The maintainer is not in the chat loop during a run.** After the plan is approved, nobody asks in chat and
  waits. The maintainer acts in backlog-ng only: the review app (tasks and the milestone review task In Review) and
  the board (escalation tasks). An open escalation blocks only the work that depends on it.
- **Waiting model: the allowed turn never ends.** The app refuses `start_session` in a turn begun by another
  session's message or an automated event (Monitor line, notification); there is no way around that. So the
  coordinator stays in the maintainer's `/milestone` turn, and the task manager, the workers and the review session
  each in their first turn, until the milestone is closed. All wait with `milestone-wait.sh` in the foreground (≤ 9
  min per call, repeated; Scripts), act on what it prints, and wait again. No Monitors, no messages between them,
  never a question to the maintainer in chat; a `/goal` or similar stop condition is kept alive by this waiting.
- **Task manager → coordinator**: `events.log` lines and `status.md`. Events: `in review <TASK-ids>` |
  `escalation <TASK-id>` | `gate green <report>` | `starts pending <n>` | `merged into main` | `failed <one line>` (incl. `failed stuck: <state>`).
- **Idle check (trial-run finding: "if all sub-sessions are idle the coordinator has to act")**: after every wait
  return (exit 0 or 3) both sessions derive the next step from the state files and git, not only from the wait's
  lines (a missed event must not stall the run). Nothing running + open work + no step that only the maintainer can
  take is a defect: do the step, or log `failed stuck: <state>` (task manager) / signal ⚠️ with the reason
  (coordinator). Waiting is right only while something runs (an open assignment or review request, a suite, a watcher merge) or
  the next step is the maintainer's (open escalation task, a task or the milestone review In Review); then
  👀/⚠️ show it, always, also when nothing else happens. Decision tables: the task-manager and coordinator skills, section Idle check.
- **Coordinator → task manager**: inbox files only (`inbox/tm/`: `gaps`, `rejected`, `cancel`, `starts-done`).
- **Who starts which session: only the coordinator** (Session lifecycle): the task manager and the three sessions
  of the set, once at milestone start; replacements on the task manager's request (`starts/`, event `starts
  pending`). Everything else is a sub-agent: the workers' implementers, the review session's review types and
  validator, the coordinator's goal check. If the coordinator's turn itself ended (crash, app restart), the run waits
  for the maintainer's `/milestone resume`, the one chat action left.

## Signals to the maintainer (coordinator only; tools verified in a started session: `set_session_title`, `set_unread`, `PushNotification`, `list_sessions`, `get_session`, `list_events`)

Icons, no others: `👀` reviews wait for the maintainer (tasks or the milestone review task In Review) · `⚠️`
attention (open escalation task, stuck session, `failed` event) · `✅` milestone merged into `main`.

- **Title** of the coordinator's own session (`set_session_title`, `self`): `👀 <n> · ⚠️ <m> · M<n> <slug>`, a part
  only when its count > 0; `M<n> <slug> · running` when nothing waits; `✅ M<n> <slug> merged` at the end. Set only
  when it changes.
- **On a new 👀 or ⚠️ item** (not reported before, per `signal.state`): one chat line starting with the icon, the
  session marked unread (`set_unread`, `self`), and one `PushNotification` (≤ 200 chars, what to do first).
- **Stuck sessions**, checked on every wake-up of the coordinator's wait loop, for the linked family
  (`list_sessions` with `linked: true`; `name` = session id; role and task from `status.md`):
  - waits on the user: the last lines (`list_events`, limit 5) show a permission prompt or a question to the user;
  - silent: the task manager has had no activity for 20 min (it wakes at least every 9 min); an assignment or request
    without an answer 75 min after it was written (after the task manager's own 60-min replace); sessions report no
    liveness (no heartbeat files);
  - ended its turn while the milestone is open (every session of the set stays in its first turn).
  Report each once: `⚠️ [<name>](#<sessionId>) <role> <assignment>: <what it waits for> → <what to do>`. Never answer
  a prompt or a question of another session. A task manager that ended is restarted once (`task-manager-m<n>-<k+1>`),
  then only reported; dead workers or review sessions are replaced on the task manager's request.

## Session lifecycle (the session list must not grow)

Tools verified in a started session: `stop_session` (no prompt for a session the caller started) and
`archive_session` (asks the user to approve each call in default mode; auto mode may approve, bypass does not ask;
refuses a session that is mid-turn). So the coordinator, the maintainer's session, owns the whole lifecycle.

1. **Only the coordinator starts sessions**, and only the set: `task-manager-m<n>-<k>`, `worker-1-m<n>-<k>`,
   `worker-2-m<n>-<k>`, `review-m<n>-<k>`, cwd = the main checkout of this project, all four once at milestone start. No v1 session uses
   `hand_off_to_session`, `start_session` with `offer` or `own_initiative`, or starts any other session (no follow-up
   sessions, nothing in another repository). A finding about a tool (backlog-ng, the app) → escalation task.
2. **A replacement retires its predecessor first**: a dead or hung task manager, or a request with `replaces:` →
   the coordinator runs `stop_session` on the predecessor, then `archive_session` (reason "replaced by <new id>"),
   then starts `<role>-m<n>-<k+1>`. Never two sessions for one role; a still-pending archive approval doesn't block the
   start (the predecessor is stopped).
3. **Cap**: coordinator + task manager + 2 workers + 1 review session. Before every start, `list_sessions`
   (`linked: true`): surplus = only linked sessions whose name matches `task-manager|worker-1|worker-2|review-m<n>-<k>`
   and that are not the current one of their role; never touch any other session → stopped and archived first.
4. **Cleanup** on every wake-up of the coordinator: an idle surplus session (as in 3) → archive it
   (one waiting on the user → ⚠️ instead, never archive or answer it). Milestone closed (merged into `main` or
   cancelled): the task manager writes `end` to the three inboxes and ends its turn; once all four are idle, archive
   them.
5. **Archive, never delete**: archiving keeps the transcript for the retro; `delete_session` is never used.

## Review mode per milestone (maintainer, 2026-11-14)

"Per milestone should be the default and users can request a review per task ... but users need to ask for it
actively." The coordinator asks once at planning ("Do you want to review every task yourself in this milestone?
Default: no") and writes `review mode: milestone | per task` into the milestone review task's description.

| | `milestone` (default) | `per task` (opt-in) |
|---|---|---|
| agent review | every task, of the **whole task** (all fitting types; a parent with sub-tasks additionally per sub-task where D9 has it) | the same |
| manual review | once, the milestone review task before `main` | every task (In Review) + the milestone review |
| merge into `milestone-<slug>` | **interim:** the task manager, after the agent review: `git merge --no-ff --no-commit` in its milestone checkout (not detached), minimal suite on the result, commit `Merge TASK-<id>: <title>`, set the task Done. **Target:** backlog-ng's agent finish (open point #3), then the watcher merges | the watcher, after the maintainer's approval (below) |
| task In Review | never (the review app never offers the task) | after the validated agent review |
| milestone review shows | hand-merged task commits as open for the maintainer (no finished task review), grouped by task in the report | task commits as approved |
| milestone size cap (planning) | ~2,000 changed lines (a guess; calibrate in the dry run) | none beyond the task limits |

In `milestone` mode `guard-main.sh` allows on `milestone-*` only, with cwd = the milestone checkout
`<repo>.worktrees/milestone-<slug>`: a `--no-ff --no-commit` merge of a `task-<id>-*` branch that has a validated
findings file, and the commit completing it (Hooks). The task manager is the only one working there. In this mode the
maintainer reviews only the milestone review task: approving a task in the review app would add a second merge path. A merge that conflicts
or turns the minimal suite red → `git merge --abort`, merge-in assignment, re-review (not a Pareto round), merge again.

## Task status and merges (`per task` mode, and what both modes share; agents never merge into `main`)

| Change | Only by | When |
|---|---|---|
| milestone, tasks, milestone review task created | coordinator (`$BNG cli`) | planning, before the task manager starts |
| fix, gap, regression, sync, compensation tasks created | task manager | during the run, only these kinds and within the milestone size cap: review findings are fix **assignments** on the same task, not new tasks; minor findings → one list in the milestone report; anything else beyond the goal or the cap → escalation task (D10, D13) |
| To Do → In Progress | task manager (`$BNG start`) | dispatch, once: fixes, merge-ins, resumes and aborts change notes only (overhead cut 4). Exceptions: an aborted
watcher merge in `per task` mode (Done → In Progress → In Review, row below, so the merge-in commits get the manual
review), and a parent backlog-ng set In Review by itself |
| sub-task To Do → Done | task manager (informational, one change; Done once its agent review has nothing blocking) | Sub-tasks above |
| In Progress → In Review | task manager (`per task` mode only) | after a validated agent review with nothing blocking and the DoD ticked (except "Manual review approved") |
| In Progress → Done (merged) | task manager (`milestone` mode only) | right after its own merge into the milestone branch (Review mode per milestone) |
| In Review → Done + "Manual review approved" | review app (the maintainer) | manual approval |
| In Review → In Progress + note | review app (the maintainer) | rejection → fix assignment, agent re-review of the fix commits (not a Pareto round), In Review again |
| Done → merged into `milestone-<slug>` | backlog-ng watcher | after its quality gate (`tools/verify.sh`) |
| milestone review task: start, In Review | coordinator | hand-off, after `gate green` and the goal check |
| Done → In Progress + note | task manager (`per task` mode only) | the watcher's merge was aborted → merge-in assignment, agent re-review, In Review again |

**Sub-tasks: steps of one task, one manual review for the whole task** (maintainer, 2026-11-14: "no additional
manual reviews"; agent reviews may run where the design needs them, but always finish before In Review). A task may have sub-tasks (`$BNG cli task create ... -p <parent>`, one level) as fine-grained work steps:
- no sub-task branch or worktree: never `$BNG start` a sub-task; the task manager starts the parent, and each sub-task
  is one worker assignment in the parent's worktree (`task: TASK-<sub-id>`, `parent: TASK-<id>`), one after another,
  never two sub-tasks of one parent at a time;
- agent review by default **once, of the whole parent** after the last sub-task (all fitting types, as a task),
  when the parent's diff is ≤ ~400 lines. Larger parent (≤ ~1,000 lines) → agent review **per sub-task** on its own
  commit range (review id `task-<sub-id>-r<n>`, Pareto rounds per sub-task, findings fixed with `task: TASK-<sub-id>`,
  `parent:`, `mode: fix`) before the next sub-task starts, plus, as for every task, one full agent review of the **whole
  parent** (all fitting types; the whole picture). Then the parent goes on as a task (In Review or the task manager's
  merge, by review mode); no manual review per sub-task;
- sub-task status is informational and changes once: To Do → Done (never In Progress or In Review). The **task manager** sets a sub-task
  Done after its `done` (and its own agent review, where the parent has per-sub-task reviews), notes "manual review
  with TASK-<id>" and ticks the parent AC it covers (from its notes); the last one only right before the parent goes
  In Review. It sets them Done because the review app holds a parent's review while a sub-task is open; this is the
  one exception to "only the app sets Done", and nothing merges on it. A parent set In Review by backlog-ng itself is
  set back to In Progress;
- size: each sub-task ≤ ~400 changed lines; the whole parent ≤ ~1,000 lines (one manual review; a guess, calibrate
  in the dry run). Bigger work is still several tasks with dependencies.
- fixes after the parent's review, a rejection or an aborted merge are worker assignments for the parent (`task: TASK-<id>`).

Implementers never change a status. Nobody but the app ticks "Manual review approved"; nobody but the app sets Done, except
the task manager for sub-tasks (above) and for tasks it merged itself in `milestone` mode. In `per task` mode the task manager's
milestone checkout is **detached** and read-only (`git worktree add --detach`, refreshed with `git checkout --detach
milestone-<slug>`), so the watcher's merges never meet a checkout; no agent commits on the milestone branch. In `milestone` mode it is
checked out on `milestone-<slug>` and only the task manager's merges are committed there.

**Hard rule: hands off a task's worktree from In Review until it is merged or rejected.** No session or sub-agent runs
any command in it (not even `git status`, not `$BNG cli` there): a held `.git/.../index.lock` makes the watcher skip
the merge. Read a task branch from the main checkout (`git -C <repo> log|diff ... task-<id>-<slug>`). The one
exception is `$BNG finish <worktree>` below. The window also ends with an `auto-merge aborted` line for that task (the watcher has released the worktree);
then set In Progress as usual.

**Approved but not merged** (one rule; only in `per task` mode, and not for sub-tasks; in `milestone` mode the task
manager's own merge commit counts as merged, so `skipped` lines for those tasks are ignored): the task is Done and there is no `merged` line for it after 5 min, or an
`auto-merge skipped` line for it arrives while it is Done → wait 30 s, run `$BNG finish <worktree>` from the main
checkout once (the watcher's own finish step: commit board changes, rebase, verify, merge). Still not merged 5 min
later → escalation task. Until backlog-ng retries a skipped merge by itself this is the only
retry.

Watcher log lines the task manager waits for per task branch `task-<id>-<slug>` and the review branch
(`milestone-wait.sh`, source `watcher`):

| Line | Meaning |
|---|---|
| `merged <branch> into milestone-<slug> (TASK-<id>: ...) and deleted the branch` (or `squash-merged ...`) | merged; branch and worktree are gone |
| `auto-merge waiting (<branch>): <reason>` | verify running or bridge down; still waiting after 15 min (a guess) → escalate |
| `auto-merge aborted (<branch>): <reason>` | rebase/merge conflict or verify failed → status back to In Progress, merge-in assignment |
| `auto-merge skipped (<branch>): <reason>` | ignore while the task is not Done. Task Done (approved) → the "approved but not merged" rule below |

Rejections are not logged: `milestone-wait.sh` (source `status`) reports task status changes; In Review → In
Progress is a rejection, an escalation task set Done is an answer.

## Sessions and hand-overs (D13; prompt = `Use the <skill> skill.` + key: value lines)

| Session | Skill | Prompt keys |
|---|---|---|
| `task-manager-m<n>-<k>` | `milestone-task-manager` | `milestone: M<n> <title>`, `slug:`, `goal: <milestone review task file>`, `lessons:` |
| `worker-1-m<n>-<k>`, `worker-2-m<n>-<k>` | `milestone-worker` | `slot: worker-1\|worker-2`, `milestone:`, `slug:`, `inbox: <C>/milestone/inbox/<slot>/`, `review-inbox: <C>/milestone/inbox/review/`, `lessons:`, `docs:` |
| `review-m<n>-<k>` | `milestone-review` | `slot: review`, `milestone:`, `slug:`, `inbox: <C>/milestone/inbox/review/`, `lessons:`, `docs:` |

Started by the coordinator with the app's `start_session`, `context: fresh`, `use_worktree: false`, `name:
<session-id>`, cwd = the main checkout, `initiation: user_asked`. Each stays in its first turn: `milestone-wait.sh
<slug> --caller <slot> --sources inbox` → one file at a time → answer → wait again; `<k>-end.md` → end the turn.

**One task, three hand-overs** (one writer per file; nothing goes back and forth):
1. **Task manager → worker**: assignment `inbox/<slot>/<k>-work-<task-id>-<k>.md` with `id`, `answer:
   <C>/answers/work-<task-id>-<k>.md` and `task`, `parent` (sub-task; `worktree` is then the parent's), `worktree`,
   `mode: implement|fix|merge-in|resume`, `findings` (fix), `from` (merge-in), `lessons`, and **`review: <review id>`**
   (the next review id, e.g. `task-12-r2`; `none` for a sub-task without its own review, D9) plus `diff-base: <sha>`
   (`merge-base` for round 1 and after a merge-in; the reviewed commit for a fix round; the parent's head before the
   sub-task for a sub-task review).
2. **Worker → review session**: the worker has each run done by a fresh `milestone-implementer` sub-agent, checks it
   (new commits; `milestone-test.sh minimal <worktree>` green; task notes with a `docs:` line, D11; the diff only in
   the task's expected files or the notes say why), retries once with `mode: resume`. Passed and `review` ≠ `none` →
   it writes `git diff <diff-base>..<head>` to `<C>/reviews/<review id>.diff` and the request
   `inbox/review/<review id>.md` (`id`, `answer: <C>/answers/review-<review id>.md`, `review`, `diff`, `tree:
   <worktree>`, `scope: TASK-<id> r<n>`, `task`, `lessons`, `docs`), then its own answer to the task manager:
   `result: done`, `commit`, `summary`, `checked`, `review: <review id>|none`. Blocked or failed twice → `result:
   blocked` with `blocked:`, no request. After its answer the worker never touches that worktree again.
3. **Review session → task manager**: per request it selects the types (the request's `types:` if given, else by
   size and trigger files, table above), runs one fresh `milestone-review-type` each in parallel, the reproductions,
   one `milestone-validator` if a raw finding exists, checks that all answered, writes `<review>.findings.md` and the
   answer `review`, `result: <c> confirmed, <d> dropped`, `findings: <path>`. The milestone review request comes from
   the task manager (`types: milestone`, `tree:` the milestone checkout).

**The task manager collects and plans follow-ups**: it never runs sub-agents itself. On a worker answer: blocked →
answer or escalate; `review: none` → next sub-task. On a review answer: Pareto (`references/reviews.md`): blocking →
a fix assignment (`mode: fix`, `findings:`, next review id), to the same worker if it is idle; nothing blocking → its
merge or In Review; minor findings → the report list; lessons. The coordinator's goal check stays its own sub-agent.

| Sub-agent | Started by | Prompt keys | Answer |
|---|---|---|---|
| `milestone-implementer` | a worker session; fresh per run, foreground, one at a time | `task`, `parent`, `worktree`, `mode`, `findings`, `from`, `lessons` | `result: done\|blocked`, `commit: <sha>`, `summary:`, `blocked:` (if blocked) |
| `milestone-review-type` | the review session; one per type, in parallel | `type:`, `checklists: <path>[, <path>]`, `diff:`, `tree: <abs>`, `scope:`, `lessons:`, `docs:` | findings in the format below, or exactly `0 findings` |
| `milestone-validator` | the review session; once per review, only if a raw finding exists | `review: <id>`, `diff:`, `tree:`, `lessons:`, `raw: <C>/reviews/<review>.raw.md`, `repro: <path>` (optional) | header `review: <id>` / `result: <c> confirmed, <d> dropped`, then `finding` blocks (+ `type:`, `checked: read\|reproduced\|minor`) and `dropped` blocks (`type:`, `what:`, `reason: format\|scope\|no scenario\|duplicate of <k>\|not confirmed: <why>`) |
| `milestone-goal-check` | the coordinator; fresh, foreground | `goal`, `tree: <milestone checkout, absolute>`, `tests: <full-suite report>`, `findings: <paths>`, `tasks: <task file paths>` | one line per criterion `SC-<n>: met\|not met\|for the manual review - evidence: <...>`, then `result: goal met\|gaps`, `gaps: <list>` |

**Limits**: 2 workers, 1 review session. No answer 60 min after an assignment or request (a guess), or the session
ended its turn → the task manager renames the open file to `.done` (it gets no answer) and requests `<slot>-m<n>-<k+1>`
with `replaces:`; once it runs, the task manager writes the assignment again (worker: `mode: resume`) or, for a review,
the request again with the same review id; fails again → escalate. A restarted task manager rebuilds from the inboxes
(open files without `.done`), the answers and git.

Finding format (review types; the validator keeps it and adds `type:`/`checked:`):

```
finding <k>
severity: critical | major | minor
where:    path/to/file.ext:123 (changed line)
what:     one sentence: the defect
scenario: concrete input or state -> wrong result, crash, data loss, ...
fix:      one sentence
repro:    <existing test id or short command that shows it>   (optional; critical/major only)
lesson:   L-<n>                                               (only if a lesson is broken)
```

## Scripts (task manager: `full`, `bisect`, `minimal` on its merges; worker: `minimal`; review session: `repro`; all sessions: `milestone-wait.sh`; coordinator: `milestone-check.sh`)

- `milestone-test.sh minimal|full <dir>`: runs the suite in `<dir>` as it is (also an uncommitted merge result);
  each failed test once more alone → flaky. Exit `0` green, `1` red, `2` error (could not run). Last stdout line:
  `report: <path>`. Report: `suite`, `dir`, `commit`, `result: green|red|error`, `counts`, `log`, then `failed <k>`
  (`test`, `error`, `cause: merge of TASK-<id> (<sha>)|unknown`) and `flaky <k>` blocks.
- `full` and `bisect` can outlast one Bash call (10 min max): the task manager runs them with `run_in_background:
  true` and keeps waiting; `minimal` (≤ ~5 min) runs in the foreground.
- `milestone-test.sh bisect <good> <bad> <test>...`: own detached worktree under `<C>/tests/`, first-parent bisect
  with the single test command; fills `cause:`. Same exit codes and last line.
- `milestone-test.sh repro <dir> <command>`: runs one command, 5-min limit. Exit `0` command failed as the finding
  says (reproduced), `1` not reproduced, `2` error. Last line `report: <path>`.
- `milestone-wait.sh <slug> --sources <answers,watcher,status,inbox,events> [--timeout <sec>]` (default 540): blocks
  in the foreground (call it with the Bash tool's `timeout: 600000`) until at least one new event, prints one line each and exits `0`; exit `3` = timeout without
  events (call it again). Lines: `answer <path>` | `watcher <log line>` | `status TASK-<id> <old> -> <new>` | `inbox
  <path>` | `event <events.log line>`. It keeps its read positions in `<C>/milestone/wait-<caller>.state`
  (`--caller tm|coordinator|worker-1|worker-2|review`; source `inbox` reads `<C>/milestone/inbox/<caller>/`), so
  nothing is reported twice or missed between calls. Exception: inbox files (not `.done`/`.read`) are reported on
  every call until the reader renames them, so a replacement session sees the open file of the one it replaces.
- `milestone-check.sh start|resume`: run in the main checkout. Prints `missing: <what>` (exit 1), `warn: <what>`,
  and `open: milestone-<slug>` if one exists (start with an open milestone → exit 1; resume without one → exit 1).

## Hooks (PreToolUse; JSON on stdin; exit 2 + reason on stderr blocks; same for every agent)

`guard-main.sh` (Bash): commit/merge/cherry-pick/revert/am while on `main` or `milestone-*` (exception, only with cwd
`<repo>.worktrees/milestone-<slug>`: `git merge --no-ff --no-commit task-<id>-*` if
`<C>/reviews/task-<id>-r*.findings.md` exists, `git commit` only while `MERGE_HEAD` exists, `git merge --abort`;
cherry-pick/revert/am and direct commits stay blocked), any `git push`. `guard-rewrite.sh` (Bash): `rebase`, `reset`
(except `git merge --abort`), `commit --amend`, `push --force` on `milestone-*` or merged commits. `guard-install.sh`
(Bash): package installs without `--ignore-scripts`. `guard-web.sh` (WebFetch, WebSearch, Bash curl/wget): domains not
in `~/.claude/allowed-domains.txt`.
