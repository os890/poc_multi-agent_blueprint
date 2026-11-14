# Architecture review

Scope: Structure of the changed code against the project's architecture docs and decisions.

Check:

- Logic in the right layer and module; module and package boundaries respected; no new dependency cycles.
- Interfaces and extension points used as intended; no duplicated mechanism next to an existing one.
- Decisions the change makes implicitly that should be recorded (data formats, persistence, threading model).
