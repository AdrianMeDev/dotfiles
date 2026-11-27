# GLOSSARY.md format

File: `.agent/GLOSSARY.md` (single context, created when the first term is resolved).

```md
# {Project name}

{One or two sentences: what this context is and why it exists.}

## Language

**Order**:
A request by a **Customer** to buy goods.
_Avoid_: Purchase, transaction

**Customer**:
A person or organization that places an **Order**.
_Avoid_: Client, buyer, account
```

## Rules

- Be opinionated: pick one word per concept, list the others under `_Avoid_`.
- One or two sentences per definition: what it IS, not what it does.
- Bold other glossary terms inside a definition.
- Only terms specific to this project, not general programming concepts.
- Group under subheadings when clusters emerge.
- No implementation details, specs or scratch notes.
