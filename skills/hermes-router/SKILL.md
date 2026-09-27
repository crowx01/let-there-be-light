---
name: hermes-router
description: >-
  Delegate-first + failover doctrine for the framework. Dispatches sub-tasks to cheaper or free PAL
  models so Claude Opus's context stays reserved for judgment. Triggers on: 'route this to a
  cheaper model', 'delegate this read', 'who should write this report', 'which model do I use for
  X', 'gemini refused, what now'.
---

# hermes-router

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

## Token efficiency rules

- **Rule 1 (auto-compress large outputs):** any tool output above 5 KB (Bash, Read, WebFetch, jq) routes through `nemotron` (bulk read) or `flash` (structured) for compression before Claude reads it. Typical 10x reduction.
- **Rule 2 (batch PAL sub-tasks):** three separate groq calls for "draft prose + suggest names + explain concept" costs three adjudicate cycles. One structured PAL call returning all three saves two round trips.
- **Rule 3 (confidence triples):** on factual output, delegation prompts must ask for `{claim, confidence, source_span}` triples. Claude byte-checks only entries flagged below high confidence, not the whole draft.
- **Rule 4 (don't re-delegate):** never delegate the same task twice. If groq already drafted section X, quote it inline; do not re-ask.
- **Rule 5 (don't re-Read):** never `Read` a file already Read this session. Recall the content from conversation context.
- **Rule 6 (preempt predictable bloat):** on Bash calls whose full output you don't need, append `| head -c 5000` or `| jq -c` at the shell level rather than reading the whole dump and then summarizing.
- **Rule 7 (failure-map cache):** on any PAL refusal or 4xx/5xx, tag `$model refused $task-class this session` and skip that model for the next similar task in this conversation. Do not retry the failing route inside one turn.
- **Rule 8 (diff-first for code review):** for any "review this commit", "what changed", "audit this diff" request, run `git diff <base>..HEAD` first and reason from the diff. Only Read a full file when the diff is insufficient.
- **Rule 9 (response terseness ladder):** Level 1 (one-liner) for self-explanatory diffs / SHAs / file identifiers; Level 2 (short paragraph) for 1-2 non-obvious decisions; Level 3 (detailed section) only on explicit request or for architecture / security findings. Never default to Level 3.
- **Rule 10 (preempt shell bloat):** cap tool output over 5 KB at the shell layer. Patterns: `| head -100`, `| head -c 5000`, `| tail -20`, `| jq -c`, `| wc -l` first-then-head.
- **Rule 11 (route-plan pre-flight, speculative):** for tasks with 3 or more distinct sub-steps, issue a small groq call (~200 tokens) FIRST asking for a routing plan; then execute. Measure impact; drop if overhead exceeds savings on tasks under 5 sub-steps.

## Auto-detect delegation triggers
Auto-invoke hermes-router BEFORE reading when you see:
- A file open > 5 KB (`Read` with no `limit` on a large file)
- Any WebFetch call
- Bash output over 100 lines
- Any long-form prose request ("explain", "write up", "draft the report")

## When NOT to delegate
- The user asked for YOUR opinion or judgment
- A severity or safety-boundary call
- One-off short strings (< 200 bytes); PAL round-trip overhead dwarfs the saving

## The rule
> Delegate the prose, never the judgment.
