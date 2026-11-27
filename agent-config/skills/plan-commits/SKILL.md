---
name: plan-commits
description: Plans a task - or the next open milestone of the roadmap - as a sequence of small, commit-sized steps, saves the plan to .agent/plan.md and stops for approval without implementing anything. Use when the user asks to plan a task, break work into commits, start the next milestone, or runs /plan-commits. The steps are then executed one at a time with the `next` skill.
---

# Plan work as commit-sized steps

**This skill only plans. Do not change any source code. You only write `.agent/plan.md` (and, for an untracked roadmap, the milestone status).**
Respond in the user's language.

## 1. Find the task

Conventions (layout, exclude helper, legacy paths, git rule) are in the `agent-workspace` skill – follow it.

Look for a roadmap: `.agent/ROADMAP.md`, then `docs/ROADMAP.md`, then `ROADMAP.md` in the repository root.

- **User passes a prompt file** (an existing file, typically `.agent/prompts/<slug>.md` from `refine`) → read it as the task: Goal and Context are the task, Acceptance criteria become **Done when**, Boundaries become out of scope. `Target:` is not `commits` → hint and continue only after confirmation.
- **User passes a task** (free text) → plan that task. If a roadmap exists and the task clearly belongs to one of its milestones, say so and link it.
- **User passes a milestone id** (e.g. `M2`) → plan that milestone.
- **No argument and a roadmap exists** → take the first milestone marked `[ ]` whose dependencies are `[x]`. Name it and confirm in one line ("Planning M2 – <name>. OK?") unless the user already said which one.
- **No argument and no roadmap** → ask what to plan. If it sounds bigger than ~8 commits, suggest `/plan-roadmap` first.

When planning a milestone, read only the roadmap parts you need: its milestone section, Architecture, Decisions and Definition of done. Its **Goal**, **Includes** and **Done when** are the task and the acceptance criteria.

## 2. Understand the task

1. Restate the task in 2–3 sentences in your own words.
2. Explore read-only: the affected code, existing patterns and conventions, tests, and the project's commands (README, `package.json`, `pyproject.toml`, `*.csproj`, `.zed/tasks.json`, `CLAUDE.md`/`AGENTS.md`).
3. If `.agent/GLOSSARY.md` exists, read it (and relevant `.agent/adr/*.md`): use its terms in steps and commit messages, and list conflicts with the task wording as assumptions.
4. If something essential is ambiguous, ask at most 3 short questions **before** writing the plan. Otherwise state your assumptions in the plan.

## 3. Check the starting point

- Run `git status` and `git branch --show-current`.
- Uncommitted changes? Point them out: they should be committed or stashed before step 1.
- On the main branch? Suggest a feature branch name (do not create it yourself).
- An existing `.agent/plan.md` with open steps? Show its status and ask whether to replace it.
- An old `.agent-plan.md` in the repository root (legacy)? Offer to move it to `.agent/plan.md` (`mkdir -p .agent && mv .agent-plan.md .agent/plan.md`); do not move it without asking.

## 4. Design the steps – one step = one commit

Every step must:
- have **one purpose** and be small: ideally under ~200 changed lines and a handful of files; a step that needs much reading (agent budget ~150k tokens) is split;
- leave the project **buildable with green tests** – no broken intermediate states (if needed, add code that is not wired up yet, or put it behind a flag);
- build on the previous steps in a sensible order, for example: data model/migration → domain logic + tests → API/endpoint → frontend service → UI → docs;
- include the tests for the behaviour it adds (or write them first);
- keep refactorings separate from behaviour changes;
- have a concrete, checkable "done when" and a command that verifies it.

Typically 3–8 steps. More than ~8 steps → the work is too big for one plan: for a milestone, propose splitting it in the roadmap (change the roadmap only after the user agrees); for a free task, suggest `/plan-roadmap`.

**When planning a roadmap milestone**, keep the roadmap status in sync through the commits themselves:
- Check whether the roadmap is tracked: `git ls-files --error-unmatch <roadmap>`.
- **Tracked:** step 1 also sets the milestone to `[~]`, the last step sets it to `[x]` and adds a Changelog line – list `<roadmap>` under **Changes** of those two steps. So the roadmap is never changed outside a commit.
- **Not tracked:** set the milestone to `[~]` in the roadmap now; `next` sets `[x]` when the last step is committed.
- The last step's **Done when** includes the milestone's **Done when** and the roadmap's Definition of done.

## 5. Write `.agent/plan.md`

First make sure `.agent/` is excluded from git (exclude helper in `agent-workspace`; never touch `.gitignore`), then create `.agent/plan.md` using exactly this structure.

```markdown
# Plan: <short title>
Created: <YYYY-MM-DD> · Branch: <branch> · Base: <short hash of HEAD>
Milestone: <M2 – name (<roadmap path>, tracked|local)> or "none"

## Goal
<2–3 sentences: what will work at the end, and for whom>

## Assumptions
- <assumption or "none">

## Steps

### 1. [ ] <commit message, Conventional Commits, English>
- **Why:** <one sentence>
- **Changes:** `<path>` – <what>; `<path>` – <what>
- **Done when:** <checkable criteria>
- **Verify:** `<command>`

### 2. [ ] <commit message>
...

## Log
```

Status markers: `[ ]` open · `[~]` implemented, waiting for commit · `[x]` committed (followed by ` – <short hash>`) · `[-]` skipped.

## 6. Present and stop

Show the plan compactly: milestone (if any) and goal, then one line per step (number, commit message, verify command), then assumptions and risks.

End with: **"Change the plan if needed, or run `/next` to implement step 1."** and, on a separate line: "Tip: once the plan is approved, `/clear` (Claude Code) or `/new` (pi) is safe – everything needed is in `.agent/plan.md`."

**Stop here. Do not start implementing.** If the user asks for changes, update `.agent/plan.md` and show the updated step list again.
