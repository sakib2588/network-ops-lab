# incidents/

Incident reports -- the highest-signal portfolio artifact, because writing them is the daily
deliverable of a SOC analyst job.

Each report investigates the attack chain from
`../docs/Signature_Project_Detection_Gap.md`: timeline, evidence, MITRE mapping, root cause,
detection gap and its closure, and recommended response. Every claim cites its evidence
(an `alerts.log` line, a screenshot in `../portfolio/screenshots/`, or a `wazuh-logtest`
capture).

Copy the template below per incident. Keep it ASCII-only so it renders cleanly on GitHub.

```markdown
# Incident Report: <short title>

**Analyst:** Nazmus Sakib
**Date:** <YYYY-MM-DD>
**Severity:** <Low / Medium / High / Critical>
**Status:** <Open / Contained / Closed>

## Summary
<2-3 sentences: what happened, what was affected, current state.>

## Timeline (with evidence)
| Time | Stage | Action observed | Evidence (alerts.log line / screenshot) |
|---|---|---|---|
| | Recon (T1046) | | |
| | Initial access (T1110) | | |
| | Post-compromise (T1548.003) | | |

## MITRE ATT&CK mapping
- T1046 Network Service Discovery -- <how observed>
- T1110 Brute Force -- <how observed>
- T1548.003 Sudo and Sudo Caching -- <how observed>

## Root cause
<Why it was possible; which detection was missing by default.>

## Detection gap and closure
<The gap found in Step 2; the custom rule (ID 100015+) that closes it; logtest proof.>

## Recommended response / containment
<Concrete steps: block, patch, tune, monitor.>

## Evidence index
- <path to screenshot>
- <path to alert log excerpt>
- <path to logtest capture>
```
