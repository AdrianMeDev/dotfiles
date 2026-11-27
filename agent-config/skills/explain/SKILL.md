---
name: explain
description: Explains freshly implemented or existing code simply and thoroughly so the user really understands it and can change it on their own - the latest changes, a plan step, a commit, a file, a function or a feature. Use when the user runs /explain or asks "explain this", "what did you do", "how does this work", "erklär mir das" or "ich verstehe das nicht".
---

# Explain implemented code so it is really understood

Goal: afterwards the user can explain the code in their own words, change it safely and debug it.
**Explain only – do not change code, do not commit.** Respond in the user's language.

## 1. Pick the subject

Use the first source that applies:
1. Whatever the user passes as argument (file, folder, function, commit, branch, plan step number, feature name).
2. What was implemented most recently in this session, or the last `[~]`/`[x]` step in `.agent/plan.md` (legacy: `.agent-plan.md`).
3. Local changes: `git status` and `git diff HEAD`.
4. Otherwise the last commit: `git show --stat HEAD`, then `git show HEAD`.

If the subject is large (more than ~5 files or several features): give an overview first, split it into parts and ask whether to go through them one by one.

## 2. Understand before explaining

- Read the affected files completely, plus direct callers and callees.
- Read related tests – they show the intended behaviour.
- Do not guess: anything you have not confirmed in the code is labelled as an assumption.

## 3. Structure of the explanation

Keep this order. Skip sections that do not apply instead of filling them.

1. **In one sentence** – what can the software do now that it could not before (or: what is this code for)?
2. **A picture** – an everyday analogy, only if it genuinely fits.
3. **The flow** – step by step what happens when the feature is used, from the trigger (click, HTTP request, command, timer) to the result. Every step with `file:line`. With more than three stations, add a small diagram (ASCII or Mermaid), e.g.:
   ```
   Button (cart.component.html:12) → CartService.add() (cart.service.ts:40) → POST /api/cart → CartViewSet.create (views.py:88) → DB
   ```
4. **The key places in the code** – at most 3–5 short excerpts (≤ 15 lines each), each explained in plain language: what the lines do and why.
5. **Concepts you need to know** – every language or framework concept that actually appears, in 2–3 sentences: what is it, which problem does it solve, how is it used here. Examples: Angular signals, RxJS observables, dependency injection, Django ORM/QuerySets, middleware, migrations, serializers, C# `async`/`await`, LINQ, Entity Framework, the ASP.NET request pipeline.
6. **Why this way?** – the 1–3 most important design decisions, each with one realistic alternative and the trade-off.
7. **Pitfalls** – edge cases, what breaks easily, what to watch out for when changing it, known weaknesses or technical debt (name them honestly).
8. **Try it yourself** – 1–3 concrete steps to see it live: a command, a URL, a test, or "set a breakpoint at `file:line` and inspect variable X".
9. **Check your understanding** – 3 short questions that test real understanding, not recall (e.g. "What happens if …?"). Put the answers at the very end under the heading **Answers**, with a note to think first.

## 4. Style

- Short sentences, from the big picture to the details.
- Explain each technical term in half a sentence the first time it appears, then use it normally.
- Concrete instead of abstract: real names, real paths, real values from the code.
- No filler, no praise for the code.

## 5. Adjust the level

- Default: the user can program but is new to this technology or codebase.
- "simpler" / "einfacher" / "for beginners": more analogies, smaller steps, every concept explained in more depth.
- "short" / "kurz": only sections 1, 3 and 7.
- "deeper" / "tiefer" or a specific part: that part with all sections in detail.

## 6. Finish

Offer in one line: go deeper into one part, or save the explanation as `docs/explanations/<topic>.md`. Only write the file if the user agrees.
