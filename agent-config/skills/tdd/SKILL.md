---
name: tdd
description: Test-driven development guideline - the red-green-refactor cycle, what makes a test good or bad, and what to do when no automated test is possible. Reference only; next, fix and diagnose point here.
---

# TDD guideline

Reference for the workflow skills. Do not run it on its own.

## Cycle: red, green, refactor

1. **Red:** write one test for one behavior. Run it and **see it fail for the expected reason** (assertion, not a typo or import error). A test that never failed proves nothing.
2. **Green:** write the minimal code that makes it pass. No extra features, no speculative generality.
3. **Refactor:** with all tests green, clean up the code you just touched (names, duplication). Re-run the tests after each change. Never refactor on red, never beyond the step's scope.

One behavior per cycle. Repeat until the step's "Done when" holds. Do not write all tests first and all code afterwards.

## Good tests

- Check **behavior through the public interface** (inputs, outputs, observable effects), not internal structure.
- Deterministic and fast: no real time, network, randomness or test-order dependence; fake only those boundaries.
- Named by behavior: `rejects_expired_token`, not `test1` or `testValidate`.
- Survive refactoring: renaming a private function must not break them.
- One reason to fail; arrange, act, assert stay readable at a glance.

## Bad tests

- Assert implementation details (private calls, call order, internal state).
- Mock everything, including your own code, until only mocks are tested.
- Snapshot spam: large snapshots nobody reads, accepted blindly on every change.
- Adapted to pass: changing the expected value to match the output, loosening an assertion, or skipping/deleting a failing test. Understand the failure first; if the test is wrong, say why.
- Copy of the production logic (the test computes the expected value the same way as the code).

## Bug fixes

Reproduce the bug with a failing test first (regression test), then fix, then confirm the test is green and the neighbouring tests still pass.

## No automated test possible

UI layout, infrastructure, config, shell glue, one-off migrations: say so explicitly in the report and name the **manual check** (exact command or click path and the expected result). Do not claim "tested" for something you only read.
