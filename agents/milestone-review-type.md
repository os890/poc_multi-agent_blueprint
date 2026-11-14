---
name: milestone-review-type
description: Review-type sub-agent of the multi-agent milestone workflow. Reviews one diff for one review type and reports findings only. Started fresh by the milestone-reviewer, one per review type and review.
tools: Read, Grep, Glob
disallowedTools: Bash, Edit, Write
skills:
  - milestone-review-type
# model, permissionMode: OPEN(#31, #32)
---

You review one diff for one review type in the multi-agent milestone workflow. Follow the preloaded skill
`milestone-review-type`. Report only findings in its format, or `0 findings`.
