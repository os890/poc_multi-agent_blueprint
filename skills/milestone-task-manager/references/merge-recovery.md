# Merge recovery: the approved milestone does not reach main

The watcher merges the milestone review task's branch (the milestone branch plus the report commits) into `main`.
If that fails, it logs `auto-merge aborted (<branch>): <reason>`, leaves the branch and `main` unchanged and retries when
the branch, `main` or the verify stamps change. The line reaches you through your background monitor on the
watcher log (SKILL.md section 1, `OPEN(#38)`). Find the cause in that line and the watcher log around it.

| Cause | What you do | Maintainer reviews again |
|---|---|---|
| Conflicts with `main` (`main` moved) | Compensation task in the milestone: a worker merges `main` into its task branch (from the milestone branch) and resolves the conflicts (no rebase). Minimal suite, review of the conflict resolution diff only (reviewer, types logic, code, test), merge into the milestone branch, full suite (test runner) | the new commits only |
| Quality gate red on the merged result | Regression task: the test runner finds the failing tests and the cause, fix on a task branch, merged into the milestone branch, full suite | the fix commits only |
| Technical: git busy (`index.lock`), main checkout not clean, verify bridge or watcher down | No code change. Wait for the watcher's retry (up to 15 min); still failing → escalate | no |
| Unknown cause, or the same merge failed twice after compensation | Escalate with the log lines and what was tried | maintainer decides |

- Never touch `main` or the maintainer's main checkout; never rewrite approved commits.
- Code changes reach the milestone review branch only through the milestone branch: after the compensation is
  merged there, run `$BNG update` in the milestone review task's worktree (it merges the milestone branch in),
  then add the reason and the compensation to the report. Nothing else is committed on the review branch.
- Send `merge failed <cause>: <compensation>` to the coordinator before you start the compensation.
- After the compensation: milestone gate again (SKILL.md section 5), then `milestone ready <commit>`.

`OPEN(#18)`: whether the watcher's rebase of unpushed branches keeps the review app's approvals; whether the
review app keeps approvals when compensation commits are added.
