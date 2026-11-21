---
description: Code review of the current changes (or a path / focus)
argument-hint: "[path or focus]"
---
Do a code review. Subject or focus: "$ARGUMENTS" – if empty, the current changes from `git diff HEAD`.

Check in this order and give `file:line`, severity (critical / important / minor) and a concrete suggestion for every finding:
1. Correctness and edge cases
2. Security (input handling, auth, secrets, injection)
3. Error handling
4. Readability and naming
5. Missing or weak tests

Do not change code. Finish with a one-sentence overall verdict. Respond in the user's language.
