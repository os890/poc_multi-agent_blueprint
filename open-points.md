# Open points (to brainstorm)

Open decisions and edge cases of the [multi-agent milestone workflow](multi-agent-workflow.md) and the
[agents and skills](agent-skills.md). Rough order: the first group blocks most of the others.
`Proposed (RE)` lines are proposals from the requirements and process review; details and rationale are in
[requirements.md](requirements.md). They stay open until the maintainer accepts them.
`Proposed (Arch)` lines are proposals from the architecture review (agent boundaries, state, branches, runtime);
the state and branch model is in [agent-skills.md](agent-skills.md#state-and-who-writes-it).

## 1. Foundations (decide first)

1. **The commit for the review app**: partly answered by backlog-ng's milestone branches (`BNG_MILESTONE_BRANCHES`, still in review in the template): the milestone review task
   (label `milestone-review`) branches from the milestone branch and targets `main`; its commit is the milestone
   review report (goal check, tests, reviews), and the commits of already merged tasks count as approved. Still
   open: how one task is rejected in the middle of an otherwise approved milestone.
   `Proposed (RE)`: no un-merging. Per rejected point the maintainer says *fix* (fix task, new commits) or *drop*
   (`git revert -m 1 <task merge>` as a new commit on the milestone branch); only the new commits are reviewed
   again. Approvals of the other commits stay.
2. **Backlog.md task state with parallel workers**: the task manager as the only writer of task files; on which
   branch the true state lives (milestone branch, task branches, `main`); how the watcher's commits of `backlog/` on
   task branches fit in without merge conflicts.
   `Proposed (Arch)`: one writer per task file at a time, handed over by messages: the coordinator during planning,
   the worker from `assign`/`fix` until `done`/`stopped`/`blocked`, the task manager otherwise; always `$BNG cli` in
   the task's worktree. A running task's true state is on its task branch (the watcher commits `backlog/` there),
   after the merge on the milestone branch, in `main` with the milestone. No `backlog/` conflicts, because each task
   file changes only on its own branch. To verify: where new task files (fix, gap, drafts) are committed - the
   watcher never commits board changes on `main` or `milestone-*`.
3. **Branch hierarchy in backlog-ng**: answered by backlog-ng's milestone branches (`milestone-<slug>` from `main`, task branches from it,
   merged into it after their review). Still open: **agent-approved task reviews**: today the watcher merges a task
   branch only after the maintainer's approval; the workflow needs a way for the task manager to approve a task
   review (provisional in the skill: the task manager merges by hand in its milestone checkout).
   `Decided (maintainer, 2026-11-14)`: manual review per milestone by default, per task only on request; the
   backlog-ng changes (a) agent finish and (b) approver-aware milestone review are listed under #40.
   `Proposed (Arch)`: the hand merge works for v1 but has a catch: the review app counts a milestone's task commits
   as approved only "when their task is finished with an approved review" (backlog-ng's milestone review). Hand-merged tasks
   have none, so the maintainer would see every commit as open in the milestone review. To verify first in the dry
   run. Target: an *agent review* in backlog-ng for tasks that target `milestone-*`: the task manager finishes the
   task review through the review app's API as agent; the watcher merges (its quality gate replaces the task
   manager's minimal-suite merge); reviews that target `main` can only be finished by the maintainer, enforced in
   backlog-ng. Consequence: the watcher rebases an unmerged task branch onto the milestone branch before it merges;
   the rule "never rebase" then means "agents never rebase, and nothing merged is rewritten".
4. **Agent runtime**: partly decided: the maintainer starts all long-running agents at the beginning of the run
   (coordinator, task manager, workers, reviewer, test runner); only the reviewer starts sub-agents (one fresh
   `milestone-review-type` per review type and review). Still open: as teammates of one team (coordinator as lead)
   or as separate sessions (`claude --agent ...`); separate sessions need another message channel than
   `SendMessage` (task files, a mailbox file, a hook). Agent teams reportedly don't let teammates start
   sub-agents (to verify: a teammate calls the Agent tool) - then the reviewer must be a session of its own, or the
   lead. Teammates from agent definitions (`skills:` preloaded). To verify in the Claude Code docs
   (`code.claude.com` is not on the domain whitelist yet).
   `Proposed (Arch)`: decide with a 15-minute spike before writing hooks: in an agent team, (a) a teammate calls
   the Agent tool, (b) a PreToolUse hook fires for a teammate and a sub-agent and its input names the agent, (c) a
   teammate runs a background monitor (see 38). All yes → one team, coordinator as lead. (a) no → separate sessions;
   Claude Code can send messages between local sessions, so a mailbox file may not be needed (to verify for the CLI,
   not only the desktop app). Skills stay the same either way: they only use typed messages and files.
5. **Worktrees for workers**: backlog-ng `start <id>` (branch and folder naming as today) vs `isolation: worktree`.
   `Proposed (Arch)`: backlog-ng `start <id>`. The worktree belongs to the task, not to the agent: it must outlive
   review rounds, a `stop` and a change of worker, and start from the milestone branch with the target recorded.
   `isolation: worktree` ties the worktree to one agent's lifetime and its own naming.

## 2. Review and Pareto

6. **Concrete Pareto rule**: rounds per task, severity per round, finding budget; whether to add
   follow-up milestone rules (at most one follow-up milestone Mn.1, whose review only blocks on the highest
   severities, never an Mn.2).
   `Proposed (RE)`: keep today's rule as v1 (3 rounds; round 3 blocks only critical and lesson violations; then
   escalate; milestone gate: one fix round per gate run). No finding budget and no follow-up milestone Mn.1: what is
   left after the limits is the maintainer's fix-or-defer decision, and deferred items go to the next planning.
   Judge it with the retro metric "tasks that hit the limit".
7. **Severity scale**: three levels (critical/major/minor, used in the skills now) or four (critical/high/medium/minor);
   one scale for all projects.
   `Proposed (RE)`: three levels for all projects. Each level has its own consequence (critical/major block and are
   never deferred by agents, minor becomes a draft); a fourth level would add a judgement call with no different
   consequence.
8. **Review-type selection per task**: who decides "touched" (path rules, labels, the task manager's judgement).
   `Proposed (RE)`: path rules per project in `CLAUDE.md` (glob → review types); the task manager may add types by
   judgement but never drop one a rule selects; selection and reason go in the task notes. Retro check: a milestone
   review finding of a type that was not run on that task → sharpen the rules.
9. **Double-check of findings**: decided: the reviewer validates all findings of its sub-agents (format, scope,
   duplicates, re-read of critical/major in context, reproduction by the test runner where a test or command can
   show it) and reports only confirmed ones; dropped findings are recorded with a reason in the findings file.
   Still open: the time limit for a reproduction; whether a long-running reviewer's validation drifts over a
   milestone (retrospective metric: what the maintainer finds that the reviewer dropped).
   `Proposed (RE)`: 5 min per reproduction (already in the test-runner skill); drift is watched by the existing retro
   metric, and goes away if long-running agents are restarted per milestone (see 21).
10. **Drafts and out-of-scope findings**: who decides them and when (a "decide the drafts" step with the maintainer at
    milestone end?). Decided: critical/major findings are never deferred by an agent; "fix or defer" goes to the
    maintainer. Still open for minor drafts.
    `Proposed (RE)`: every minor finding becomes a draft without a milestone (today's skills say "in the milestone",
    "next milestone" and "either"); the hand-off lists them, and the maintainer sorts them in one batch during the
    manual review: next milestone, backlog or discard. Agents never discard a draft.
11. **A 12th review type?** The list has 11 types now.
    `Proposed (RE)`: not now. Add one only when the manual review finds the same kind of defect in 2 milestones and it
    fits no existing checklist. Candidate to watch: performance.

## 3. Tests

12. **Minimal vs full suite per project**: tags, the two test commands, time budget for the minimal
    suite.
    `Proposed (Arch)`: one quality-gate script with a `--full` flag, the same script backlog-ng's watcher runs; slow
    tests (end-to-end, container, platform) tagged and excluded without the flag. Minimal suite ≤ 5 min: it runs on
    every merge into the milestone branch, one at a time, so its duration caps the merge queue's throughput.
13. **Flaky tests**: retry policy, quarantine allowed or not, who fixes them.
    `Proposed (RE)`: one rerun alone (as in the skill); flaky tests never block but are always listed in the report;
    a test flaky in 2 milestones gets a fix task; quarantine only by the maintainer's decision, recorded as a draft
    with the test name.
14. **Regression attribution**: bisect over the task merges; who fixes the regression (original worker or fresh).
    `Proposed (RE)`: any free worker, with the original task's notes linked in the regression task (the original
    worker's context is gone by then anyway); every regression is checked for a lesson.

## 4. Parallel work and merging

15. **Merge queue**: order, minimal suite on the merged result, what happens to tasks queued behind a red merge.
    `Proposed (RE)`: oldest `done` first. A red or conflicting merge is aborted and leaves the milestone branch
    unchanged, so the tasks behind it go on; the aborted task joins the queue again after its fix. The re-review
    after merging the milestone branch in does not count as a Pareto round. A task that fails to merge twice is
    merged next, with no other merge in between.
16. **Overlap between parallel tasks**: file ownership hints, dependencies, when the task manager serializes tasks.
    `Proposed (RE)`: each task lists its expected files or modules (Definition of Ready, requirements.md §9); the
    task manager serializes tasks whose lists overlap or that change the same interface. Retro metric: merge
    conflicts between parallel tasks.
17. **`main` moves during a milestone** (hotfix, another milestone): merge `main` into the milestone branch right
    away or only before the hand-off.
    `Proposed (Arch)`: not right away (reviews keep stable diffs). Once before the gate: if `main` is not an ancestor
    of the milestone branch, a sync task merges `main` in (gate step 0), so the full suite and the milestone review
    see what will reach `main`. Earlier only when a task needs a fix from `main`. After the hand-off, backlog-ng
    brings the review branch up to date with `main` by a merge itself; conflicts → `merge-recovery.md`.
18. **Watcher rebase vs merge for approved milestone branches**: the watcher rebases unpushed branches (new commit
    IDs of approved commits) and merges `main` into pushed ones; does the review app keep earlier approvals when
    compensation commits are added?
    `Proposed (Arch)`, facts from backlog-ng's milestone branches: the milestone review branch is brought up to date with `main` by
    a merge, never a rebase, so approved milestone commits are not rewritten; task branches are rebased onto their
    target before their merge (relevant only with the agent review of 3). Compensation goes through a task branch
    into the milestone branch, then `$BNG update` merges it into the review branch. Still to verify in the dry run:
    whether the review app keeps the approvals when these new commits arrive.
19. **Several milestones in parallel**: allowed or strictly one at a time.
    `Proposed (RE)`: strictly one at a time in v1, so the merge into `main`, the lessons file and the retro metrics
    stay unambiguous; revisit after 3 milestones.

## 5. Robustness

20. **Stalled or crashed workers**: heartbeat, timeout, taking a task back, resuming from the task notes.
    `Proposed (RE)`: no heartbeat messages (they would break the loop guard); the tick checks the task branch and
    notes. 30 min without a commit, note or message → `stop TASK-<id>`; no `stopped` within 10 min → take the task
    back from its notes and branch and assign it again; the same task stalls twice → escalate (too big or unclear).
    Needs a `stopped` message: today the worker answers `stop` with `done`, which triggers a review.
21. **Context limits**: what each agent writes to the task notes so a fresh agent can continue after compaction;
    the reviewer keeps its state only in the review folder (diff, findings file). Long-running agents run for the
    whole milestone, possibly days during the manual review: restart them per milestone or keep them.
    `Proposed (Arch)`: restart per milestone: all long-running agents end after `retro done` and start fresh for the
    next one. No context drift across milestones, and skill improvements take effect (a preloaded skill is read at
    start). During the manual review they may be stopped; everything after the hand-off resumes from files.
22. **Crash of an agent**: the maintainer starts all agents, so a crashed agent must be restarted by the maintainer
    (or a supervisor script); how the coordinator notices it (a missing `ready`, no answer) and how the run is
    resumed from the task files and the review folder.
    `Proposed (RE)`, process part: every request has a time limit (review, suite, reproduction); missing answer or
    tick → the coordinator asks the maintainer to restart the role; the restarted agent sends `ready <role>` and the
    task manager re-sends its open request (requests are idempotent, the state is in files). A restarted task manager
    gets `start M<n>` again, which means *resume*: it rebuilds its state from task statuses, notes, the review folder
    and git. The restart mechanism itself stays open with 4 and 38.
    `Proposed (Arch)`: v1: the maintainer restarts the role the coordinator names; a supervisor script only if
    restarts turn out to be frequent (retro metric).
23. **Loop guard numbers**: message limits, budget per task and milestone; how the hook counts "since the last state
    change".
    `Proposed (RE)`: a state change is a change in a file the hook can see: task status or notes, a commit, a new
    task, a findings file, a test report. One wording in all skills: the 4th message about one task between two agents
    without a state change is blocked (today worded four ways). Budgets: a default per task set by the maintainer in
    `CLAUDE.md` until there is data; after the first milestone 2× the median task cost; milestone budget = sum of the
    task budgets + 30 % for the gate and fixes.

## 6. Maintainer interaction

24. **Escalations**: which decisions always belong to the maintainer; batching questions instead of interrupting
    for each one.
    `Proposed (RE)`: decision table and batching rule in requirements.md §4. Asked immediately only when it blocks
    all work, a hard rule is broken, data is at risk, or it is scope, pause or cancel; otherwise batched (when no
    other work can proceed, at `gate green`, at the hand-off, at least once a day). Every answer goes to the task
    notes.
25. **Changes during a run**: pause, cancel, changed priorities or scope; what happens to running tasks.
    `Proposed (RE)` (requirements.md §7): scope change → replan with the maintainer; removed running task → `stop`,
    branch kept unmerged; removed merged task → revert commit; priority change → only the order of To Do tasks.
    `cancel M<n>` → no new tasks, running tasks stopped, no more merges, milestone branch kept unmerged with a report;
    the maintainer decides keep or delete.
26. **Goal capture**: format of the goal and success criteria at planning; what counts as evidence in the goal
    check.
    `Proposed (RE)`: template in requirements.md §8: goal verbatim, success criteria `SC-<n>` each with "verified by"
    (test, command, screenshot or maintainer), and an explicit "out of scope" list. "Task done" is not evidence;
    criteria only a human can judge are listed "for the manual review", never "met".
27. **Status**: how often and in what form the coordinator reports without being asked.
    `Proposed (RE)`: event-driven only: batched escalations, `gate green` (one line), milestone ready, merge failed,
    retro done; plus a one-line daily digest (done, in progress, blocked) on days with no other report. `status` on
    request as today.

## 7. Improvement over time

28. **Retrospective metrics**: where each metric comes from (task notes, git, watcher log, token usage), thresholds
    for "inefficient".
    `Proposed (RE)`: sources: task notes and findings files (rounds, findings, dropped, disputes), `rejected <list>`
    (maintainer findings), the lessons file's `seen`, test reports (failures, flaky), watcher log (failed merges),
    hook log (loop-guard events), session usage (tokens, if available). No absolute thresholds in v1:
    "inefficient" = repeated in this milestone, or more than 50 % worse than the median of the previous 3 milestones
    (only the "repeated" criterion until 2 earlier milestones exist).
29. **Where skills live**: per project (`.claude/`), in the backlog-ng template, or user-level; how an improvement
    in one project reaches the others; versioning of skills.
    `Proposed (Arch)`: installed per project (`.claude/`), copied from one source (this blueprint, later the backlog-ng
    template), with a version line in each skill. Retro improvements change the project copy (reviewed there); the
    maintainer carries general ones back to the source. Projects update from the source by version.
30. **Rollback of skill changes** that did not help, and how "did it help" is measured with few milestones.
    `Proposed (RE)`: each improvement names its metric and expected direction when it is proposed; it is judged after
    2 milestones (one is noise). Not better → reverted by a normal improvement task; undecided → kept only if it did
    not make the skills longer.

## 8. Security and cost

31. **Permission mode per agent** (workers in bypass mode?) and which rules are enforced by hooks: never merge
    into or push `main`, `--ignore-scripts`, domain whitelist, reviewers without Bash/git, no file writes through Bash
    by agents without Edit/Write (coordinator, test runner), the reviewer's Write only in the review folder.
    `Proposed (Arch)`: hooks check paths per agent, not only tools: the reviewer writes only in
    `<git-common-dir>/backlog-ng/reviews/`, the test runner (now with Write) only in `.../backlog-ng/tests/`, the
    coordinator only through `$BNG cli` (planning, goal check), the task manager only diff files, reports, the
    lessons file and the retrospective. No agent in bypass mode; workers get an allowlist (test commands, git on
    their own task branch, `$BNG`).
32. **Models per role**, number of parallel workers, token and cost budget per milestone.
    `Proposed (Arch)`: the most capable model for coordinator, task manager, reviewer and review types (judgement and
    defect finding); workers the same until the retro shows a cheaper one is enough; the test runner a small model
    (mechanical). Start with 2 workers: the reviewer and the serial merge queue are the bottleneck; add a worker only
    when the retro shows the reviewer idle and no overlap conflicts. Budgets: see 23.

## 9. Not covered yet

33. **Releases**: how backlog-ng's release flow fits after a milestone.
    `Proposed (Arch)`: outside the agents' run: after the merge into `main`, the maintainer uses backlog-ng's release
    flow, which already lists a milestone's tasks under its milestone review. No agent role, no new message.
34. **Milestone planning**: how the coordinator splits the goal into tasks, task size, dependencies, and the
    maintainer's approval of the plan.
    `Proposed (RE)`: Definition of Ready and Done in requirements.md §9: each task serves ≥ 1 success criterion,
    has testable acceptance criteria, dependencies and expected files, and fits one reviewable branch (target
    ≤ 400 changed lines without tests and generated files). The plan shown to the maintainer is a table: task,
    criteria served, dependencies, expected files, size. A success criterion without a task blocks the approval.

## 10. Implementation

35. **Hooks**: the scripts that enforce the hard rules and the loop guard (`SendMessage` counter per task and pair)
    are not written yet; which hook events exist for teammates and sub-agents needs the docs (see 4).
    `Proposed (Arch)`: four PreToolUse hook scripts, each keyed on the agent from the hook input: git guard (`main`,
    push, rebase/reset/force on `milestone-*` and merged branches), install and network guard, write-path guard
    (31), and the `SendMessage` counter per (task, sender, receiver), reset when the hook sees a state change (task
    file or task branch head changed, new findings file or test report). Written after the spike of 4.
36. **Testing the skills**: a dry run on a small demo project (e.g. backlog-ng's `create-demo.sh`) before the first
    real milestone; what counts as a successful run.
    `Proposed (RE)`: a demo milestone of ≥ 3 tasks, two of them parallel with a planned file overlap, one with a
    seeded defect, plus a seeded flaky test. Successful when: it reaches `milestone ready` with maintainer
    interactions only from the decision table (requirements.md §4); the seeded defect is found and fixed; the flaky
    test is reported as flaky, not red; one agent of each role is killed once and the run resumes from the files
    (goal G4); every attempt to break a hard rule is stopped by a hook.

## 11. Lessons learned

37. **Lessons-learned file**: what counts as a "basic" mistake in practice (the task manager's judgement now); whether
    the maintainer approves each lesson before it is active or only with the milestone; the limit of 30 active
    lessons; whether general lessons also go to a user-level file shared by all projects or only into the reviewer
    checklists of the skills (see 29).
    `Proposed (RE)`: "basic" = its rule can be written as one line that is checkable on a diff (if not, it is not a
    lesson). A lesson is active right away; the maintainer approves it with the milestone and can drop it there
    (cheap to revert, and the next tasks benefit immediately). Keep the limit of 30. User-level sharing waits for 29.

## 12. Wake-ups

38. **Events no agent sends**: agents act only on messages, but some events come from outside: the watcher's
    `auto-merge aborted` and the successful merge into `main` (start of the retrospective), a worker without a
    commit for 30 min, a crashed agent. Provisional: a monitor or hook on the watcher log and a periodic tick send
    the task manager a message. Which mechanism (hook, background monitor, scheduled check, the watcher itself), and
    how it reaches an agent in a team or in a separate session (see 4).
    `Proposed (Arch)`: the task manager starts a background monitor in its own session at set-up (Claude Code's
    Monitor tool): `tail -F` on the watcher log filtered to `auto-merge aborted` and merge lines, plus a 10-min tick
    that prints stalled tasks from git and the task notes. Each output line wakes the task manager. This works the
    same in a team or in a separate session and needs no outside process that sends messages. A crashed task manager
    loses its monitor → noticed by the coordinator (22), re-started on resume. To verify in the spike of 4.

## 13. Entry point

39. **Entry point for a run**: today the maintainer starts every agent by hand; nothing checks that the project is
    set up, and nothing defines how a run is resumed. Needed: one command that (1) checks the prerequisites
    (`CLAUDE.md` names `$BNG`, the minimal and full test commands, the docs and the lessons file; the hooks are
    installed; the watcher runs; no other milestone is open), (2) starts the run, and (3) on an open milestone
    resumes it from the files instead of starting a new one. Exit criterion: all checks pass and the run is ready for
    planning (replaces phase P0 in requirements.md).
    `Proposed (RE, Arch, Docs, Critic)`, agreed by all four sessions, part of v1 (under D1 resume is the only recovery
    path), but kept minimal:
    - **Command + script**: the maintainer learns one command, `/milestone start|resume` (the orchestrator; no
      session per role, see 4). It first runs a script for the mechanical part (as D2): the prerequisite checks, and
      on resume the phase detection and a state summary. The skill does only the judgement steps. The script's
      "missing: ..." output (non-zero exit) doubles as the setup guide.
    - **Checks** (only what fails late or silently): hooks installed (they cover the domain whitelist); skills and
      agent files installed in `.claude/`, same version as the blueprint; the watcher runs; no other open milestone
      (a `milestone-*` branch exists); the milestone checkout, if it exists, is clean after `git worktree prune`; the
      main checkout has no uncommitted changes (warning only: it would make the watcher's merge fail).
    - **Resume reads** the milestone description, task statuses and notes, the review and test folders, and git: task
      branch heads and worktrees, the first-parent merges on the milestone branch, whether the review branch exists.
      Git is the truth for the merge state.
    - **Guards** ("already done?") for the steps that are not idempotent: task merge (task head already an ancestor
      of the milestone branch → skip); `$BNG start` (branch exists → continue); task or draft creation (same title
      and milestone exists → reuse); lessons commit (L-<n> already in the file → skip); review report (already on
      the review branch → addendum). Reviews and suites are safe to rerun.
    - **After the hand-off** the same `resume` is the wake-up: the orchestrator reads the watcher log for a failed or
      done merge into `main` (replaces the monitor of 38 in v1).
    - **Not before the spike**: the script is written only after the spike's check (d) shows which prerequisites
      actually break.
    Decided (maintainer): the review app is not checked at the start, only at the hand-off, before the milestone
    review task is set In Review. Still open: Docs suggests moving this point into group 1 so it is seen first
    (numbers stay); the README should later point to the command and the tutorial's setup step, not to this point.

40. **Enforcing "agent review before manual review"** (trial-run findings, 2026-11-14): in the first trial run, two tasks
    were approved in the review app and merged by the watcher before their agent review had finished.
    The review app offers every task worktree as soon as `$BNG start` creates it, whatever the task's status; the
    rule text in v1 and `CLAUDE.md` cannot prevent that. To discuss later. Proposed (coordinating session):
    1. **Review app gate** (backlog-ng): list a task's tree only once the task is In Review, and refuse Approve,
       Approve all and Finish review on the server for a task that is not In Review (a stale page or an API call
       must not get through). Alone this would have prevented both cases.
       Status: built as a backlog-ng change "Manual review only for tasks In Review" (also: the watcher merges only
       reviews finished in the review app), in review.
    2. **Watcher gate** (backlog-ng, second line of defence): a DoD item "Agent review passed (`<sha>`)" that only
       the task manager ticks; the watcher merges only when it and "Manual review approved" are ticked and `<sha>`
       is the branch head. New commits after the agent review make it stale. A step towards the agent-review mode
       of #3.
    3. **Status hook** (v1): `guard-status.sh` blocks `$BNG cli ... -s "In Review"` unless the task's newest
       `task-<id>-r<n>.findings.md` exists, has nothing blocking and was made for the task branch's current head.
       Needs no agent identity (as D5).
    4. **Spike check (f)**: approving a task that is not In Review fails, and the watcher does not merge it.
    5. **Running trial**: the two tasks are merged without a prior agent review; their confirmed blocking findings
       become fix tasks on the milestone branch, and the milestone report names both cases (lesson L-1 records the
       cause).
    Not recommended: hiding task worktrees outside the review app's roots (a workaround that breaks with the next
    backlog-ng change). Suggested order: 1 and 3 first, 2 after the spike shows the app gate works.
    **Update 2026-11-14 (maintainer: manual review per milestone by default, per task only on request):** v1's
    default `milestone` review mode needs two backlog-ng changes; until they exist the task manager merges
    agent-reviewed tasks itself (v1 `INTERFACES.md`, Review mode per milestone):
    (a) **agent finish**: a review whose target is `milestone-*` can be finished by an agent (API), recorded with
    approver=agent; refused for targets `main` and `release`, enforced in backlog-ng; the watcher then merges after
    verify as usual (replaces the task manager's interim merge and its `guard-main` path exception).
    (b) **approver-aware milestone review**: a task's commits count as approved there only with approver=maintainer;
    agent-approved (or hand-merged) task commits are shown open, marked "agent-reviewed", grouped by task.
    Order (proposal): dry run of the `milestone` mode now with the interim merge; (a) and (b) afterwards, then a second
    dry run against the same baseline (G0).

41. **The verify gate runs in the live work tree** (trial-run finding, 2026-11-14): a task's tree was verified while its
    worker ran the build in the same task worktree; two tests failed because both wrote the build output folder. A red gate can
    block a good merge, a green one can cover files that are not the committed tree. Built as a backlog-ng change
    "Verify the committed tree in an isolated worktree" (in review): the verify script runs in a temporary detached worktree of the stamped commit, removed afterwards.
    Consequence for projects: every gate run builds from scratch, and files the build needs must be committed.
    To discuss: v1 rule that agents change only the project's repository, and findings about tools (backlog-ng)
    reach the maintainer as an escalation task first (both backlog-ng changes above were written directly in backlog-ng).

## 14. Sub-tasks

42. **Sub-tasks in multi-agent runs** (2026-11-14, revised after the maintainer's "no additional manual reviews"): v1
    allows sub-tasks as steps of one task: an agent review per sub-task, one integration agent review, and **one**
    manual review of the whole parent (v1 `INTERFACES.md`, Task status and merges). It works around backlog-ng with no own branch per
    sub-task (never `$BNG start` a sub-task) and one exception to "only the app sets Done": the task manager sets the
    sub-tasks Done just before the parent goes In Review, because the review app holds a parent's review while a
    sub-task is open. Cleaner backlog-ng support, for later: (a) a sub-task kind without branch or review ("step"),
    whose Done needs no review; (b) no automatic parent In Review after its last sub-task when an agent review gate is
    configured (today it fires only on a sub-task's review, which v1 never has). To check in the spike: `$BNG start
    <parent>` with sub-tasks, `$BNG cli` edits of a sub-task from the parent's worktree, and the parent's review and
    the milestone review with all sub-tasks Done.
