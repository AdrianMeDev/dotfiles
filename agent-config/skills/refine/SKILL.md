---
name: refine
description: Turns a rough prompt plus context (ticket text, paths) into a precise, reusable prompt for a roadmap, a commit plan or a fix, via grill rounds, and saves it to .agent/prompts/<slug>.md. Use when the user runs /refine, wants to sharpen a request before planning, or pastes a ticket. Does not write code.
---

# Refine: rough request to precise prompt

Respond in the user's language. Conventions (`.agent/` layout, exclude helper, git rule): see the `agent-workspace` skill. **Do not write code.** Only write under `.agent/`.

## 1. Input

Arguments: `<roadmap|commits|fix> <text, ticket, paths>`.
- Existing file paths in the arguments: read them as context.
- No target given: Q1 of the first round asks for it, with a recommendation:
  - `roadmap`: big, several milestones, new app or epic -> `/plan-roadmap`
  - `commits`: one feature or task, several commits -> `/plan-commits`
  - `fix`: one small correction, one commit -> `/fix`

## 2. Rounds

Follow the `grill` skill (read its SKILL.md): numbered rounds over the open decisions, every question with a recommended answer, facts looked up yourself, glossary read first and resolved terms recorded via `grill`.

Aim the questions at the sections of the prompt template (`PROMPT-FORMAT.md`):
- Goal: what is different afterwards, and for whom?
- Context: which files, modules, tickets, constraints? (look up paths yourself)
- Acceptance criteria: observable and testable; for `fix` also how to reproduce the bug.
- Boundaries: what is explicitly out of scope?

Ask only what is still open. A precise request needs one short round, not five.

## 3. Write

When the frontier is empty:
1. Run the exclude helper from `agent-workspace`, create `.agent/prompts/` lazily.
2. Slug: kebab-case title. Existing file with that slug: ask before overwriting.
3. Fill the template for the chosen target from `PROMPT-FORMAT.md`. Use glossary terms. Do not invent facts; unresolved points go under Boundaries or as an open question.
4. Write `.agent/prompts/<slug>.md`.

## 4. Done

Show the file path and a 3-line summary. Ask the user to read the file and confirm or correct it. Then suggest the matching next command, nothing else:
- `roadmap`: `/plan-roadmap .agent/prompts/<slug>.md`
- `commits`: `/plan-commits .agent/prompts/<slug>.md`
- `fix`: `/fix .agent/prompts/<slug>.md`

Do not start planning or implementing yourself.
