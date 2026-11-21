---
name: explain-project
description: Explains a whole software project to someone who is new to it - purpose, tech stack, folder structure, architecture, data flow, how to run, test and debug it, and where to start reading. Use when the user runs /explain-project or says "explain this project", "I'm new here", "onboarding", "how is this structured", "where do I start", "erklär mir das Projekt" or opens an unfamiliar codebase.
---

# Explain a project (onboarding)

Goal: after reading, the user knows what the project does, how it is built, how to run it locally and where to start.
**Read only.** Do not change files, install, build or run migrations. Read-only commands (`git log`, `ls`, `rg`, reading files) are fine. Respond in the user's language.

In Claude Code this skill runs in a separate read-only subagent so the exploration does not fill the main session. **Your final message is the complete explanation the user will read** – write it out in full, not a summary of what you did.

If the user names an area (e.g. "backend", "frontend only", a folder), focus on it and place it within the whole project.

## 1. Explore systematically (do not guess)

1. **Docs:** `README*`, `CONTRIBUTING*`, `docs/`, `CLAUDE.md`, `AGENTS.md`, ADRs.
2. **Manifests and configuration:**
   - Angular/Node: `package.json`, `angular.json`, `tsconfig*.json`, `src/main.ts`, `app.config.ts`, `app.routes.ts`
   - Django/Python: `pyproject.toml`, `requirements*.txt`, `manage.py`, `*/settings*.py`, `urls.py`, `asgi.py`/`wsgi.py`
   - .NET: `*.sln`/`*.slnx`, `*.csproj`, `Directory.Build.props`, `Program.cs`, `appsettings.json`
   - Operations: `Dockerfile`, `docker-compose*.yml`, `.github/workflows/`, `.gitlab-ci.yml`, `.zed/tasks.json`, `Makefile`
3. **Structure:** `git ls-files` (filtered/truncated for large repos) or the folders 2–3 levels deep. Find the entry points.
4. **History:** `git log --oneline -15` – what is being worked on right now?
5. **Tests:** where they live, which framework, how they are run.
6. **Trace one typical flow:** follow one central use case from its entry (route, endpoint, command) to the database or output.

For monorepos with several applications: briefly show all parts first, then ask which one to go deeper into.

## 2. Structure of the explanation

Skip sections that do not apply.

1. **What is it?** – 2–3 sentences: purpose, who uses it, main features.
2. **Tech stack** – table: *technology | used here for | what it is (one sentence for newcomers)*.
3. **Map** – folder tree (2–3 levels) with a comment for each important folder. Also say what can safely be ignored (generated files, build output, vendor code, old migrations).
4. **Architecture** – a diagram (ASCII or Mermaid) of the main parts and how they talk to each other (e.g. Angular frontend ↔ REST API ↔ database ↔ external services), followed by 3–5 sentences.
5. **One walk-through** – the typical use case from step 1.6, station by station with `file:line`.
6. **Patterns and conventions** – the project's typical patterns (e.g. services with signals, repository pattern, DRF viewsets, middleware, CQRS/MediatR, feature folders), each briefly: what, where, why.
7. **Working locally** – setup, run, test, debug, lint, each with the exact commands from the project. Do not invent anything: mark unclear points as "unclear – ask the team". If `.zed/tasks.json` or `.zed/debug.json` exist, mention the task and debug configuration names.
8. **Glossary** – domain terms and abbreviations used in the code, one sentence each.
9. **Where to start reading** – 5–7 files in a sensible reading order, one sentence each on why.
10. **Getting started** – 3 small practice tasks of increasing difficulty that fit this project (e.g. "add field X to the form and pass it through to the API"). They make good input for `/plan-commits`.
11. **Observations and open questions** – technical debt, missing tests, outdated dependencies, unclear points and concrete questions to ask the team.

## 3. Style

- Short sentences, from the big picture to the details.
- Explain each technical term briefly the first time it appears.
- Real names, paths and commands from the project instead of generic statements.
- Stay honest: anything you did not verify is labelled as an assumption.

## 4. Finish

Offer in one line: go deeper into one area (the `explain` skill fits) or save the explanation as `docs/ONBOARDING.md`. Only write the file if the user agrees.
