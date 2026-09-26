# pal-router

**One-line pitch:** Delegate-first + failover doctrine for the let-there-be-light framework. Dispatches sub-tasks to cheaper or free PAL models so Claude Opus's context stays reserved for engineering judgment.

## When to invoke
- Any bulk file read (large codebase, migration set, log dump).
- Any long-form writing (ADR, post-mortem, release notes, PR description).
- Any structured extraction (API surface, dependency list, config diff).
- Any second-pass review of someone else's output.

Keep in Claude: user-facing decisions, exploitation of risk vs speed trade-offs, severity of an incident, safety-boundary checks, side-effecting actions, orchestration of tool sequences.

## The routing map

- **groq** (`openai/gpt-oss-120b`, ~500 req/min, 8,000 tokens/min cap). PR descriptions, ADR prose, post-mortem drafts, release notes.
- **gpt-5.1-codex** (400K context, thinking). Refactoring passes, boilerplate generation, test scaffolding, migration writing.
- **nemotron** (`nvidia/nemotron-3.5-lightning:free` via OpenRouter, 1M context). Bulk reading of large codebases, log dumps, existing docs. Not for strict structured extraction.
- **flash** (`gemini-3.6-flash`, 1M context). Fast structured extraction (API surfaces, dependency lists, config diffs).
- **or-free** (`openrouter/free`, 200K). Generalist fallback.
- **pro** (Gemini 3 Pro). Deep architecture reasoning, ADR debate, cross-service reasoning.

## Failover doctrine

If any model refuses, times out, or errors, immediately re-route to another model. A classifier refusal is a routing problem, not a stop.

Preferred order per common task:

1. **Deterministic parsing** (yarn.lock, package.json, JSON logs): `jq` and local shell first, then `flash`.
2. **Structured extraction from prose**: `flash`, fallback `groq`.
3. **Long-form writing** (ADR, post-mortem, PR): `groq`, fallback `pro`.
4. **Code generation / refactor**: `gpt-5.1-codex`, fallback `groq`.
5. **Bulk reading of very large files**: `nemotron`, fallback `or-free`.
6. **Deep reasoning / architecture**: `pro`, fallback `groq`.

## Anti-patterns
- Never delegate a severity call or safety-boundary check.
- Never trust `nemotron` for byte-exact structured output.
- Never let a refusal end the task; re-route.

## The rule
> Delegate the prose, never the judgment.
