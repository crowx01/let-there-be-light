---
name: fix-validator
description: >-
  Runs the 4-step fix-validation pipeline before any code fix merges or ships to
  production. Stress-tests the fix for regression risk, test coverage, rollback
  complexity, and blast radius. Triggers on: 'validate this fix', 'before I merge',
  'is this fix complete', 'review my patch', 'ready to ship this bug fix', 'does
  this actually fix it'.
---

# fix-validator

**One-line pitch:** Runs the 4-step fix-validation pipeline before any code fix merges or ships. Mirrors the sauron `validator` skill but for software fixes rather than vulnerability findings.

## When to invoke
- Any bug fix PR before merge
- Any hotfix before deployment to production
- Any refactor that claims to fix a systemic issue
- Any performance patch
- Trigger phrases:
  - `validate this fix`
  - `before I merge`
  - `is this fix complete`
  - `review my patch`
  - `ready to ship this bug fix`
  - `does this actually fix it`

## The 4-step pipeline

### Step A. Fix stress-test
Invoke this skill against the proposed fix. Produce twelve fields:

- **Root Cause Confidence (0-100):** does the fix address the actual root cause or a symptom?
- **Regression Risk** (Low/Medium/High + what else in the codebase could break)
- **Blast Radius** (services, tenants, features affected)
- **Test Coverage** (does the fix have a test that would have caught the bug, plus edge cases)
- **Missing Tests** (specific negative controls, edge cases, contract tests still needed)
- **Rollback Complexity** (steps + expected time to revert if this breaks prod)
- **Side Effects** (what changes about system behavior beyond the bug being fixed)
- **Security Impact** (any new attack surface, information leak, auth bypass)
- **Performance Impact** (hot-path changes, memory, latency, allocations)
- **Backwards Compatibility** (does this break existing API contracts or clients)
- **Deployment Risk** (schema migration? feature flag? big-bang vs gradual rollout)
- **Final Verdict** (one of: Ship / Ship with monitoring / Hold for more tests / Rework / Reject)

### Step B. Gap tests
Run every missing test, negative control, and edge case the validator flagged. Use your own dev tools: test suite, linter, type checker, coverage tool, mutation testing, contract tests. No shortcuts.

### Step C. Adversarial code review
Route the fix to `mcp__hermes__challenge` with Gemini 3 Pro as primary and Groq as fallback. Frame the debate adversarially:

- Attack the fix's correctness under edge cases.
- Challenge whether this is the right layer to fix (band-aid on symptom vs true root cause).
- Question test coverage completeness.
- Attack the rollback plan.
- Question backwards compatibility and contract stability.
- Ask: what would break if this ships to 10x current traffic?

### Step D. Synthesize + write
Combine validator output + gap-closing test evidence + debate transcript into the final assessment. Delegate the PR description to groq. Human byte-checks technical details (file paths, function signatures, line numbers, migration steps) before merging or deploying.

## Anti-patterns
- Never merge a fix that has no test that would have caught the original bug.
- Never merge a fix without a rollback plan (even a one-liner).
- Never merge a schema migration and a code change in the same PR.
- Never let "looks good to me" pass for anything shipping to production.
- Never skip Step C because the fix seems small; small fixes hide the most subtle regressions.

## Related
- Runs BEFORE `debate-review` (which does the two-model PR debate) as the author's self-check.
- Feeds `ship-checklist` when the fix graduates from PR review to release candidate.
- Adapted from the sauron `validator` skill (same 4-step pattern, different domain).

## The rule
> A fix without a test that would have caught the bug is a bet, not a fix.
