---
name: clean-code
description: >-
  Implementation-phase skill: keeps code human-readable. Triggers on: 'write', 'implement',
  'refactor', 'clean this up', 'review readability', code that ships to a repo, any function
  longer than a screen, any name that needs a comment to explain it, any nested block deeper
  than three levels. Runs alongside test-strategist during implementation.
---

# clean-code

**One-line pitch:** Code should read like prose to the next person, not like a puzzle. Names carry intent, functions do one thing, structure tells the story.

## When to invoke
- Any new function, class, or module about to land in a repo.
- Any refactor that touches naming, structure, or control flow.
- Any code review where the diff is correct but hard to follow.
- Trigger phrases: "write", "implement", "refactor", "clean this up", "review readability".

## What I produce
- Named, small, single-purpose functions (a name a reviewer can grasp in one read).
- Explicit types at boundaries; inferred inside.
- Comments only for WHY (constraints, invariants, workarounds). Never for WHAT.
- Structure that follows the reader's questions: entry point at the top, helpers below.

## The rules (in order of ruthlessness)

1. **Naming carries the load.** A well-named identifier removes the need for a comment. If a name needs a comment, rename. Prefer `daysUntilRenewal` over `d`. Prefer `isEligibleForRefund` over `check`. Verbs for functions, nouns for values, boolean-shaped names for booleans (`is`, `has`, `should`).
2. **One function, one job.** If the summary of what a function does contains "and", split it. If the body doesn't fit on one screen without scrolling, split it.
3. **Nesting is a smell.** Three levels deep is the wall. Guard clauses and early returns beat pyramids. Extract inner blocks into named helpers when they earn a name.
4. **No dead weight.** Delete commented-out code, unused imports, TODOs without a ticket, feature flags for launched features, `_var` renames of things that aren't used. Dead code lies.
5. **Comments explain WHY, never WHAT.** A comment restating the code is noise. A comment explaining a hidden constraint, a subtle invariant, a workaround for a specific bug, or a decision that would surprise a future reader is gold. If removing the comment wouldn't confuse a future reader, delete it.
6. **Types at the seams, inference inside.** Public APIs, function signatures, data-model boundaries get explicit types. Local variables lean on inference. The reader should see the shape of the contract without hunting.
7. **Errors are named, not swallowed.** No bare `catch { }`. No `except: pass`. Every error either handles the case explicitly, wraps with context and rethrows, or bubbles. `throw new Error(str)` with the actual thing that went wrong is minimum viable.
8. **Formatting is not a taste decision.** Follow the project's linter and formatter. If there isn't one, add one before writing more code. Style debates evaporate the moment the tool decides.
9. **No premature abstraction.** Three similar lines beats a badly named helper. Wait for the third occurrence before extracting. Interfaces without two concrete implementations are noise.
10. **Boundaries are the only place for validation.** Trust internal code. Validate at user input, external API responses, deserialization, database reads. Everywhere else, types and invariants do the work.

## Delegation
- Bulk read of the existing file/module context: `nemotron` (1M ctx).
- Suggest 3 alternative names for a hard-to-name concept: `groq`.
- Explain WHY a piece of legacy code is shaped a certain way (from git blame + surrounding files): `nemotron` first, `groq` for the writeup.
- Draft docstring or module-header prose (when explicitly requested): `groq`.
- Final naming decision, structural split, comment-vs-rename call: stays in Claude.

## Anti-patterns (things this skill actively fights)

- **AbstractSingletonProxyFactoryBean naming.** If it takes three words to describe the class and you still don't know what it does, the design is the bug.
- **Comment blocks that echo the code.** `// increment i by 1` above `i++` is worse than no comment.
- **Boolean flag parameters.** `renderUser(user, true, false)` is unreadable. Split into two functions or use a named options object.
- **Utility grab-bags.** A `utils.ts` with 40 exports is where dead code goes to hide.
- **God objects and 400-line functions.** If the file needs a table of contents, it needs a split.
- **Clever one-liners.** Chained ternaries, dense functional pipelines with no intermediate names, regex with no comment on intent. Clever is a debt.
- **Reintroducing legacy comments.** `// added for the X flow, see issue #123`. Belongs in the PR description; rots in the source.
- **Backwards-compat noise.** Renaming an unused `_var`, `// removed - was doing Y`, re-exports of things nothing imports. Delete completely.

## The reader test

Before merging, imagine the reviewer who has never seen this code. Ask three questions:
1. Can they name what each function does after reading its signature?
2. Can they find where to change behavior X in under 30 seconds?
3. Can they explain WHY (not what) the tricky parts are shaped this way?

If any answer is no, the code isn't done.

## The rule

> The next person reading this code is you, six months from now, without context.
> Write for them, not for the compiler.
