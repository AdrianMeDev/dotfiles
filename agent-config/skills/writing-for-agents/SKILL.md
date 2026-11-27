---
name: writing-for-agents
description: Writing rules for documents that agents read - skills, CLAUDE.md and AGENTS.md. Pointers instead of inline content, two budgets (context load, cognitive load), information hierarchy, checkable completion criteria. Use when writing or editing a skill, CLAUDE.md or AGENTS.md; retro loads it first.
---

# Writing for agents

Reference for the workflow skills. Do not run it on its own.

## Scope

Applies to every file an agent reads as instructions: `SKILL.md` and its helper files, `CLAUDE.md`, `AGENTS.md`, prompt templates. Not for user-facing docs (README).

## Two budgets

- **Context load:** every line is paid for on every run, read or not. Keep always-loaded files short; move detail into helper files that are read only when needed.
- **Cognitive load:** every extra rule competes with the others. Fewer, sharper rules are followed better than many soft ones.

## Rules

1. **Point, do not inline.** Name the file, skill or command (`see the agent-workspace skill`) instead of copying its content. Copies drift.
2. **One source per fact.** State a rule in one place; everything else points to it.
3. **Most important first.** Order: purpose, hard constraints, the steps, details. Put the stop conditions where they apply, not at the end.
4. **Say what to do.** Write "run `git status` before editing", not "do not forget to check the state". Keep a prohibition only when it needs a reason, and give the reason.
5. **Checkable completion.** Every task or step ends with a criterion an outside reader can verify: a command with its expected result, a file that exists, a test that passes. "Works well" is not a criterion.
6. **Concrete over general.** Exact paths, commands and formats beat adjectives. One short example beats a paragraph of description.
7. **Strike no-ops.** Delete lines the agent would do anyway (`write clean code`, `be careful`), filler, repeated headings, and rules for cases that cannot occur.
8. **Right size for the audience.** The agent knows the language and tools. Write down only what it cannot infer: project conventions, decisions, traps.

## Review before saving

- Can each rule be followed or violated observably? If not, sharpen or delete it.
- Does any line duplicate another file? Replace it with a pointer.
- Would removing the line change the agent's behavior? If not, remove it.
- Do the stop conditions and the done-criteria sit where the agent needs them?
