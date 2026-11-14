# Security review

Scope: Security of the changed code.

Check:

- Input validation of every new or changed external input (paths, IDs, sizes, URLs).
- Path traversal, symlink following, injection (shell, SQL, HTML, XML/XXE), unsafe deserialization.
- New endpoints, IPC or bridges: authentication, origin checks, least privilege.
- Secrets, logs (no sensitive data), temp files, file permissions.
- Processes started with user data: no shell, arguments as a list.
