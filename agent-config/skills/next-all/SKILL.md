---
name: next-all
description: Works through the entire commit plan in .agent-plan.md autonomously - creates a feature branch, then implements, verifies and commits every open step itself until the plan is finished. Use when the user runs /next-all or says "arbeite den Plan ab", "alle Schritte", "continue with the plan" or "weiter". Optional arguments - a step number to start from, "skip" to skip the current step, "once" to do only one step.
---

# Execute the whole plan

Respond in the user's language. **Work through all open steps in one run, one commit per step, until `.agent-plan.md` has no open steps left.** Do not wait for review between steps.

## Commit message format

Every commit message must look like this:

```
feat(planning): expose week plans through the API
```

Rules: `<type>(<scope>): <description>` – type is one of `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `build`, `ci`; scope is a short lowercase module or domain name; description is imperative, lowercase, no trailing period, max 72 characters in total. If a message in the plan does not match, normalize it before committing (and update the plan). Append any commit attribution lines the environment requires.

## 1. Load the plan

Read `.agent-plan.md` in the repository root.
No file, or no open steps? Say so, suggest `/plan-commits <task>`, and stop.

## 2. Prepare the branch

1. `git status --porcelain` (ignore `.agent-plan.md`). Unrelated uncommitted changes that do not belong to a `[~]` step: **stop** and ask. Never stash or discard on your own.
2. Make sure `.agent-plan.md` is never committed: add it to `.git/info/exclude` if it is not tracked or ignored yet.
3. Determine the branch:
   - Plan header has a `Branch:` line → `git checkout <branch>`.
   - Otherwise, on the default branch (`main`/`master`/`develop`) or detached: `git checkout -b feat/<short-kebab-slug-of-plan-title>`, and write `Branch: <name>` and `Base: <short hash>` into the plan header.
   - Already on a non-default branch → use it and record it in the plan header.
4. **Never commit on the default branch.** Never push, force-push, rebase or reset unless the user explicitly asks.

Leftovers from the old review workflow: a `[~]` step with uncommitted changes → re-run its Verify command; if it passes, commit it (section 4) and continue; if not, fix it first. A `[~]` step with clean tree and unchanged HEAD → ask the user what happened.

Arguments:
- a number → start at that step instead of the first open one (ask if earlier steps are still open);
- `skip` → mark the first open step `[-]`, log the reason, continue with the next;
- `once` → stop after one step (section 5 applies).

## 3. Loop: for each open `[ ]` step, in order

1. Announce in one line: **"Step n/N: <commit message>"**.
2. Re-read the files involved – the user may have changed code since planning.
3. Implement **only** what this step describes, following the project's conventions. Include the planned tests. Be lazy about the solution, never about reading the code: read the code and callers first, then take the first option that fully works – (1) does it need to exist? (2) already in the codebase? (3) standard library or platform, unless the project has its own (a house UI library beats the native widget)? (4) installed dependency? (5) one readable line? (6) only then the minimum code. No abstraction, option or "for later" code nobody asked for. Validation at trust boundaries, data-loss error handling, security and accessibility are never cut. A shortcut with a known limit gets a comment: `shortcut: <limit>, <when to upgrade>`.
4. **Verify:** run the step's **Verify** command plus fitting quick checks (lint, type check, related tests). Fix failures that belong to this step. If it still fails after two attempts: mark the step `[!]`, log error and diagnosis, leave changes uncommitted, **stop the whole run** and report the options.
5. **Commit** (section 4), mark the step `[x] – <short hash>` in the plan, add a Log line, and continue with the next step immediately.

### When the plan is wrong

- **Small deviation** (file lives elsewhere, one extra small change, different scope in the message): adapt, keep the commit self-contained, note it in the Log.
- **Big deviation** (step much larger than planned, wrong approach, missing prerequisite): split it or add a step in the plan, log the reason, continue. Only **stop and ask** if it needs a decision that is the user's to make (product behavior, destructive change, new dependency, architecture change).
- Never silently expand scope and never skip tests to get green.

## 4. Commit

1. `git status --porcelain`: only files belonging to this step may be changed. Unrelated changes → leave them out, mention in the Log.
2. Stage and commit:
   ```
   git add -A
   git commit -m "<type>(<scope>): <description>"
   ```
3. Check the format against the rules above; if a hook fails, fix and retry (never `--no-verify`).
4. Confirm with `git log --oneline -1`.

## 5. Finish

When no open steps remain (or after `once`, or after a stop):

- Show all commits: `git log --oneline <Base>..HEAD`.
- Report compactly: branch, commits (hash + message), skipped `[-]` / failed `[!]` steps with reasons, deviations from the plan, result of one final full test/lint run, and one or two lines on what you skipped or did not check and any risk the user must know.
- Offer a short pull-request description (title, summary, testing notes).
- Do **not** push; tell the user: `git push -u origin <branch>`.
- Ask whether to delete `.agent-plan.md`.
