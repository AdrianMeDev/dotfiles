---
name: grill
description: Interviews the user about a plan, idea or decision in numbered rounds, each question with a recommended answer, looks up facts itself, and records resolved terms in .agent/GLOSSARY.md and hard-to-reverse decisions in .agent/adr/. Use when the user runs /grill, wants to stress-test an idea, sharpen terminology or record a decision.
---

# Grill: interview, glossary, ADRs

Respond in the user's language. Conventions (`.agent/` layout, exclude helper, git rule): see the `agent-workspace` skill. **Do not write code.** Only write under `.agent/`.

## Rounds

Map the topic as a **design tree**: every decision branches into the decisions that hang off it. The **frontier** is every open decision whose prerequisites are settled. Ask the whole frontier in one round, then wait for the answers.

```
**Q1 - <title>**: <question, multiple choices allowed>
Recommended: <your answer>
```

- Number questions per round (Q1, Q2, ...); every question has a recommended answer.
- Word each question so "yes" accepts the recommendation.
- A question that depends on another open one in the same round belongs to a later round.
- Answers reshape the tree: recompute the frontier, ask the next round.

## Facts are your job

Never ask the user for something you can look up (files, tools, versions, code behavior). Claude Code: dispatch an Explore subagent and keep asking the rest of the frontier meanwhile. pi (no subagents): look it up inline before the round. Decisions stay with the user.

## Glossary

Read `.agent/GLOSSARY.md` first if it exists.
- Term conflicts with the glossary: call it out immediately.
- Vague or overloaded term: propose one canonical term.
- Test relationships with concrete edge-case scenarios; if the code disagrees with the user, surface it.
- Write each resolved term to `.agent/GLOSSARY.md` right away, not in a batch. Format: `GLOSSARY-FORMAT.md` (read it before the first write).
- No implementation details in the glossary.

## ADRs

Offer an ADR only if all three hold: hard to reverse, surprising without context, a real trade-off with alternatives. Otherwise skip. Write to `.agent/adr/NNNN-<slug>.md` after the user agrees; format: `ADR-FORMAT.md`.

## Done

The frontier is empty and nothing is silently assumed. Summarize decisions, new terms and ADRs in a few lines, ask the user to confirm the shared understanding, and only then suggest the next step (`/plan-roadmap` or `/plan-commits`). Create `.agent/` files lazily after running the exclude helper from `agent-workspace`.
