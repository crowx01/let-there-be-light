---
name: architect
description: >-
  Design-phase skill: turns product ideas into system designs, ADRs, and tech-stack decisions
  before a line of code ships. Triggers on: 'design this', 'should we use X', 'write an ADR', 'what
  is the architecture', new feature spanning multiple services, tech choice, migration touching
  data flow or auth boundaries.
---

# architect

**One-line pitch:** Design-phase skill: turns product ideas into system designs, ADRs, and tech-stack decisions before a line of code ships.

## When to invoke
- Any new feature that touches more than one service, database, or contract.
- Any tech-choice decision (framework, cloud provider, storage engine, messaging).
- Any migration that changes data flow or auth boundaries.
- Trigger phrases: "design this", "should we use X", "write an ADR", "what is the architecture".

## What I produce
- One-page system diagram (component + data flow, plain-text or mermaid).
- ADR in the standard format (title, context, decision, consequences, alternatives-considered).
- Trade-off matrix for the top 2-3 alternatives.
- Explicit list of assumptions and unknowns.

## Delegation
- Bulk reading of existing docs / RFCs / codebase context: `nemotron` (1M ctx).
- Draft ADR prose: `groq`.
- Comparative reasoning between alternatives: `pro` (Gemini 3 Pro).
- Final judgment on which alternative to recommend: stays in Claude.

## Anti-patterns
- Never pick a tech based on hype.
- Never skip the "do nothing" alternative.
- Never write an ADR without naming the unknowns.
- Never let the trade-off matrix be all-green for one option (that means you did not look hard enough).

## The rule
> A design doc that names the unknowns beats one that pretends there are none.
