---
name: inspect
description: Reviews the changes since a fixpoint on two separate axes - project standards and the spec (plan step, milestone or refined prompt) - each in its own fresh subagent, and saves one report to .agent/reviews/. Changes no code. Use when the user runs /inspect or asks to review the changes, a branch or a finished plan against standards and spec.
---

# Inspect: review on two axes

Respond in the user's language. Conventions: see the `agent-workspace` skill. You only orchestrate and write the report. **Change no code, run no git write commands**; the only file you write is the report under `.agent/reviews/`.

## 1. Fixpoint and diff

Arguments: `[base] [prompt path]` (both optional; a path under `.agent/prompts/` is the prompt, anything else is the base).
- Base given (ref or hash) → `git merge-base <base> HEAD`.
- Else the `Base:` hash in `.agent/plan.md`, else `main`.
- Diff command: `git diff <fixpoint>` (includes uncommitted changes) plus `git log --oneline <fixpoint>..HEAD`. Uncommitted changes present → name them as such in the report.
- Empty diff → say so and stop.

## 2. Gather the sources (paths only, do not paste them)

- **Standards:** see `STANDARDS.md`.
- **Spec**, first match wins:
  1. the prompt path from the arguments,
  2. the steps of `.agent/plan.md` within the range, plus their milestone,
  3. the roadmap milestone (`.agent/ROADMAP.md`, else `docs/ROADMAP.md`).
  Nothing found → the Spec section says "no spec found"; do not guess one.

## 3. Run the two axes

Each axis gets **only** its own sources, the fixpoint and the diff command, never the other axis' sources or result. Task for each: read the diff, check it against its sources, report findings as `file:line`, severity (critical / important / minor), the problem and a concrete suggestion. No finding → say so. No speculation: only what the diff and the sources show.

- **Claude Code:** start two subagents with the Agent tool (`general-purpose`, model sonnet) in **one message**, so they run in parallel and fresh.
- **pi (no subagents):** run the axes one after another; before the second axis, read the diff and its own sources again and do not carry over the first axis' findings.
- Standards axis: violations of the standards sources and the code smells in `STANDARDS.md`.
- Spec axis: what the spec demands but the diff lacks (missing, partial), what the diff does beyond the spec (scope creep), and whether the "Done when" / acceptance criteria are met.

## 4. Report

Write `.agent/reviews/<YYYY-MM-DD>-<slug>.md` in the format of `REPORT-FORMAT.md` (slug from the branch or plan title; add a suffix if the file exists). Make sure `.agent/` is excluded from git (snippet in `agent-workspace`).
- Write both sections **verbatim**, in separate sections "Standards" and "Spec". No merged verdict; only one summary line per axis.
- Show the user the same compactly: counts per severity per axis, the critical and important findings, the report path.

## 5. Stop

Offer follow-ups, do not start them: small corrections via `/fix`, larger ones via `/plan-commits`. **Never run `git commit` or `git push`.**
