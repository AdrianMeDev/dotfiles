---
name: fix
description: Makes one small correction test-first - reproduces the problem with a failing test, applies the minimal fix, verifies it, then stops with a commit suggestion. Input is a refined prompt (.agent/prompts/<slug>.md) or free text. Use when the user runs /fix or asks for a small bug fix or correction that needs no plan.
---

# Fix: one small correction, one commit

Respond in the user's language. **One fix per invocation, one commit.** You may start without the conversation history; rely on the prompt file, git and the code. Conventions: see the `agent-workspace` skill.

## 1. Input

Argument: a path to a prompt file (typically `.agent/prompts/<slug>.md`, see `refine`) or free text.
- File: read it. Goal is the problem, Acceptance criteria are the checks, Boundaries are out of scope. A `Target:` other than `fix` → hint, continue only after confirmation.
- Free text: restate the problem and acceptance criteria in two lines.
- If `.agent/GLOSSARY.md` exists, read it and use its terms.

## 2. Gates

1. `git status --porcelain` (ignore `.agent/`): uncommitted changes → **STOP**, show the files and ask the user to commit or stash first.
2. `.agent/plan.md` has a `[~]` step → **STOP**, a plan step waits for its commit; run `/next` after committing.
3. The fix needs more than one commit (several modules, migration, design decision) → **STOP**, explain why, suggest `/plan-commits <prompt path>`.

Never touch `.agent/plan.md`.

## 3. Fix, test first

1. Search the cause (`rg`, symbols), read only the relevant parts. Understand the cause before changing code; no symptom workarounds.
2. Write a failing test that reproduces the problem and run it to see it fail. No test setup possible → say so and name the manual check instead.
3. Apply the minimal fix. No refactoring, no formatting changes elsewhere, no new dependencies.
4. Run the test again, then the related tests and lint.
5. Still failing after two attempts → stop and report error, diagnosis and options.

Findings that must survive `/clear` go to `.agent/notes.md` (format in `agent-workspace`).

## 4. Stop for the commit

Report compactly (at most ~20 lines):
- **Fix done:** one line on the problem and the cause
- **Changed:** each file with one line, test first
- **Checks:** each command → passed / failed
- **Review:** `git diff` or Zed `<space> g g`
- **Commit** (Conventional Commits, English):
  ```
  git add -A
  git commit -m "fix(<scope>): <message>"
  ```

**Never run `git commit` or `git push` yourself** unless the user explicitly asks for it in this turn. **Stop.**
