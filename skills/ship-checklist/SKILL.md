---
name: ship-checklist
description: >-
  Staging-phase skill: runs the pre-deploy checklist, builds the rollback plan, and defines smoke
  tests before promotion to production. Triggers on: 'ready to ship', 'check the deploy', 'rollback
  plan', 'smoke test', any promotion, any schema migration, turning a feature flag on.
---

# ship-checklist

**One-line pitch:** Staging-phase skill: runs the pre-deploy checklist, builds the rollback plan, and defines the smoke tests before you promote to production.

## When to invoke
- Before any promotion from staging to production.
- Before any release that includes a schema migration.
- Before turning a feature flag on for real traffic.
- Trigger phrases: "ready to ship", "check the deploy", "rollback plan", "smoke test".

## What I produce
- Ordered checklist for this specific release: schema migration, feature flags, dependency bumps, secrets rotation, observability signals.
- Rollback plan: exact steps, expected time, blast radius, data-loss risk.
- Smoke-test list: the 5-10 operations that must succeed within 60 seconds of promotion.
- Explicit list of what could go wrong and the monitoring signal that would catch it.

## Delegation
- Reading migration files and diffs: `nemotron`.
- Drafting rollback runbook prose: `groq`.
- Building the smoke-test script: `gpt-5.1-codex` (or `groq` fallback).
- Final go/no-go decision: stays with Claude, then you.

## Anti-patterns
- Never ship without a rollback plan.
- Never ship a schema migration and a code change in the same commit.
- Never let the smoke test be "the site loads".
- Never trust green CI over the smoke test.

## The rule
> A release without a rollback plan is a bet, not a plan.
