# incident-response

**One-line pitch:** Production skill: triages the alert, finds the right runbook, and calculates blast radius so you can decide fast.

## When to invoke
- Any active production alert.
- Any customer-reported outage.
- Any anomaly in error rate, latency, or throughput that a human is looking at.
- Trigger phrases: "incident", "outage", "pages are firing", "who owns X".

## What I produce
- Blast radius: which services, tenants, regions, and features are affected.
- Runbook link (from internal docs) for the exact alert.
- Ordered triage steps: is it caused by a recent deploy? by traffic? by an upstream?
- Draft status update: one version for engineers and one for the customer-facing status page.

## Delegation
- Bulk log-reading during the incident: `nemotron`.
- Correlation across services / traces / dashboards: `flash`.
- Draft status-page copy: `groq`.
- All decisions about mitigations (rollback, restart, scale, feature-flag): stays with Claude, then you.

## Anti-patterns
- Never guess at blast radius; measure it.
- Never write "investigating" as the only status update for more than 15 minutes.
- Never restart before capturing the diagnostic snapshot.
- Never resolve without confirming the customer-facing signal recovered, not just the internal one.

## The rule
> Communicate every 15 minutes even when there is nothing new. Silence is the second incident.
