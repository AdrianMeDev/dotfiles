---
description: Suggest a commit message for the staged changes
---
Read `git diff --cached` (if empty: `git diff`). If `.agent/plan.md` (legacy: `.agent-plan.md`) has a step marked `[~]`, start from its planned message.

Suggest a commit message in Conventional Commits format (`type(scope): description`, English, imperative, max. 72 characters, optionally 2–4 bullet points below).

Do NOT run `git commit` yourself – only show the message and the command.
