---
name: flow
description: Recommends which workflow skill or command chain fits the user's concern (e.g. "small bug in the login" -> /refine fix -> /fix). Recommends only - runs nothing, writes no file. Use when the user runs /flow or asks which command or skill fits, where to start, or how the agent workflow goes.
---

# Flow: pick the right command

Respond in the user's language. **Recommend only:** run no other skill, write no file, change no code. Read only `.agent/plan.md` (if it exists) - no code, no other files.

## 1. Input

Argument: the concern as free text. Empty: print the table in section 3 as a short overview and ask what the user wants to do.

## 2. Check for an open step

If `.agent/plan.md` has a step marked `[~]` (implemented, waiting for the commit): say so first. The user commits it, then continues with `/next`, before any new work starts (rule in the `agent-workspace` skill).

## 3. Decide

Take the first row that fits the concern:

| Concern | Recommend |
|---|---|
| Idea, terms or decision unclear | `/grill` |
| Whole app, large feature, weeks of work | `/plan-roadmap` -> `/plan-commits` -> `/next` per step |
| Feature or task with several commits | `/plan-commits` -> `/next` per step |
| Rough request or ticket text to sharpen first | `/refine <roadmap\|commits\|fix>` -> the matching planner or `/fix` |
| Small, clear bug or correction | `/refine fix` -> `/fix` (task already precise: `/fix` directly) |
| Hard or unclear bug, cause unknown | `/diagnose` -> `/fix` |
| Review code, a diff or a milestone | `/inspect` |
| Improve skills, checks or control files after a milestone | `/retro` |
| Understand a change, plan step or file | `/explain` |
| Understand a whole project | `/explain-project` |
| Which command fits | `/flow` |

Several rows fit: pick the one that matches the size of the concern, name the next-larger one as the alternative.

## 4. Output

At most 6 lines, in this order:

1. **Recommendation:** the chain, e.g. `/refine fix "small bug in the login"` -> `/fix`.
2. **Why:** one sentence.
3. **Alternative:** only if a second option is realistic.
4. **Open step:** only if section 2 applies.

Example: "small bug in the login" -> `/refine fix` -> `/fix`; why: small, local, one failing test is enough.
