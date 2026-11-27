# Report format

File: `.agent/retro/<YYYY-MM-DD>-<slug>.md`

```markdown
# Retro: <slug>
Date: <YYYY-MM-DD> · Scope: <milestone | plan | date range | topic> · Range: <n commits>
Sources: <notes.md | plan log | reviews | session logs (filtered) - only those used>

<one summary line: n high, n medium, n low>

## High
1. [<category>] `<target path>` – <change in one or two sentences>.
   Evidence: <file:line | log date and pattern | review path>

## Medium
...

## Low
...
```

Rules:
- Categories: navigation, automatic checks, standards, CLAUDE.md size, tool economy, no-ops, information access.
- A severity without suggestions is omitted. No suggestion at all → "No findings."
- Mark suggestions that need the user's decision with `(decision)` after the category.
- Do not quote session logs beyond the one matching line needed as evidence; never include secrets or customer data.
