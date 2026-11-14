# Docs review

Scope: The product docs a user or the next developer needs for what the milestone changed: README (what it is,
install, usage), the reference for changed CLI, config or API, and, only where the project already keeps them,
decision records and `CHANGELOG.md`. Not process files (retro, lessons, task notes).

Check:

- Every user-visible change of the milestone is documented where a user looks for it; missing or wrong → major.
- Build, install, run and test instructions still work as written; broken → major.
- A decision that changes structure, data formats or a dependency has its record, if the project keeps decision
  records; missing → minor.
- Docs say only what the code does: no duplicate of the code, no outdated sections, no diagrams nobody maintains;
  stale or redundant text → minor.
