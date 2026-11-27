# ADR format

Files: `.agent/adr/NNNN-<slug>.md`, numbered sequentially (`0001-...`). Scan the folder for the highest number and add one. Create the folder lazily.

```md
# {Short title of the decision}

{1-3 sentences: context, what was decided, and why.}
```

An ADR can be one paragraph. Optional, only when they add value: a **Status** line (`proposed | accepted | deprecated | superseded by ADR-NNNN`), **Considered options** (rejected alternatives worth remembering), **Consequences** (non-obvious effects).

## When to write one

All three must be true: hard to reverse, surprising without context, a real trade-off. Typical: architectural shape, integration patterns, technology with lock-in, boundary decisions, deliberate deviations from the obvious path, constraints not visible in code, non-obviously rejected alternatives.
