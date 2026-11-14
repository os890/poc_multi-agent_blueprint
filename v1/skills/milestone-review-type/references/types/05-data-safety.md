# Data safety review

Scope: Changed code that reads, writes, moves or deletes the user's data.

Check:

- Nothing is deleted or overwritten without an explicit user action and, where the project requires it, a confirmation.
- Writes are atomic or recoverable; a crash or error at any step leaves the data intact.
- Copy, move and delete handle symlinks, special files, cross-volume moves and name clashes as specified.
- Destructive paths have tests, including failure in the middle.
