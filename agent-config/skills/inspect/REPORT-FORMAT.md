# Report format

File: `.agent/reviews/<YYYY-MM-DD>-<slug>.md`

```markdown
# Inspect: <slug>
Date: <YYYY-MM-DD> · Fixpoint: <hash> (<base given or source>) · Range: <n commits[, + uncommitted changes]>
Sources: standards: <files used> · spec: <prompt path | plan steps + milestone | roadmap milestone | none found>

## Standards
<one summary line: n critical, n important, n minor>

- [critical|important|minor] `file:line` – problem. Suggestion: ...

## Spec
<one summary line, or "no spec found">

- [critical|important|minor] `file:line` – problem (missing | partial | beyond spec | criterion not met). Suggestion: ...
```

Rules:
- The two sections are the subagents' results, verbatim; do not merge, reorder or rate across axes.
- No finding in an axis → "No findings."
- Findings without a `file:line` (e.g. a missing file) name the expected path instead.
