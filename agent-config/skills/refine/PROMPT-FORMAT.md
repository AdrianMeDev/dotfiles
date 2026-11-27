# Prompt file format

File: `.agent/prompts/<slug>.md`, slug = kebab-case title. Keep it short: a planner or `/fix` should need nothing else.

```
# <Title>
Target: roadmap | commits | fix
Created: <YYYY-MM-DD>

## Goal
<1-3 sentences: what is different afterwards, and for whom>

## Context
- <ticket text, key facts, constraints>
- Paths: `<file or folder>` - <why it matters>

## Acceptance criteria
- [ ] <observable, testable statement>

## Boundaries
- Out of scope: <what must not change or be done>
- Open: <unresolved question, if any>

## Glossary terms
- <term> - <meaning, from .agent/GLOSSARY.md>
```

## Per target

- `roadmap`: Goal is the vision; Acceptance criteria are the outcomes the whole roadmap must deliver; Boundaries state scope limits and non-goals.
- `commits`: Acceptance criteria become the plan's Done when; Boundaries become out of scope; Context lists the code the steps will touch.
- `fix`: Goal is the correct behavior. Context has the **Reproduction** (steps, input, actual vs expected result, error text) and the suspected location. Acceptance criteria: the failing case now passes, nothing else changes. If it cannot be done in one commit, say so under Open.
