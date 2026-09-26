# let-there-be-light workflow

From cold repo to deployed service. Two invariants: (1) delegate the prose, never the judgment. (2) A model refusal is a routing problem, not a stop.

## 1. One-time install

1. Clone the PAL MCP server (fork of zen-mcp-server): https://github.com/BeehiveInnovations/zen-mcp-server. Register it in `~/.claude.json` under `mcpServers.pal`.
2. Clone this repo.
3. Run `./setup.sh`. The wizard walks you through:
   - **Scope.** Global (`~/.claude/settings.json`) or per-project (`./.claude/settings.json`). Per-project is the default; keeps the framework from attaching to unrelated work.
   - **Auto-load skills.** Which skills fire at every session start (`architect`, `test-strategist`, `ship-checklist` are on by default; `incident-response` and `retrospective` are off unless you opt in).
   - **PAL models.** Pick which models you have keys for. Unselected models are dropped from the rendered hook so Claude never routes to them.
4. Fill in your API keys in the generated `.env.lttbl.example` and source it from your shell rc.
5. Symlink skills into the discoverable path (the wizard offers to do this automatically).
6. Restart Claude Code.

## 2. Every session boot (automatic, ~2s)

`SessionStart` hook injects the mandatory-first-actions block. Claude's first tool calls are the enabled skills. One short readout, then Claude is ready.

## 3. The dev loop (per message)

`UserPromptSubmit` hook re-asserts the delegate-first + failover policy every message. Claude picks tools and delegates the busy work per the routing map.

### Concrete example

```
you> "design the auth service refactor"
```

1. Claude invokes `architect` (decision stays).
2. Reads the existing auth service files via `nemotron` (1M ctx).
3. Debates the top 3 approaches with `pro` (Gemini 3 Pro).
4. Drafts the ADR prose with `groq`.
5. Presents ADR + trade-off matrix + explicit unknowns. You approve or push back.

## 4. The 4-phase lifecycle

Each phase has its own skill and its own delegation pattern.

### Phase 1. Design
`architect` runs. Produces a system diagram, an ADR, a trade-off matrix, and an explicit list of unknowns. Debate happens with `pro`. Final recommendation stays in Claude.

### Phase 2. Implementation
`clean-code` runs alongside coding to keep names, structure, and comments human-readable (one-job functions, WHY-not-WHAT comments, three-levels-deep-max nesting, types at the seams). `test-strategist` runs in parallel: test-pyramid split, coverage targets for the changed lines, fixture strategy, and an explicit list of what is not tested. When the PR opens, `debate-review` runs a two-model debate and posts a single review from your `gh` / `glab` / `az` account. `babysit-pr` then works the rounds until merge-ready.

### Phase 3. Staging
`ship-checklist` runs before promotion. Produces an ordered pre-deploy checklist, a rollback plan with expected time and blast radius, and a 5-10 step smoke test. Rollback plan is non-negotiable.

### Phase 4. Production
`incident-response` runs on every alert. Produces blast radius, runbook link, ordered triage steps, and draft status updates. `retrospective` runs after anything customer-visible: builds the timeline in UTC, drafts the blameless narrative, categorizes contributing factors, and produces at most 5 action items with owners and deadlines.

## 4.5 The 4-step fix-validation pipeline (per code fix)

Runs on every bug fix, hotfix, or refactor that claims to fix an issue. Mirrors the sauron `validator` pattern but for software fixes.

**A. Stress-test.** `Skill(fix-validator)` produces twelve fields: Root Cause Confidence, Regression Risk, Blast Radius, Test Coverage, Missing Tests, Rollback Complexity, Side Effects, Security Impact, Performance Impact, Backwards Compatibility, Deployment Risk, Final Verdict.

**B. Gap tests.** Run every missing test, negative control, and edge case the validator flagged. Use your dev tools: test suite, linter, type checker, coverage tool, mutation testing, contract tests.

**C. Adversarial code review.** `mcp__pal__challenge` with `pro` primary, `groq` fallback. Attacks the fix on correctness under edge cases, right-layer-to-fix, test completeness, rollback plan, backwards compat, and 10x-traffic behavior.

**D. Synthesize and write.** Combine validator output + gap-closing tests + debate transcript into the final assessment. Groq drafts the PR description; you byte-check file paths, function signatures, migration steps against the raw diff before merging or shipping.

Rule: A fix without a test that would have caught the original bug is a bet, not a fix.

## 5. Quick reference: what fires when

| Event | What runs | Where it lives |
|---|---|---|
| session start | enabled skills auto-invoke | SessionStart hook |
| every prompt | delegate-first + failover re-asserted | UserPromptSubmit hook |
| any bulk read/write | routed to a PAL model per task type | pal-router skill |
| any design | ADR + trade-off matrix + unknowns | architect skill |
| any code change | readability rules + test plan + PR debate + babysit | clean-code, test-strategist, debate-review, babysit-pr |
| any release | pre-deploy checklist + rollback + smoke | ship-checklist skill |
| any code fix before merge | 4-step fix-validation pipeline | fix-validator skill |
| any incident | triage + blast radius + status update | incident-response skill |
| any post-mortem | timeline + narrative + action items | retrospective skill |

## The two invariants

> Delegate the prose, never the judgment.

> A model refusal is a routing problem, not a stop.
