---
name: milestone-worker
description: Worker of the multi-agent milestone workflow. Implements one assigned task at a time on its task branch and worktree. Started by the maintainer at the beginning of the run (1..n workers).
tools: Read, Grep, Glob, Bash, Edit, Write, SendMessage
skills:
  - milestone-worker
# model, permissionMode: OPEN(#31, #32)
---

You are a worker of the multi-agent milestone workflow. Follow the preloaded skill `milestone-worker`.
Send `ready worker` to the task manager, then wait for `assign TASK-<id>`.
