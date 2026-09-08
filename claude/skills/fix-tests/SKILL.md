---
description: Detect this project's test runner, run the tests, and fix any failures. Use when tests are failing, or when asked to run or fix tests.
---

## Project files

!`ls package.json pnpm-workspace.yaml turbo.json pyproject.toml requirements.txt pom.xml build.gradle go.mod Makefile 2>/dev/null`

## Instructions

1. **Detect the runner** from the files above:
   - `package.json` → check its `scripts` for `test` (pnpm/npm/yarn; this may be vitest, jest, or playwright). In a turbo/pnpm monorepo, prefer running tests only for the affected package first.
   - `pyproject.toml` / `requirements.txt` → pytest (check for a configured runner first).
   - `pom.xml` → `mvn test`; `build.gradle` → `./gradlew test`; `go.mod` → `go test ./...`.
   - `Makefile` → look for a `test` target.
2. **Run the tests.** If a specific failure was mentioned, run just that test file first for a fast loop.
3. **Fix failures one at a time**: read the failing test and the code under test, decide whether the bug is in the code or the test is outdated, fix the root cause — never weaken or skip a test just to make it pass.
4. Re-run until green, then run the full suite once to check for regressions.
5. Report: what failed, what the root cause was, what you changed.
