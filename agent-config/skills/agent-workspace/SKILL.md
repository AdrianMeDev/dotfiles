---
name: agent-workspace
description: Shared conventions for all agent workflow skills - the local .agent/ layout, the git exclude helper, the notes.md format, legacy path fallbacks, the rule that agents never run git write or tracker commands, and the context budget. Reference only; other skills (plan-roadmap, plan-commits, next, ...) point here.
---

# Agent workspace conventions

Reference for the workflow skills. Do not run it on its own.

## Layout

All agent-generated files live under `.agent/` in the project root and stay local (never committed):

```
.agent/
  plan.md        commit plan (plan-commits), executed by next
  ROADMAP.md     roadmap (plan-roadmap)
  notes.md       findings that must survive /clear
  GLOSSARY.md    domain terms (grill)
  adr/           architecture decision records, NNNN-<slug>.md (grill)
  prompts/       refined prompts, <slug>.md (refine)
  reviews/       review reports, <YYYY-MM-DD>-<slug>.md (inspect)
  retro/         retrospective reports, <YYYY-MM-DD>-<slug>.md (retro)
```

Create files and folders lazily, only when a skill needs them.

## Keep `.agent/` out of git

Before the first write into `.agent/`, make sure it is excluded. Never touch `.gitignore`.

```sh
exclude="$(git rev-parse --git-path info/exclude)"
mkdir -p "$(dirname "$exclude")"
grep -qxF '.agent/' "$exclude" 2>/dev/null || printf '.agent/\n' >> "$exclude"
```

`--git-path` resolves correctly in worktrees. Not a git repository: skip this step.

## Legacy paths (read-only fallback)

New files are always written under `.agent/`. Old locations are only read when the new one is missing:

- plan: `.agent/plan.md`, else `.agent-plan.md`
- roadmap: `.agent/ROADMAP.md`, else `docs/ROADMAP.md`, else `ROADMAP.md`

An existing tracked roadmap (e.g. `docs/ROADMAP.md`) keeps working, including its tracked/local status handling.

## notes.md format

Append one entry per finding, newest last. Keep entries short; link files as `path:line`.

```
## <YYYY-MM-DD> <short title>
- **Where:** step n / file:line
- **Finding:** what was learned, decided or left open
- **Action:** what the user or a later step should do (or "none")
```

## Git and tracker rule

Agents never run git write actions or tracker commands: no `git commit`, `push`, `merge`, `rebase`, no `gh pr|issue create`, `gh pr merge`, no `glab`. Show the exact commands (commit message, PR text) and let the user run them. Read-only git (`status`, `diff`, `log`) is fine.

## Context budget

Stay below ~150k tokens per agent. Persist state in `.agent/plan.md` and `.agent/notes.md` instead of the conversation, read files in parts, filter long command output, and suggest `/clear` between steps. Check usage in the Claude Code statusline (context %, tokens/150k) or the pi footer.
