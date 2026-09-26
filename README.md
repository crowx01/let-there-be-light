# let-there-be-light

**From design to production. Let there be light.**

> "And God said, Let there be light: and there was light." Genesis 1:3

## What it is

It is a framework of Claude Code skills that turns Claude Opus into a senior engineer across the full dev lifecycle: design, implementation, staging, production. It ships hooks that install a delegate-first routing doctrine so Claude keeps its context for judgment while cheaper models do the busy work.

## The days of creation (skills)

| Skill | Job | Source |
|-------|-----|--------|
| [architect](skills/architect/SKILL.md) | Design phase: system design, ADRs, tech-stack choices. | mine |
| [test-strategist](skills/test-strategist/SKILL.md) | Implementation: test pyramid, coverage plan, fixture strategy. | mine |
| [ship-checklist](skills/ship-checklist/SKILL.md) | Staging: pre-deploy checklist, rollback plan, smoke tests. | mine |
| [incident-response](skills/incident-response/SKILL.md) | Production: alert triage, blast radius, status update. | mine |
| [retrospective](skills/retrospective/SKILL.md) | Post-incident: timeline, blameless post-mortem, action items. | mine |
| [pal-router](skills/pal-router/SKILL.md) | Delegate-first + failover routing doctrine. | mine |
| [debate-review](skills/debate-review/SKILL.md) | Two-model PR debate, posts one review from your gh/glab/az. | adapted from [amElnagdy/review-skills](https://github.com/amElnagdy/review-skills) (MIT) |
| [babysit-pr](skills/babysit-pr/SKILL.md) | PR review rounds automation: verify, fix, reply, resolve, re-run. | adapted from [amElnagdy/review-skills](https://github.com/amElnagdy/review-skills) (MIT) |

## What stays in Claude (never delegated)

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

## Failover doctrine

If any model refuses, times out, or errors, immediately re-route. Refusal is a routing problem, not a stop.

## Install

```bash
git clone https://github.com/BeehiveInnovations/zen-mcp-server ~/tools/zen-mcp-server
git clone https://github.com/crowx01/let-there-be-light && cd let-there-be-light
./setup.sh
```

`setup.sh` walks you through scope (global vs per-project), which skills auto-load at session start, which PAL models you have keys for, symlinking the skills into `~/.claude/skills` or `./.claude/skills`, and a PAL registration sanity check. Any existing hooks from other frameworks are appended-to, never clobbered.

See a full picture-book walkthrough of the wizard + what Claude sees: **[docs/install-walkthrough.pdf](docs/install-walkthrough.pdf)** (4 pages, dawn-palette / fire-palette rendering).

Prefer manual? Copy `settings.example.json` into `~/.claude/settings.json` and edit by hand.

## Sibling: sauron

This repo is the sibling to [crowx01/sauron](https://github.com/crowx01/sauron), the offensive-security framework for bug-bounty and pentest work. Same underlying pattern (Claude Code + PAL delegate-first + interactive setup wizard); different skills.

## Attribution

`skills/debate-review` and `skills/babysit-pr` are adapted from [amElnagdy/review-skills](https://github.com/amElnagdy/review-skills) (MIT, Copyright Ahmed Mohammed). Upstream license is preserved inside each skill dir and in [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

## License

MIT for let-there-be-light own code ([LICENSE](LICENSE)). Third-party licenses in [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

---

> And there was light.
