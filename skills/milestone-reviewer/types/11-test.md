# Test review

Scope: The tests added or changed in the diff, and the tests the diff needs.

Check:

- Tests check behaviour, not implementation details, and would fail if the behaviour broke; meaningful assertions.
- Missing tests: acceptance criteria without a test, error paths, edge cases, platform-specific behaviour, failures in the middle of destructive operations.
- Fast tests belong to the minimal suite, slow and end-to-end tests to the full suite; tests don't touch the real user configuration.
- Flaky constructs: sleeps instead of waiting for a condition, order dependence, shared state between tests.
