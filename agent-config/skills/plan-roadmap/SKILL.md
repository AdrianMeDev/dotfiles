---
name: plan-roadmap
description: Plans something big - a large feature, an epic or a complete new app - as a roadmap of milestones in .agent/ROADMAP.md (vision, scope, architecture, decisions, risks, ordered milestones), without writing code. Use when the user runs /plan-roadmap or wants to plan a whole app, a large feature or a multi-week piece of work. Each milestone is later broken into commits with `plan-commits` and built with `next`.
---

# Plan big work as a roadmap of milestones

**This skill only plans. Do not write code, do not scaffold projects, do not install anything. The only file you write is the roadmap.**
Respond in the user's language.

Three planning levels work together:
```
/plan-roadmap   .agent/ROADMAP.md   big picture → milestones        (this skill)
/plan-commits   .agent/plan.md      next milestone → commit steps
/next           code + commit       one step = one commit
```

## 1. Understand the goal

**Roadmap already exists?** Then update it instead of starting over: show the milestone status, ask what should change (new milestones, new order, revised decisions, a milestone to split), keep done milestones untouched, and add a Changelog line.

0. **Prompt file as input?** An argument that is an existing file (typically `.agent/prompts/<slug>.md` from `refine`) is the vision and scope: Goal is the vision, Acceptance criteria the outcomes, Boundaries the non-goals. `Target:` is not `roadmap` → hint and continue only after confirmation. Ask only what the file leaves open.
1. Read what exists: README, `docs/`, `CLAUDE.md`/`AGENTS.md`, manifests, folder structure, `git log --oneline -15`. For an empty repo, note that it is a greenfield project.
2. Clarify the open questions in rounds by following the `grill` skill (numbered questions, each with a recommended answer). The first frontier covers: who uses it and the one thing they must be able to do, what belongs in the MVP, fixed constraints (stack, existing systems, hosting, auth, data protection, deadline), scale and quality expectations.
3. Continue until the frontier is empty. If the user says "decide yourself", take the recommended answers and list them as decisions. Resolved terms go to `.agent/GLOSSARY.md`; decisions that are hard to reverse, surprising and a real trade-off get an ADR in `.agent/adr/` (see `grill`).

## 2. Design

- **Architecture:** stack, main components and how they talk (small diagram), core data model (entities and relations, no full schema), integrations. For a feature in an existing app: which areas it touches and how it fits the existing patterns.
- **Decisions:** the few choices that are expensive to change later, each with the reason and one alternative; link the ADR in `.agent/adr/` where one exists.
- **Risks and unknowns:** what could break the plan; plan a short spike milestone for anything that is genuinely unknown.

## 3. Cut milestones

Rules for every milestone:
- **One milestone ≈ one `/plan-commits` run ≈ 3–8 commits.** Bigger → split it.
- **Vertical slices:** each milestone delivers something usable or demoable end to end (e.g. data → API → UI for one use case), not a horizontal layer like "all models" or "all screens".
- **Order by dependency, then risk, then value:** riskiest unknowns early, the core use case before nice-to-haves.
- **Greenfield app:** start with **M0 – walking skeleton**: project scaffold, lint, format, tests, a trivial end-to-end path (e.g. one page that calls one endpoint), CI, and dev tooling (Zed tasks/debug configs if used). Nothing else.
- **Large feature in an existing app:** consider a feature flag or a non-wired first slice, and data migrations as their own early milestone.
- Each milestone has a checkable **Done when** that a person can demo or test.
- Plan milestones only to the level the next `/plan-commits` needs. Detailed steps belong in `.agent/plan.md`, not here.

## 4. Write the roadmap

Default path: `.agent/ROADMAP.md` (local, excluded from git – exclude helper in the `agent-workspace` skill). If the project already has a roadmap such as `docs/ROADMAP.md`, ask whether to use it instead.
Keep it short – **under ~150 lines** – because it is read again for every milestone. Use exactly this structure:

```markdown
# Roadmap: <name>
Updated: <YYYY-MM-DD>

## Vision
<2–3 sentences: what, for whom, why>

## Scope
- **MVP:** <bullets>
- **Later:** <bullets>
- **Not planned:** <bullets>

## Architecture
- **Stack:** <…>
- **Components:** <diagram or bullets>
- **Core data:** <entities and relations>
- **Integrations:** <…>

## Decisions
| # | Decision | Why | Alternative |
|---|---|---|---|

## Risks & unknowns
| Risk | Impact | Mitigation |
|---|---|---|

## Milestones

### M0 [ ] <name>
- **Goal:** <one sentence>
- **Includes:** <bullets>
- **Done when:** <demoable / testable criteria>
- **Depends on:** <– or M…>
- **Size:** <S/M/L, ~n commits>

### M1 [ ] <name>
...

## Definition of done (every milestone)
- Builds, tests green, lint clean
- <project-specific items, e.g. migrations included, docs updated>

## Changelog
- <YYYY-MM-DD>: roadmap created
```

Status markers: `[ ]` open · `[~]` in progress (has an `.agent/plan.md`) · `[x]` done · `[-]` dropped.

## 5. Present and stop

Show: vision in one sentence, the milestone list (one line each: id, name, size, done-when), key decisions and the top risks.

Then ask whether to change anything. (The roadmap is local; if the user wants it in the repository, they can move it to `docs/` and commit it themselves.)

End with: **"When the roadmap fits, run `/plan-commits` – it takes the next open milestone automatically."**

**Stop here.** If the user asks for changes, update the roadmap, add a line to its Changelog, and show the milestone list again.
