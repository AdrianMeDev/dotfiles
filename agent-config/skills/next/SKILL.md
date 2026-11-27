---
name: next
description: Implements exactly the next open step of the commit plan in .agent/plan.md, verifies it, then stops so the user can review and commit before continuing. Use when the user runs /next or says "next step", "continue with the plan", "weiter" or "nächster Schritt". Optional arguments - a step number to jump to, or "skip" to skip the current step.
---

# Execute the next plan step

Respond in the user's language. **One step per invocation – never more.**

You may start without the conversation history (in Claude Code this skill runs in a fresh subagent to save tokens). Everything you need is in `.agent/plan.md`, git and the code – rely on those, not on memory.

## 1. Load the plan

Read `.agent/plan.md` (fallback for old projects: `.agent-plan.md` in the repository root). Conventions are in the `agent-workspace` skill.
No file, or no open steps? Say so, suggest `/plan-commits <task>`, and stop.

## 2. Gate: is the previous step committed?

If a step is marked `[~]` (implemented, waiting for commit):

1. Run `git status --porcelain` and `git log --oneline -5`.
2. **Uncommitted changes present** (ignore `.agent/` and a legacy `.agent-plan.md`): **STOP – do not start new work.** Show:
   - the changed files,
   - a review hint: `git diff` or the Zed git panel (`<space> g g`),
   - the commit commands with the message from the plan:
     ```
     git add -A
     git commit -m "<message from the plan>"
     ```
   - "Run `/next` again after committing."
3. **Working tree clean and HEAD is newer than the hash noted at the `[~]` marker:** mark the step `[x] – <short hash of HEAD>` and add a line to the Log section. Continue with section 3.
4. **Working tree clean but HEAD unchanged:** the changes were discarded or stashed – report this and stop; do not start new work.

The user can override the gate explicitly (e.g. "continue without commit"). Then note it in the Log and continue.

Arguments:
- a number → work on that step instead of the first open one (ask if earlier steps are still open);
- `skip` → mark the first open step `[-]`, log the reason, and stop.

## 3. Implement exactly one step

1. Take the first `[ ]` step (or the requested one) and announce it: **"Step n/N: <commit message>"**.
2. Re-read the files involved – the user may have changed code since planning.
3. Implement **only** what this step describes, following the project's conventions. Include the planned tests.
4. If the plan turns out to be wrong or the step is too big: **stop**, explain why, and propose an updated plan (split the step, reorder, add a step). Change the plan only after the user agrees. Never silently expand the scope. Findings that must survive `/clear` (open points, decisions, surprises) go to `.agent/notes.md` in the format from `agent-workspace`.

## 4. Verify

Run the step's **Verify** command plus quick checks that fit (lint, type check, related tests).
Fix failures that belong to this step. If it still fails after two attempts: stop and report the error, your diagnosis and the options.

## 5. Stop for the commit

1. Mark the step `[~] (on <short hash of current HEAD>)` in the plan file, so the next run can tell whether a commit happened.
2. Report, compactly (at most ~25 lines – this report is all the main session keeps):
   - **Step n/N done:** `<commit message>`
   - **Changed:** each file with one line on what changed
   - **How it works:** 2–4 sentences, with `file:line` for the key places (for a full explanation: `/explain`)
   - **Checks:** each command → passed / failed
   - **Review:** `git diff` or Zed `<space> g g`
   - **Commit:**
     ```
     git add -A
     git commit -m "<message – adjusted if the implementation differs from the plan>"
     ```
   - **Next:** "After committing, run `/next` for step n+1: `<next commit message>`."
3. **Do not run `git commit` or `git push` yourself** unless the user explicitly asks for it in this turn.
4. **Stop. Do not start the next step.**

## 6. After the last step

When `/next` finds the last step committed:
- mark it `[x]`, show all commits of the plan: `git log --oneline <base>..HEAD`;
- if the plan has a **Milestone** that is `local` (not tracked): set it to `[x]` in the roadmap and add a Changelog line (for `tracked` roadmaps the last commit already did this – check it);
- offer a short pull-request description (title, summary, testing notes);
- ask whether to delete the plan file;
- if the roadmap has more open milestones: name the next one and suggest **`/clear`, then `/plan-commits`**.

If, while implementing, you notice that the roadmap itself is wrong (an assumption, a decision, the order of milestones), do not change it – mention it in the report and in the Log so the user can update it with `/plan-roadmap`.
