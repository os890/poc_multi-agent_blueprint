# Multi-agent milestone workflow: start here (draft)

A blueprint for letting AI agents implement, review and merge the tasks of a milestone on their own. Only the
whole milestone gets the maintainer's manual review before it reaches `main`.

## Reading order

1. [multi-agent-workflow-tutorial.html](multi-agent-workflow-tutorial.html): the overview with diagrams, setup and
   a guide to running a milestone (open it in a browser). Read it first.
2. [multi-agent-workflow.md](multi-agent-workflow.md): the flow diagram and the rules behind it (branches, merge
   failures, goal check, loop guard, retrospective, lessons learned, reviews).
3. [agent-skills.md](agent-skills.md): the agents, their tools, who writes which file, the messages between them.
4. [requirements.md](requirements.md): goals, decision rights, phases with entry and exit criteria, exception paths.
5. [open-points.md](open-points.md): what is not decided yet. Read it before you propose a change.
6. [skills/](skills/README.md) and [agents/](agents/): the files the agents actually run, plus install notes.

## Where each rule lives

Read the overview docs for orientation. When they and a skill disagree, the skill is what the agents actually run,
so treat that as a bug and fix both.

| Topic | Source of truth |
|---|---|
| Flow diagram | `multi-agent-workflow.md`; the same diagram is in `tutorial-src/diagrams/workflow.mmd` |
| Agents, tools, file ownership, messages | `agent-skills.md` |
| Review scope, review-type selection, Pareto rule | `skills/milestone-task-manager/references/reviews.md` |
| Merge into `main` fails | `skills/milestone-task-manager/references/merge-recovery.md` |
| Lessons learned, retrospective | `lessons-learned.md`, `retrospective.md` in the same `references/` folder |
| Review checklists | `skills/milestone-reviewer/types/` |
| Goals, decision rights, phases | `requirements.md` |

## Glossary

| Term | Meaning |
|---|---|
| maintainer | The human: gives the goal, approves the plan, answers escalations, does the manual review. |
| backlog-ng, `$BNG` | The task board tool (Backlog.md task files, branches, worktrees); `$BNG` is its runner, named in the project's `CLAUDE.md`. |
| watcher | backlog-ng's commit watcher. It merges the approved milestone into `main`, which nothing else does. |
| review app | backlog-ng's web UI where the maintainer reviews and approves. |
| milestone branch | `milestone-<slug>`: the only integration branch. Every task branch is merged into it. |
| milestone checkout | The task manager's own worktree of the milestone branch. It is not the maintainer's main checkout. |
| milestone review task | The task whose branch carries the milestone branch plus the report; the maintainer approves it. |
| milestone gate | Sync with `main`, full test suite and milestone review (all 11 review types) before the hand-off. |
| minimal / full suite | Fast tests per task merge / all tests incl. end-to-end per milestone. |
| Pareto rule | At most 3 review rounds per task, with fewer severities blocking in later rounds. Then the task manager escalates instead of looping. |
| finding: critical, major, minor | The severity scale. Critical and major findings block. Minor findings become drafts. |
| draft | A backlog-ng task without a milestone. The maintainer sorts drafts at the hand-off. |
| lesson, `L-<n>` | A rule from a basic mistake with major impact, checked in every review. |
| `OPEN(#n)` | A provisional rule that depends on open point n. |
| `Proposed (RE)`, `Proposed (Arch)` | Proposals from the requirements or the architecture review. They are not decided yet. |

## When you edit

- Diagrams exist twice, in the `.md` files and in `tutorial-src/diagrams/*.mmd`. Change both.
- `multi-agent-workflow-tutorial.html` is generated from `tutorial-src/` and `open-points.md` (`tutorial-src/build.py`),
  so never edit it by hand.
- Each skill repeats the shared rules it needs (hard rules, severity scale, message format). When a shared rule
  changes, change it in every skill.

## License

Apache License 2.0, see [LICENSE](LICENSE).
