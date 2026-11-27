---
name: diagnose
description: Hunts a hard bug with a fixed loop - red feedback loop, minimize, ranked hypotheses, instrumentation, test-first fix, regression test - records the cause in .agent/notes.md, then stops with a commit suggestion. Input is a refined prompt (.agent/prompts/<slug>.md) or free text. Use when the user runs /diagnose or reports a hard, flaky or unclear bug where guessing failed.
---

# Diagnose: find the cause, fix it, one commit

Respond in the user's language. **One bug per invocation, one commit.** You may start without the conversation history; rely on the prompt file, git and the code. Conventions: see the `agent-workspace` skill.

## 1. Input and gates

Argument: a path to a prompt file (`.agent/prompts/<slug>.md`, see `refine`) or free text. Read the file (Goal = symptom, Acceptance criteria = checks, Boundaries = out of scope) or restate symptom and expected behavior in two lines. If `.agent/GLOSSARY.md` exists, use its terms.

1. `git status --porcelain` (ignore `.agent/`): uncommitted changes -> **STOP**, ask the user to commit or stash first.
2. `.agent/plan.md` has a `[~]` step -> **STOP**, run `/next` after committing. Never touch `.agent/plan.md`.

## 2. Loop

Do not change production code before phase 1 is done. Understand the cause before fixing it.

1. **Red feedback loop:** build the fastest deterministic way to see the bug - a failing test, a script or a command. Run it and see it fail for the reported reason. Flaky? Pin time, seed, order or input until it fails every run. No loop possible -> stop and report what is missing.
2. **Minimize:** shrink input, config and steps until only the failing core remains.
3. **Hypotheses:** list 3-5 candidate causes, ranked by likelihood, each with a prediction ("if X, then Y shows up at Z"). Check the cheapest first.
4. **Instrument:** add temporary logs or asserts to test one prediction at a time. Mark each with `DIAGNOSE-TMP` and remove all before the report (`rg DIAGNOSE-TMP` must be empty).
5. **Fix** following the `tdd` skill: the loop from phase 1 becomes the failing test, apply the minimal fix, see it green, refactor only within the fix.
6. **Regression test:** keep a `regression test` that fails without the fix. If only a script is possible, say so and name the manual check.

Stop after 5 rejected hypotheses without a hit: report what was ruled out and what to try next, no half fix. Fix needs more than one commit -> write the cause to notes and suggest `/plan-commits <prompt path>`.

## 3. Record

Cause, rejected hypotheses and the reproduction go to `.agent/notes.md` (format in `agent-workspace`), so they survive `/clear`.

## 4. Stop for the commit

Run the regression test, the related tests and lint. Report compactly (at most ~25 lines):
- **Cause:** one or two lines, with `file:line`
- **Ruled out:** rejected hypotheses, one line each
- **Changed:** each file with one line, test first
- **Checks:** each command -> passed / failed
- **Review:** `git diff` or Zed `<space> g g`
- **Commit** (Conventional Commits, English):
  ```
  git add -A
  git commit -m "fix(<scope>): <message>"
  ```

**Never run `git commit` or `git push` yourself** unless the user explicitly asks for it in this turn. **Stop.**
