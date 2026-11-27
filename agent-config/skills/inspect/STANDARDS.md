# Standards axis: sources and smells

## Sources (use what exists)

- `CLAUDE.md` / `AGENTS.md` in the repository, and the user's global instructions
- `.editorconfig`, linter and formatter configs, `scripts/check.sh` or the CI config
- the existing code style around the changed lines (naming, structure, tests)
- `.agent/GLOSSARY.md` (terms used in code and names)
- project rules beat general smells; a smell is only a finding if it is introduced or worsened by the diff

## Code smells (names are common vocabulary, descriptions are our own)

- **Long function** – does several things; needs a comment to explain its sections.
- **Long parameter list** – callers must remember order and meaning.
- **Duplicated code** – the same logic in two places that will drift.
- **Large class / module** – many unrelated responsibilities.
- **Feature envy** – a function mostly works on another module's data.
- **Primitive obsession** – raw strings or numbers where a small type would carry meaning.
- **Shotgun surgery** – one change forces edits in many places.
- **Dead code** – unused branches, parameters, imports, commented-out code.
- **Speculative generality** – hooks and options nobody uses yet.
- **Magic values** – unexplained literals.
- **Unclear naming** – names that hide intent or contradict the glossary.
- **Weak tests** – new logic without tests, or tests that cannot fail.
- **Error handling** – swallowed errors, secrets or sensitive data in messages, unvalidated input.
