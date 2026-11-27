---
name: retro
description: Retrospective on a finished milestone or session - finds concrete, prioritized improvements to skills, checks and control files (CLAUDE.md, AGENTS.md) from notes, plan log, reviews and filtered session logs, and saves one report with a target path per suggestion to .agent/retro/. Changes nothing else. Use when the user runs /retro or asks what to improve in the agent workflow after a milestone or session.
---

# Retro: improve the workflow from evidence

Respond in the user's language. Conventions: see the `agent-workspace` skill. **Change no skill, config or code, run no git write commands.** The only file you write is the report under `.agent/retro/`.

First load the `writing-for-agents` skill; every suggested text change must follow it.

## 1. Scope

Argument: a milestone, a plan, a date range or a topic (optional). Default: the current `.agent/plan.md` (its range and Log). Name the scope in the first line of the report.

## 2. Sources, in this order (stop when the evidence is enough)

1. `.agent/notes.md` – open points, surprises, decisions.
2. The Log of `.agent/plan.md` and `git log --oneline <base>..HEAD`.
3. `.agent/reviews/` – recurring review findings.
4. Session logs `~/.claude/projects/<project>/*.jsonl` (Claude Code only; pi: skip) – **never read whole**. Filter with `rg`, within the scope's dates: errors, rejected or denied tool calls, repeated identical calls, tool results over ~20k characters. Read only the matching lines.

A finding needs evidence from at least one source. No evidence, no suggestion.

## 3. Look through seven categories

- **Navigation:** the agent searched long for files, commands or conventions.
- **Automatic checks:** a mistake a hook, linter, test or `scripts/check.sh` rule could have caught.
- **Standards:** the same review finding or correction came back; the rule is missing or unclear.
- **CLAUDE.md size:** always-loaded files with long, stale or duplicated passages.
- **Tool economy:** huge outputs, whole-file reads, repeated reads, missing filters.
- **No-ops:** instructions that were ignored without harm or repeat the default behavior.
- **Information access:** the agent lacked a fact (decision, term, path) that exists somewhere.

## 4. Report

Write `.agent/retro/<YYYY-MM-DD>-<slug>.md` in the format of `REPORT-FORMAT.md` (slug from the scope; add a suffix if the file exists). Make sure `.agent/` is excluded from git (snippet in `agent-workspace`).
- Sort by severity (high, medium, low). At most 10 suggestions; merge related ones.
- Each suggestion: category, target path (`agent-config/...` for the shared setup, else the project file), the concrete change as one or two sentences, and the evidence (`file:line`, log date or review path).
- Suggestions the user must decide (removing a rule, a new dependency) are marked "decision".

Show the user the same compactly: counts per severity, the high items, the report path. Offer `/refine` or `/plan-commits` for implementing the accepted ones.
