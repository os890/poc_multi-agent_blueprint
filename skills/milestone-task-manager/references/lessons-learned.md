# Lessons learned: record basic mistakes so they don't happen again

The project keeps one lessons-learned file (path in the project's `CLAUDE.md`, default `docs/lessons-learned.md`).
It lists basic mistakes that caused, or would have caused, a major problem. Workers read it before they implement,
reviewers check every diff against it. It stays short: it is a list of rules, not a history.

## When to record a lesson

All three must be true:

1. **Basic mistake**: the cause is a simple, general one that a one-line rule could have prevented (e.g. an
   unchecked input, a path built by string concatenation, a missing error path, a platform forgotten, a test that
   checks nothing, a destructive command without a guard). Not: a one-off misunderstanding of the domain, a
   wrong requirement, bad luck.
2. **Major impact**: it caused or would have caused a critical or major problem (severity scale of the skill).
3. **Confirmed**: the reviewer confirmed it, a test failed, or it came from the maintainer.

Sources to check: confirmed critical/major findings of a task review or the milestone review, full-suite failures
and regressions, findings of the maintainer's manual review (always check these: the agents missed them), failed
merges into `main`, and workflow incidents (an agent broke a hard rule or a hook stopped it).

Not a lesson: minor findings; mistakes already caught automatically (a test, a lint rule, a hook) - unless that
automation was missing and is now the fix.

## How to record it

- Right away, not at the retrospective: the next tasks of this milestone should already benefit.
- Same mistake as an existing lesson → no new entry; add the occurrence to `seen` of that lesson.
- New lesson → next free number, entry below. Commit it on the milestone branch in your milestone checkout:
  `lessons: L-<n> <title>`. It reaches `main` with the milestone, so the maintainer sees every new or changed lesson
  in the manual review; the milestone review report lists them.
- Note `lesson: L-<n>` at the finding in the task notes.

File header (create the file with it if it doesn't exist):

```markdown
# Lessons learned

Basic mistakes that caused, or would have caused, a major problem. Workers read the active lessons before they
implement; every review checks the diff against the active lessons of its review type.
```

Entry:

```markdown
## L-<n>: <short title>

- applies to: <review types, e.g. code, security> | workflow
- severity:   critical | major (what it caused or would have caused)
- seen:       M<n> TASK-<id> (<task review | milestone review | full suite | manual review | merge into main>), ...
- mistake:    one sentence: the basic mistake
- rule:       one sentence, checkable on a diff: what the code must (not) do
- check:      how to spot it in a diff (pattern, search, question to ask)
- status:     active | automated (<test, lint rule or hook>) | retired (<reason>)
```

Rules are concrete and checkable ("every file path from user input goes through `<sanitizer>`"), never vague
("be careful with paths"). `applies to: workflow` lessons are about the agents' own process; you read them at the
start of each milestone, reviewers skip them.

## Use in the reviews

- Pass `lessons=<path>` (the file in your milestone checkout) with every review request; each review-type
  sub-agent checks the diff against the active lessons of its type only.
- A violation is reported with `lesson: L-<n>` and at least the lesson's severity: a known mistake is never minor.
- A confirmed violation counts as a repeat: add it to `seen`.

## At the retrospective (`retrospective.md`)

- Metrics: new lessons, repeats per lesson.
- A lesson seen a second time is not enforced well enough by text: the improvement task automates it (test, lint
  rule, hook; status `automated`) or sharpens its rule.
- A lesson that is not project-specific is proposed for the reviewer checklist of its type in the skills, so other
  projects benefit too. `OPEN(#29, #37)`
- Retire lessons that no longer apply (code removed, automated elsewhere). Keep at most 30 active lessons; more
  means rules are not being automated. `OPEN(#37)`
