# Goal check: does v1 still delegate the work? (decision note for the maintainer)

Question (maintainer): *did they consider the overall goal to delegate the work to a team and only review the result
on milestone level before merging?* Author: requirements engineer, with one round of input from the architect and the
critic. v1 is **not** changed by this note.

## 0. Decision (maintainer, 2026-11-14): decided, binding in INTERFACES.md "Review mode per milestone"

*"per milestone should be the default and users can request a review per task if they like more control for a
milestone, but users need to ask for it actively. if the user doesn't review per task then there needs to be a
auto-review round per task not only per sub-task to get the whole picture for a auto-review as well"*

- **Default = B**: the maintainer reviews the milestone only; tasks merge after a validated agent review.
- **Opt-in per milestone, asked actively**: at planning the maintainer may choose per-task manual reviews (A) for
  that milestone. Not asked for → milestone-only. This replaces C's per-task labels (§2, §3 item 1).
- **Agent review of every whole task** when there is no per-task manual review: one agent review of the full task
  diff, also when its sub-tasks were reviewed on their own.
- **Size cap**: ~2,000 changed lines per milestone in milestone mode (a guess; calibrate in the dry run).
- **Interim merge** (architect): until backlog-ng (a) exists, the task manager merges an agent-reviewed task into the
  milestone branch itself and sets it Done. This replaces §3 item 2 ("no hand merges"). In milestone mode the hand-merged
  commits showing as open in the milestone review is wanted: the maintainer reviews them there (it covers (b)).
- **Order** (architect's proposal, open for the maintainer): dry run of milestone mode now with the interim merge;
  backlog-ng (a) + (b) afterwards; then a second dry run. This replaces §3 item 4 (G0 is judged under milestone mode).

## 1. Where v1 stands today

The original idea (draft §1, first version): agents implement, review and merge the tasks; the maintainer reviews
only the whole milestone. After trial-run finding 2 (tasks approved before their agent review) the maintainer chose
"tasks too, after agent review" (D7 revised in decisions.md; draft §4 steps 5–6 and §5); D9 (decisions.md; draft §1
and the Definition of Ready) keeps one manual review per whole task, also with sub-tasks.

For a milestone of N tasks plus k extra tasks (fix, sync, regression, gap), the maintainer does today:

| Manual review | Count |
|---|---|
| per task in the review app (after its agent review) | N + k |
| milestone review task before `main` | 1 |
| re-review after a rejection or compensation | per occurrence |

- That is **more** manual reviews than the baseline (N: one session per task + `/code-review` + review).
- The maintainer is back on the **critical path**: a task that depends on another waits until that one is approved
  and merged.
- **G0** (≥ 30 % less maintainer time) could only be won by every review being much shorter. Critic: practically
  unreachable; a dry run under today's model would say "no go" for the wrong reason.

## 2. Options

| | A: per task (today) | B: milestone only (original idea) | C: hybrid (recommended target) |
|---|---|---|---|
| Maintainer reviews | every task + the milestone | the milestone only (diff grouped by task) | the milestone + tasks labelled `manual-review` |
| Manual reviews per milestone | N + k + 1 | 1 (+ re-reviews) | 1 + labelled tasks |
| Task merge into `milestone-*` | after the maintainer's approval | after a validated agent review ("agent finish") | B, or A for labelled tasks |
| backlog-ng needs | nothing new (the review-app gate) | (a) agent finish for targets `milestone-*` only, refused for `main`/`release` in backlog-ng; (b) milestone review shows agent-approved commits as still to review by the maintainer, marked "agent-reviewed" | (a) + (b) |
| Race of finding 2 | solved by the review-app gate | gone: tasks never go In Review | gone for unlabelled tasks; review-app gate for labelled |
| Main risk | G0 not reachable; maintainer on the critical path | one large, late review; defects surface late | as B, smaller for the risky parts |

Mitigations for B/C (architect, critic): the agent gate before every merge; a milestone size cap (~2,000 changed
lines, a guess to calibrate); the report and the review app group the milestone diff by task; rework after a
rejection runs as normal fix tasks. Escaped defects are what G0 measures, so the risk is measured, not assumed.

C stays simple only if the label is set **once, at plan approval, by the maintainer**, plus tasks with an escalated
critical/major finding. No dynamic rules (critic).

## 3. Recommendation (all three sessions agree)

1. **Target C**: milestone-only review by default; a per-task manual review only for tasks the maintainer labels
   `manual-review` at plan approval (e.g. security, user data, migrations, public API) and for escalated tasks.
2. **Interim A** until backlog-ng has (a) and (b). No return to agent hand merges in the meantime (the hooks block
   them, and they would bring back the "open commits" problem of #3).
3. **backlog-ng (a) + (b) become the top tool request**, recorded as the concrete work of open point #3.
4. **Dry run**: run it under A now to calibrate review times, but judge G0's go/no-go only under C, against the same
   baseline.

## 4. Decisions for the maintainer

1. Target model: C (recommended), B, or stay with A.
2. If C: the default list of `manual-review` categories, and whether escalated tasks join it automatically.
3. Milestone size cap: ~2,000 changed lines as the starting value?
4. Order: commission backlog-ng (a) + (b) before the G0 dry run, or run the dry run under A first?
