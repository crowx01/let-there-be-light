---
name: retrospective
description: >-
  Post-incident skill: builds the timeline, drafts the blameless post-mortem, and generates
  concrete action items that survive triage. Triggers on: 'post-mortem', 'retro', 'what went
  wrong', 'action items', after any customer-visible incident, after a near-miss, after a recurring
  bug.
---

# retrospective

**One-line pitch:** Post-incident skill: builds the timeline, drafts the blameless post-mortem, and generates concrete action items that survive triage.

## When to invoke
- After any customer-visible incident.
- After any near-miss that would have been an incident with a small change.
- After any recurring bug ("this is the third time this quarter").
- Trigger phrases: "post-mortem", "retro", "what went wrong", "action items".

## What I produce
- Timeline in UTC with sources cited (log line, alert timestamp, Slack message).
- Blameless narrative: what happened, what people believed at each step, what surprised them.
- Contributing factors, categorized (code, config, process, tooling, comms).
- Action items with an owner and a deadline; never more than 5, or they will not ship.

## Delegation
- Bulk timeline reconstruction from logs: `nemotron`.
- Draft narrative prose: `groq`.
- Comparative analysis against similar past incidents: `pro`.
- Root-cause assignment and severity call: stays with Claude, then the responder.

## Anti-patterns
- Never write blameful language ("X did Y wrong"). Write "X did Y because they believed Z".
- Never accept "add more monitoring" as an action item; specify what and why.
- Never publish a post-mortem with more than 5 action items.
- Never close a post-mortem before the action items have a due date and an owner.

## The rule
> The point of a post-mortem is to change something, not to explain something.
