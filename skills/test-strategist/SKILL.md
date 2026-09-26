---
name: test-strategist
description: >-
  Implementation-phase skill: designs the test pyramid, coverage plan, and fixture strategy for a
  change. Triggers on: 'what tests do I need', 'test this', 'how do I test X', 'CI is flaky', a bug
  that should have been caught, before writing tests for a new feature.
---

# test-strategist

**One-line pitch:** Implementation-phase skill: designs the test pyramid, coverage plan, and fixture strategy so the codebase stays honest.

## When to invoke
- Before writing tests for a new feature.
- When a bug ships that should have been caught (write the missing test first, then fix).
- When flake shows up in CI.
- Trigger phrases: "what tests do I need", "test this", "how do I test X", "CI is flaky".

## What I produce
- Test pyramid split for this change (unit / integration / e2e counts + rationale).
- Coverage targets for the changed lines specifically, not the whole repo.
- Fixture design (real DB vs fake, network stubs vs contract tests).
- Explicit list of what is NOT tested and why (edge cases parked, third-party unmocked, etc).

## Delegation
- Bulk reading of existing test files: `nemotron`.
- Test-file scaffolding / boilerplate: `groq` or `gpt-5.1-codex`.
- Property-based test generation: `pro`.
- Final decision on what to ship: stays in Claude.

## Anti-patterns
- Never write an e2e test for something a unit test would catch.
- Never mock a boundary you own (test the real thing).
- Never mock a boundary you do not own without a contract test.
- Never chase coverage as the goal; chase confidence.

## The rule
> Coverage is a symptom, not a goal.
