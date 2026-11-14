---
description: Multi-agent milestone workflow (v1) in this main session - start a milestone, resume an open one, or show its status
argument-hint: start | resume | status
---

Run the multi-agent milestone workflow (v1) in **this main session** of the Claude desktop app. You are the
coordinator, the maintainer's only contact; do not hand this to a sub-agent or another session. You start the
milestone's four sessions (task manager, two workers, review; the app's `start_session`; the goal check is your
sub-agent); this command is the maintainer's request for them.
Outside the desktop app (no `start_session`): say that v1 needs the desktop app and stop.

1. Load the `milestone-coordinator` skill with the Skill tool.
2. Argument: `$ARGUMENTS`
   - `start` → follow the skill's `/milestone start` section (it runs `milestone-check.sh start` first).
   - `resume` → follow `/milestone resume` (restarts the task manager if needed).
   - `status` → follow `/milestone status`; change nothing.
   - anything else or empty → print `usage: /milestone start | resume | status` and stop.
3. Chat with the maintainer only while planning. After that, never ask in chat and never end this turn while the
   milestone is open: wait inside it as the skill says (only this turn may start sessions).
