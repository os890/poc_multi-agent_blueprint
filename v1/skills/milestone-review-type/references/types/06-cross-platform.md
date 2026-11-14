# Cross-platform review

Scope: Changed code and scripts on every platform the project supports.

Check:

- Paths via the platform API: no hard-coded separators, no case-sensitivity assumptions, drive letters, long paths, reserved names.
- Platform-specific code paths for each supported OS; behaviour that differs is intended and documented.
- Scripts: equivalent variants per platform, line endings, compatibility with the shell versions the project supports.
- Tests that run on one OS only are marked; the other OS is covered elsewhere.
