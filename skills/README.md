# Skills and agent definitions of the multi-agent milestone workflow (draft)

One skill per agent. Each agent definition preloads its skill, so the skill is active from the agent's first turn.
Details that an agent needs only now and then are in reference files next to its skill and are read on demand.

| Agent | Agent definition | Skill | Reference files |
|---|---|---|---|
| coordinator | `agents/milestone-coordinator.md` | `skills/milestone-coordinator/` | – |
| task manager | `agents/milestone-task-manager.md` | `skills/milestone-task-manager/` | `references/reviews.md`, `lessons-learned.md`, `merge-recovery.md`, `retrospective.md` |
| worker | `agents/milestone-worker.md` | `skills/milestone-worker/` | – |
| reviewer | `agents/milestone-reviewer.md` | `skills/milestone-reviewer/` | `types/01-logic.md` … `types/11-test.md` (passed to the sub-agents) |
| review type (sub-agent of the reviewer) | `agents/milestone-review-type.md` | `skills/milestone-review-type/` | its type's checklist |
| test runner | `agents/milestone-test-runner.md` | `skills/milestone-test-runner/` | – |

Builds on backlog-ng with milestone branches (`BNG_MILESTONE_BRANCHES=yes`: `milestone-<slug>` branches, milestone
review task with label `milestone-review` that targets `main`).

## Install (later)

```sh
P=<project>
mkdir -p "$P/.claude/skills" "$P/.claude/agents"
cp -R skills/milestone-* "$P/.claude/skills/"
cp agents/milestone-*.md "$P/.claude/agents/"
```

The project's `CLAUDE.md` must name, for the skills:

- `BNG`: the backlog-ng runner, e.g. `tools/backlog-ng/backlog-ng.sh` or `../<project>-backlog-ng/backlog-ng.sh`
- the minimal and the full test command (the fast suite, and the suite incl. end-to-end tests)
- the project's docs the reviewers check against (PRD, specs, architecture decisions)
- the lessons-learned file (default `docs/lessons-learned.md`; the task manager creates it with the first lesson)
- the watcher log (the task manager's background monitor reads it for failed and done merges into `main`)

Start: the maintainer starts all long-running agents at the beginning of the run - coordinator, task manager,
workers (1..n), reviewer, test runner (`OPEN(#4)`: as teammates of one team or as separate sessions, e.g.
`claude --agent milestone-<agent>`). Then `/milestone-coordinator start` in the coordinator's session. Only the
reviewer starts sub-agents (one `milestone-review-type` per review type and review).

## Markers

`OPEN(#n)` marks a rule that depends on open point n in [../open-points.md](../open-points.md). The skill states a
provisional rule there; it is replaced once the point is decided.

## Shared rules

Every skill repeats the few shared rules its agent needs (hard rules, severity scale, message format) instead of
depending on a separate shared skill, so each skill can be installed and read on its own. When a shared rule
changes, change it in every skill (the retrospective's consistency review checks this).
