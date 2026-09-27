# let-there-be-light

**From design to production. Let there be light.**

> "And God said, Let there be light: and there was light." Genesis 1:3

## What it is

It is a framework of skills that turns your AI orchestrator into a senior engineer covering design, implementation, staging, and production. It installs into Claude Code, Cursor, Cline, Codex CLI, Aider, or generates a portable `SYSTEM_PROMPT.md` when the orchestrator is not one of the five. The wizard walks you through picking the orchestrator, the install scope, the skills, and the Hermes models. The higher-tier model makes the architectural decisions while cheaper models handle the busy work.

## The days of creation (skills)

| Skill | Job | Source |
|-------|-----|--------|
| [architect](skills/architect/SKILL.md) | Design phase: system design, ADRs, tech-stack choices. | mine |
| [test-strategist](skills/test-strategist/SKILL.md) | Implementation: test pyramid, coverage plan, fixture strategy. | mine |
| [fix-validator](skills/fix-validator/SKILL.md) | Runs the 4-step fix-validation pipeline before any code fix merges or ships. | mine |
| [ship-checklist](skills/ship-checklist/SKILL.md) | Staging: pre-deploy checklist, rollback plan, smoke tests. | mine |
| [incident-response](skills/incident-response/SKILL.md) | Production: alert triage, blast radius, status update. | mine |
| [retrospective](skills/retrospective/SKILL.md) | Post-incident: timeline, blameless post-mortem, action items. | mine |
| [pal-router](skills/pal-router/SKILL.md) | Delegate-first + failover routing doctrine. | mine |
| [debate-review](skills/debate-review/SKILL.md) | Two-model PR debate, posts one review from your gh/glab/az. | adapted from [amElnagdy/review-skills](https://github.com/amElnagdy/review-skills) (MIT) |
| [babysit-pr](skills/babysit-pr/SKILL.md) | PR review rounds automation: verify, fix, reply, resolve, re-run. | adapted from [amElnagdy/review-skills](https://github.com/amElnagdy/review-skills) (MIT) |

## What stays in your orchestrator (never delegated)

- user-facing engineering decisions
- severity of an incident
- risk vs speed trade-offs
- safety-boundary checks (secrets, destructive migrations, prod actions)
- side-effecting actions (kubectl apply, terraform apply, DB migrations)
- tool-sequence orchestration

## The routing map

- **groq** (openai/gpt-oss-120b, ~500 req/min, 8,000 tokens/min cap): ADRs, PR descriptions, post-mortems, release notes.
- **gpt-5.1-codex** (400K, thinking): refactoring, boilerplate, test scaffolding, migrations.
- **nemotron** (NVIDIA, 1M context): bulk reading of large codebases and log dumps.
- **flash** (Gemini 3.6-flash, 1M context): fast structured extraction (API surface, deps, config diffs).
- **or-free** (OpenRouter meta-router, 200K): generalist fallback.
- **pro** (Gemini 3 Pro preview): deep architecture reasoning + adversarial ADR debate.

## The 4-phase lifecycle

1. **Design:** architect skill + pro debate → ADR + trade-off matrix.
2. **Implementation:** test-strategist + debate-review → tested code + one PR review.
3. **Staging:** ship-checklist → rollback plan + smoke tests.
4. **Production:** incident-response ready; retrospective for anything customer-visible.

Full spec: [docs/WORKFLOW.md](docs/WORKFLOW.md).

### The 4-step fix-validation pipeline (inner loop)

Every code fix runs through a fixed 4-step pipeline before it merges or ships, mirroring the sauron `validator` pattern but for software fixes rather than vulnerabilities:

1. **Stress-test** the fix with `fix-validator`: 12 fields including Root Cause Confidence, Regression Risk, Blast Radius, Test Coverage, Missing Tests, Rollback Complexity, Side Effects, Security Impact, Performance Impact, Backwards Compatibility, Deployment Risk, Final Verdict.
2. **Gap tests** for every missing test the validator flagged (unit, contract, integration, mutation).
3. **Adversarial code review** via `mcp__hermes__challenge` (pro primary, groq fallback). Attacks the fix from correctness, layering, rollback, backwards compat, and 10x-traffic angles.
4. **Synthesize + write** the PR description (delegated to groq); human byte-checks file paths, function signatures, migration steps against the raw diff before merge.

Full spec: [skills/fix-validator/SKILL.md](skills/fix-validator/SKILL.md).

## Orchestrators

The installer supports six targets. Pick one at prompt `0` in `./setup.sh`.

- **Claude Code** (default): writes `~/.claude/settings.json` (or `./.claude/settings.json` for per-project) with `SessionStart` + `UserPromptSubmit` hooks, and symlinks `skills/*` into `~/.claude/skills/`.
- **Cursor**: writes `./.cursor/rules/let-there-be-light.mdc` with `alwaysApply: true`, and copies `skills/*` into `./.cursor/rules/let-there-be-light-skills/` so the model can read them.
- **Cline**: writes `./.clinerules` (or `~/.clinerules` for global) with the routing doctrine, and copies `skills/*` into `./let-there-be-light-skills/`.
- **Codex CLI**: writes `~/.codex/instructions.md` and copies `skills/*` into `~/.codex/let-there-be-light-skills/`.
- **Aider**: writes `./.aider.let-there-be-light.md` (add to your `.aider.conf.yml` as `read: [./.aider.let-there-be-light.md]`) and copies `skills/*` into `./let-there-be-light-skills/`.
- **Generic / other**: writes `./SYSTEM_PROMPT.let-there-be-light.md` you can paste into any tool's system prompt, with `skills/*` copied alongside.

For non-Claude orchestrators the installer also appends an index of the shipped skills to the rules file so the model knows what SKILL.md files it can read when a trigger phrase appears (since only Claude Code has the `Skill()` primitive).

## Failover doctrine

If any model refuses, times out, or errors, immediately re-route. Refusal is a routing problem, not a stop.

## Install

```bash
# REQUIRED: Hermes intelligent multi-provider MCP model router (setup.sh auto-installs + registers if missing)
git clone https://github.com/crowx01/hermes-mcp-server ~/tools/hermes-mcp-server
git clone https://github.com/crowx01/let-there-be-light && cd let-there-be-light
./setup.sh
```

`setup.sh` walks you through scope (global vs per-project), which skills auto-load at session start, which Hermes models you have keys for, symlinking or copying the skills into the appropriate location, and a Hermes registration sanity check. Any existing hooks from other frameworks are appended-to, never clobbered.

See a full picture-book walkthrough of the wizard + what your orchestrator sees: **[docs/install-walkthrough.pdf](docs/install-walkthrough.pdf)** (4 pages, dawn-palette / fire-palette rendering).

Prefer manual? See `settings.example.json` (Claude Code format) or any orchestrator-specific example under `docs/`.

## Sibling: sauron

This repo is the sibling to [crowx01/sauron](https://github.com/crowx01/sauron), the offensive-security framework for bug-bounty and pentest work. Same underlying pattern (orchestrator + Hermes delegate-first + interactive setup wizard); different skills.

## Attribution

`skills/debate-review` and `skills/babysit-pr` are adapted from [amElnagdy/review-skills](https://github.com/amElnagdy/review-skills) (MIT, Copyright Ahmed Mohammed). Upstream license is preserved inside each skill dir and in [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

## License

MIT for let-there-be-light own code ([LICENSE](LICENSE)). Third-party licenses in [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

---

> And there was light.
