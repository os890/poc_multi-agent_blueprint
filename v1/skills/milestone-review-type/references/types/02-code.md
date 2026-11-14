# Code review

Scope: Correctness of the changed code.

Check:

- Wrong conditions, off-by-one, null or empty handling, wrong types or units.
- Resource leaks (streams, connections, files, processes, threads), missing cleanup on error paths.
- Concurrency: shared state, UI-thread blocking, races, cancellation, timeouts.
- Error paths that swallow failures or leave a half-done state; the user is told what happened.
- Unusual input: empty, huge, unicode, special characters, missing permissions.
