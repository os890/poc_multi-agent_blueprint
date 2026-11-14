# Rules review before the second trial run (docs, with architect, RE, critic; 2026-11-14)

The maintainer asked the experts to check the current v1 rules against trial-run findings 1–8, the overhead finding and
the the first trial run lessons. Each owner reviewed their own files once. Clear defects are already fixed (bottom); the list ranks
what is left by effect. **DQ** = design question for the maintainer.

## Open issues, ranked by effect

| # | Where | Problem | Proposed fix |
|---|---|---|---|
| 1 | coordinator/TM skills, backlog-ng (old #2) | **DQ.** Board files created in the main checkout (planned, escalation, fix and gap tasks; `drafts/`, `milestones/`) stay untracked; in the second trial run six task files were untracked. When those files reach `main` with the milestone merge, git refuses ("untracked files would be overwritten"), so the watcher's merge into `main` fails. | (a) backlog-ng commits new task files on `main` (a board-only commit kind; architect's preference), or (b) the maintainer commits `backlog/` on `main` before approving the milestone (G0 cost). Interim: the check warns on resume; the hand-off lists uncommitted `backlog/` files. The second trial run's merge stays with the demo team. |
| 2 | coordinator SKILL, draft §4 step 1 | **DQ.** Milestone cap "~2,000 changed lines" is undefined: the first trial run's diff was 3,221 lines (825 production, 1,725 tests, tools, docs). If tests count, the first trial run would become 2 milestones and 2 milestone reviews: more overhead, not less. | Count production code only (no tests, no generated files; the first trial run ≈ 825); calibrate in the next trial run. |
| 3 | decisions.md D10 (cut 6) | **DQ.** The 5 sessions and their wake-ups are still the biggest communication overhead. | Pending: drop the slot sessions; the task manager runs implementer and review sub-agents itself (2 sessions per milestone). Spike: 2 parallel sub-agents while it waits on the watcher. |
| 4 | INTERFACES 250, worker, draft §7 | 60 min per assignment vs D10's bigger tasks (≤ ~400 lines incl. tests): expect more timeouts and resume runs. | Calibrate in the next trial run; consider ~90 min. (Draft now names the 60-min guess.) |
| 5 | draft §1 G0 | **DQ.** G0's dry run compares against a per-task baseline; the second trial run runs in milestone mode. | Log maintainer minutes per interaction in the next trial run (one line each in the retro note) as the first G0 data point. |
| 6 | hooks (guard-main) | The milestone-mode merge exception can't see the review mode; in `per task` mode the milestone checkout must be detached. | Known gap; the check warns; the coordinator detaches the checkout in `per task` mode. |
| 7 | repo layout | **DQ.** The frozen pre-v1 docs (`multi-agent-workflow.md`, `requirements.md`, `agent-skills.md`, `skills/`, `agents/`, `open-points.md`, the tutorial) sit next to `v1/` and describe the 6-agent design. D8's condition (spike, dry run) is met by the trial runs. | Move them to `archive/`; keep `open-points.md` (still used) or fold its live items into v1. |
| 8 | coordinator SKILL ~49-52 | The sizing rules (400 / 150 / sub-task 400 / parent 1,000 / milestone cap) are one long paragraph. | One small table, also in the draft's DoR. |

| 9 | INTERFACES (review mode) | Until the backlog-ng review-app gate hides trees of tasks not In Review, the app offers `milestone`-mode tasks; approving one adds a second merge path. | README rule "review only the milestone review task" (done); the backlog-ng review-app gate before the second trial run's merge if possible. |
| 10 | TM (milestone mode) | The hand merge relies on the `guard-main` path exception and the task manager's discipline. | Keep as interim; replace by backlog-ng's agent finish (#3, #40). |
| 11 | coordinator (lifecycle) | Every `archive_session` is an approval card in default mode (G0 cost). | Run the coordinator in auto mode; count cards in the next trial run. |
| 12 | coordinator, TM, sub-tasks | Unverified: start rights hours into a turn, compaction mid-turn, `list_sessions` of grandchild sessions, `$BNG start <parent>` with sub-tasks. | Check in the next trial run; on failure the known gap is "nothing starts until `/milestone resume`". |

## Fixed in this pass (clear defects)

- **Security (first trial run)**: scripts and hooks run only from `~/.claude/milestone/`; the snippet no longer prefers a
  project copy (an agent could fake green or switch a guard off). The check reports a project copy, `$CLAUDE_PROJECT_DIR`
  in hook commands, and a missing `.gitignore` entry (critic). Script path `S` is `~/.claude/milestone/scripts` in the
  review slot (docs) and in worker and implementer (RE); coordinator, task manager and the INTERFACES layout (architect).
- **First milestone (chicken-and-egg)**: README has a "Setup (once, on `main`)" section; `tools/verify.sh`, the labels,
  the hook snippet and `.gitignore` are set up on `main`, never as milestone tasks; the worker and implementer read
  `CLAUDE.md` from the task worktree (RE); the check's setup messages point to it (critic).
- **Leftovers from today's revisions**: hands-off wording fits milestone mode, merge-in covers the task manager's own
  merge, rejection fixes are "per task only", resume may have no new commits (RE); 12 defects incl. the aborted-merge
  status row (`per task` only, named exception to cut 4), `full`/`bisect` in the background (10-min Bash cap), sync
  task by review mode, parent size limits, merge-recovery by mode (architect); README install and gaps, draft
  time limits and old #2 row (docs); `decisions.md` stale orchestrator/Monitor wording (critic).
- **Closed**: the board output format of `milestone-wait.sh` is verified by the first trial run (gap 15).

Not covered: the first trial run's lessons file itself (in the trial project); L-1 from #40 was used.
