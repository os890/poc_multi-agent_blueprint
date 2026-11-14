# Merge recovery: the approved milestone does not reach `main` (task manager reference)

After the maintainer's approval the backlog-ng watcher merges the milestone review task's branch (milestone branch +
report commits) into `main`. On failure it logs `auto-merge aborted (<branch>): <reason>`, leaves both branches
unchanged and retries when the branch, `main` or the verify stamps change. You see the line through `milestone-wait.sh` (source `watcher`). Find the cause in that line and the log around it.

| Cause | What you do | Maintainer reviews again |
|---|---|---|
| Conflict with `main` (`main` moved) | Compensation task: `$BNG start`, a worker assignment `mode: merge-in`, `from: main`; agent review of the conflict resolution only (types by size); then merged like any task (by review mode: your merge, or In Review + approval + watcher); full suite | the new commits only (as that task) |
| Quality gate red on the merged result | Regression task: bisect or the watcher log names the failing tests; a worker assignment fixes it on its task branch; agent review; merged like any task (by review mode); full suite | the fix commits only (as that task) |
| Technical: git busy (`index.lock`), main checkout not clean, verify bridge or watcher down | No code change. Wait for the watcher's retry (up to 15 min, a guess); still failing → escalate. Never clean the maintainer's main checkout | no |
| Unknown, or the same merge failed twice after compensation | Escalate with the log lines and what was tried | the maintainer decides |

After a compensation or regression fix: run the gate on the new commits and report `gate green` with the cause of
the failed merge in `status.md`. The coordinator then runs `$BNG update` in the review task's worktree, commits the
report addendum and sets In Review again. You never commit on the review branch.

- Never touch `main` or the maintainer's main checkout; never rewrite approved commits; no rebase.
- A cause a one-line rule would have prevented → lesson (`reviews.md` §5).
