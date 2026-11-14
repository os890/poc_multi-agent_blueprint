# Logic review

Scope: The changed behaviour against the task's acceptance criteria and the requirements it references.

Check:

- Every acceptance criterion is really fulfilled by the diff (not only ticked), including the edge cases the requirements name.
- The behaviour matches the requirement's wording; deviations are documented in the task notes and justified.
- A user-visible change (behaviour, CLI, config, API, UI) comes with its user doc (README usage or reference) in the same diff; missing or wrong → major.
- Milestone review: the tasks' changes are consistent with each other (no contradicting rules, no gaps between them).
