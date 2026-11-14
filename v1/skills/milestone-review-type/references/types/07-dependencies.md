# Dependencies and licenses review

Scope: Every dependency added or upgraded in the diff.

Check:

- Needed at all; maintained; no known vulnerability in the chosen version.
- License compatible with the project's license for distribution.
- Version pinned or locked; installs use `--ignore-scripts`; no new network access at runtime unless specified.
- Third-party notices updated where the project keeps them.
