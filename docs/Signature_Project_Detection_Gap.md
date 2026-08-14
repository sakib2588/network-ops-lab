# Signature Project: Detection Gap Closure (SOC Case Study)

> **For Sakib.** This is the focused, non-generic project script. Do it by hand, step by
> step. It drives ONE realistic intrusion end to end, closes ONE real detection gap with a
> validated custom rule, investigates it like an analyst, and bridges it to your
> realizability-gap research. Every step ends with a gate. Do not start the next step until
> the gate passes.

**Goal of this project:** turn a "I stood up a Wazuh dashboard" lab (which proves you
followed a tutorial) into "I found a hole in the default detection and closed it, and I can
explain every line" (which proves you can do the job). Depth and defensibility, not more tools.

**One-sentence pitch (memorize this):** One realistic intrusion, detected across host (Wazuh
agent) and network (Suricata) layers, where I closed a real detection gap with a documented,
`wazuh-logtest`-validated custom rule, investigated it like an analyst, and tied it to my
NIDS realizability research.

---

## 1. Scope and honesty split (read before you start)

This is NOT a single evening. Be honest with yourself about time so you do not abandon it
half-built.

**Minimum Viable Artifact (MVA) -- ship this FIRST. About 2 focused days AFTER the lab is back up.**

1. The attack chain run once, real output captured.
2. ONE detection gap closed with a documented + validated custom rule.
3. ONE professional incident report.
4. A clean README so the work is visible.

That is a complete, shippable, defensible portfolio piece on its own. Ship it before touching
anything below.

**Extensions -- only AFTER the MVA is shipped:**

- 2nd / 3rd gap closed.
- A correlation rule (frequency-based).
- Full host-vs-network coverage comparison.
- Atomic Red Team in place of the manual tools.
- The realizability-gap research note (Step 5).

**Time honesty:** MVA is about 2 focused days *after* the lab is rebuilt. Full version is
about 4-5 days. The rebuild itself (Step 0) is its own milestone and can eat a day -- do not
fold it into the "2 days". Each numbered step below is independently shippable.

---

## 2. Integrity guardrails (non-negotiable)

These are what separate a real case study from a fabricated one. A panel can smell a faked lab.

- **No fabricated data.** The gap matrix in Step 2 must be *produced by actually running the
  techniques*, not copied from the master plan. A technique that does NOT alert is recorded
  honestly as a finding -- that is the whole point of the project.
- **No invented ML results.** The realizability note (Step 5) is *conceptual and
  forward-looking only*. It cites the real Ennaji et al. (2025) paper and is labelled "thesis
  direction." It must NOT imply that any ML detection was run on lab traffic, because it was not.
- **No over-claiming.** Your framing is always "I tuned and extended Wazuh's detection and
  closed a gap." Never "I built an IDS" or "I built network detection." Wazuh's built-in rules
  and Suricata's Emerging Threats ruleset did most of the work -- credit them. You claim the
  tuning and the one rule you wrote.
- **Teach-back gate.** Before any artifact is marked "done," record or say a 2-minute
  plain-language explanation of it, with no notes. If you cannot, it is not done -- it is study
  material. This project exists to kill surface knowledge, so this gate is the point.

### Objective and verifiable rule (applies to every step)

Every gap-matrix cell and every incident-report claim must cite the **evidence that proves
it** -- an exact file path plus line or timestamp:

- an entry in `/var/ossec/logs/alerts/alerts.log`, or
- a screenshot in `portfolio/screenshots/<name>.png`, or
- a captured `wazuh-logtest` output.

No claim without a traceable artifact. "Alerted? No" is only valid *after* you grepped the
alert log and found nothing -- never assumed. For every run, record the **exact command, the
target IP, and the timestamp** so the run is reproducible.

---

## 3. Step 0 -- Rebuild the lab (gated milestone)

The Wazuh server was on a powered-off VirtualBox VM. Before anything else, rebuild it.

- Follow `docs/Server_Migration_Runbook.md` end to end (Docker single-node Wazuh on the 12 GB
  Arch laptop, then re-enroll the agents).
- Work through it to the Phase 2 gate.

**Gate (must all pass before Step 1):**

- Dashboard reachable in a browser (`https://<SERVER_IP>`).
- At least 2 agents showing `Active` in the dashboard.
- Basic log ingestion confirmed (you see events flowing).

See "Edge cases and countermeasures -> Step 0" below before you start -- the indexer and the
agent enrollment have specific failure modes.

---

## 4. Step 1 -- Choose the attack chain (host + network)

One realistic chain, three stages, all simple and defensible. Run it from one machine (the RPi
or a Linux box) against a target agent on the LAN. **Authorized lab only -- your own machines.**

| Stage | Technique | Command (example) | Layer that should catch it |
|---|---|---|---|
| Recon | T1046 Network Service Discovery | `sudo nmap -sS <target_ip>` | Network (Suricata) |
| Initial access | T1110 Brute Force | `hydra -l <user> -P <wordlist> ssh://<target_ip>` | Host (Wazuh, auth.log) |
| Post-compromise GAP | T1548.003 Sudo / sensitive-file access | access `/etc/shadow` via sudo on the target | Logged but NOT alerted by default = the gap |

Record for each: exact command, target IP, timestamp.

> The post-compromise stage is the one you expect to be **logged but not alerted** by Wazuh's
> defaults. That is the gap you will close in Step 3. But do not assume it -- Step 2 proves it
> empirically.

---

## 5. Step 2 -- Produce the real gap matrix

Run each stage. For each, check BOTH the dashboard and `/var/ossec/logs/alerts/alerts.log` and
record honestly whether it alerted by default. Screenshot the evidence into
`portfolio/screenshots/`.

Produce this table (this is YOUR result, not the master-plan design):

| Technique | Logged? | Alerted by default? | Evidence (file path / screenshot / alert line) |
|---|---|---|---|
| T1046 nmap scan | | | |
| T1110 SSH brute force | | | |
| T1548.003 sudo / shadow access | | | |

- The master plan (`docs/SOC_Lab_Project_Plan.md`, the matrix around lines 1492-1517) is the
  *design* -- a hypothesis of what will and will not alert. THIS table is the *produced* result.
  They may differ. If they differ, your produced table wins, because it is real.
- A cell marked "Alerted? No" is only valid after you grepped the alert log and found nothing.

**Gate:** the table is filled with real evidence links, and the "gap" stage (the one that is
logged but not alerted) is confirmed by an actual grep that returned nothing.

---

## 6. Step 3 -- Close the gap (detection engineering)

Write a custom rule for the not-alerted technique (the sudo / sensitive-file access).

- Edit `/var/ossec/etc/rules/local_rules.xml` on the Wazuh manager.
- **Reuse the rule syntax from `docs/guides/Blue_Team_Home_Lab_Guide.md`, Section 4.2** --
  `<if_sid>`, `<field name="..." type="pcre2">`, `<mitre>`, `<group>`. Do not invent syntax.
- That guide already uses example IDs 100001-100014, so start your rule at **100015**.
- **Before editing:** back up the file --
  `sudo cp /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml.backup`.

Document, in the rule comment and your notes:

- the threat (what the attacker did),
- the decoder / log fields the rule keys on (read these from `wazuh-logtest`, see below),
- why the chosen level / threshold,
- which false positives you tuned out.

Validate and confirm:

1. `sudo /var/ossec/bin/wazuh-logtest` -- paste the raw log line, confirm your rule fires.
   Capture this output (it is your proof).
2. Restart the manager and confirm it came back up.
3. Re-run the attack stage -> confirm it now alerts on the dashboard.

Then commit the finished rule into the repo at `rules/local_rules.xml` (so the GitHub artifact
shows it).

**Teach-back gate:** explain, with no notes, why this rule's `<if_sid>` parent is what it is,
what field it matches, and what false positive you removed. If you cannot, you do not
understand it yet.

---

## 7. Step 4 -- Incident report (the highest-signal artifact)

Write ONE professional incident report into `incidents/`. This is the daily deliverable of the
actual job, so it is the artifact a SOC panel cares about most.

Use the template in `incidents/README.md`. It must contain:

- **Timeline** of the chain (with timestamps).
- **Evidence** -- log excerpts and screenshot references for each stage.
- **MITRE mapping** per stage (T1046, T1110, T1548.003).
- **Root cause.**
- **Recommended response / containment.**

Every claim cites its evidence (alert line, screenshot, or logtest output).

**Teach-back gate:** walk through the report out loud in 2 minutes, no notes.

---

## 8. Step 5 -- Host vs network comparison + realizability note (extension)

Short analysis (one page is fine):

- Which stages were caught at the **host** layer (Wazuh agent, auth.log) vs the **network**
  layer (Suricata on the RPi)?
- What could an attacker do to evade each layer?

Then the **realizability note** -- conceptual and honest:

- Reuse your own framing already written in `phases/phase7_raspberry_pi/RPi_Suricata_Setup.md`
  (the "Thesis connection" paragraph near the top, and the saved note near the end). Do not
  write fresh claims.
- Cite Ennaji et al. (2025). Quote only what you have actually read and can defend.
- Label it explicitly: "thesis direction, conceptual." It must NOT imply ML was run on lab
  traffic.
- The idea: feature-space dataset attacks differ from packets that must survive a real TCP/IP
  stack -- Suricata sees the wire, which is direct evidence of the realizability gap.

---

## 9. Step 6 -- Package for GitHub (HR visibility)

Create a new PUBLIC repo (suggested name: `wazuh-detection-engineering`).

Contents:

- `README.md` -- architecture diagram, the produced gap matrix, before/after coverage, links.
- `rules/` -- the custom rule.
- `incident-reports/` -- the incident report.
- `screenshots/` -- the evidence screenshots (redacted -- see edge cases).

Then:

- Pin the repo on your GitHub profile.
- Glyph-audit before pushing: no non-ASCII glyphs (no section sign U+00A7, no pilcrow U+00B6,
  no smart quotes, no em-dashes) -- they render as mojibake on GitHub.
- Commit as `sakib2588`.

A README skeleton is at the bottom of this guide.

---

## 10. Edge cases and countermeasures

Each is a verifiable failure mode. Hit the listed check before moving on.

### Step 0 -- lab rebuild

- **Indexer will not start (silent exit).** Wazuh's indexer needs
  `vm.max_map_count=262144`. -> Run `sudo sysctl -w vm.max_map_count=262144` and persist it in
  `/etc/sysctl.conf` *before* `docker compose up`. **Verify:** the indexer container is
  `healthy`, not restart-looping (`docker ps`).
- **12 GB Arch laptop runs out of memory.** The full stack (JVM indexer ~2-4 GB) plus a
  browser starves the machine. -> Single-node compose only; close other apps; enroll agents
  *after* the stack is healthy. **Verify:** `docker stats` shows headroom and the dashboard
  loads.
- **Agent shows "Never connected" / "Disconnected".** Usually wrong `SERVER_IP`, DHCP changed
  it, or ports 1514/1515 blocked. -> Use a static IP or DHCP reservation (the runbook covers
  this); open 1514-1515. **Verify:** `Active` in the dashboard AND the agent log shows
  "Connected to enrollment service".
- **Re-enrollment key clash after rebuild.** Old agents carry stale keys. -> Remove and re-add
  the agent, redeploy the key. **Verify:** the agent appears once, status `Active`.

### Steps 1-2 -- attack chain and matrix

- **nmap SYN scan fires nothing on the network layer.** `-sS` needs root, and Suricata only
  alerts if its ruleset is loaded. -> Run `sudo nmap`; run `sudo suricata-update` and restart
  Suricata first. **Verify the source before blaming Wazuh:** `tail /var/log/suricata/fast.log`
  and `eve.json` must show the scan; only then check Wazuh.
- **Suricata alerts exist but Wazuh shows none.** The agent `ossec.conf` is missing the
  `eve.json` localfile block, or it was not restarted, or the JSON is not being decoded. ->
  Confirm the `<localfile>` block (per `RPi_Suricata_Setup.md` Step 5) and restart the agent.
  **Verify:** paste one `eve.json` line into `wazuh-logtest` and confirm a rule matches.
- **hydra brute force generates no host alert.** SSH disabled, account lockout / fail2ban
  throttling, or Wazuh is not watching the auth log path. -> Confirm `sshd` is running; send
  enough attempts to trip the built-in sshd rules (e.g. 5710 / 5712); confirm
  `/var/log/auth.log` (Debian/Ubuntu) is in the agent config. **Verify:**
  `grep "authentication failure" /var/ossec/logs/alerts/alerts.log`.
- **A "gap" you assumed is actually covered (or vice versa).** Wazuh ships thousands of rules;
  your guess can be wrong. -> Treat every matrix cell as empirical -- grep the alert log; if
  nothing, *that* is the finding. **Verify:** each cell links to evidence (an alert line, or a
  "no match" grep result).
- **Agent / manager clock skew** makes the chain impossible to correlate. -> NTP-sync all
  nodes. **Verify:** timestamps across nodes agree within seconds.

### Step 3 -- custom rule

- **Rule never fires because `<if_sid>` parent is wrong.** A custom rule only evaluates when
  its parent rule matched. -> Run `wazuh-logtest` on the raw line, read the matched rule id from
  the output, and set `<if_sid>` to that. **Verify:** logtest shows your 100015+ rule firing as
  a child.
- **Matching a field the decoder never produced.** `<field name="...">` only works on fields
  that were actually decoded. -> In logtest, read which fields the decoder extracted; match only
  those. **Verify:** the field appears in logtest's decoded output.
- **Regex flavor mismatch.** Wazuh defaults to os_regex; PCRE needs `type="pcre2"`, with
  different escaping. -> Match the example syntax in `Blue_Team_Home_Lab_Guide.md` Section 4.2;
  test the pattern in logtest before committing.
- **ID collision.** 100001-100014 are already used by the Blue Team guide examples. -> Start at
  **100015**. **Verify:** `grep -r 'rule id="1000' rules/` shows no duplicate.
- **Syntax error bricks the SIEM.** A malformed `local_rules.xml` stops `wazuh-manager` from
  starting -- the whole dashboard goes down. -> Back up first, then restart and confirm it came
  back. **Verify:** manager `running` and dashboard reachable after the edit.
- **The rule is too broad -> alert fatigue.** A raw "/etc/shadow access" rule fires on cron,
  backups, and package managers. -> Scope by user / process, exclude known-good, document the
  tuned-out false positives. **Verify:** re-running the *attack* fires it; a *benign* admin
  action does not.

### Steps 4-6 -- report, analysis, public repo

- **Screenshot / commit leaks** in a PUBLIC repo: real internal IPs, hostnames, usernames, the
  AIUB student ID, the admin password, and the personal absolute path
  `/media/filwel/All/Sakib/...` referenced in `RPi_Suricata_Setup.md`. -> Redact IPs and
  usernames, never commit passwords, strip personal paths; scan git history before pushing.
  **Verify:** `git log -p | grep -iE 'pass|192\.168|/media/filwel'` returns nothing sensitive.
- **Wrong commit author.** Must be `sakib2588`, not an automation identity. **Verify:**
  `git log --format='%an %ae'` shows you.
- **Non-ASCII glyphs** render as mojibake on GitHub. -> ASCII only. **Verify:** glyph grep
  returns nothing.
- **Realizability over-reach.** Citing Ennaji 2025 specifics you have not read, or implying ML
  ran on lab traffic. -> Quote only what is defensible; label the note "thesis direction,
  conceptual." **Verify:** teach-back -- you explain the note unaided.

---

## 11. Common pitfalls to avoid

1. **Skipping the MVA for breadth.** Doing all 9 techniques / 5 rules before shipping one. ->
   Ship the MVA (one gap, one rule, one report, README) first; extensions only after.
2. **Copying the designed matrix as if it were results.** The master-plan table is a *design*;
   presenting it as produced output is fabrication. -> Produce your own table from real runs.
3. **Claiming authorship of built-in detection.** "I built network IDS detection" when
   Suricata's ET rules / Wazuh's defaults did the work. -> Credit built-ins; claim only the
   tuning and the one rule you wrote.
4. **Editing `local_rules.xml` with no backup and no logtest.** -> Always back up, always
   validate, always confirm the manager restarted.
5. **Treating "no alert" as a failure to hide.** A technique that does not alert is the *most
   valuable* finding -- it is the gap. -> Record it honestly; it is the whole point.
6. **Publishing the conflicting thesis doc.** Linking the public repo to
   `Full_Implementation_Guide.md` (the XAIT / IoT thesis) contradicts your locked NIDS
   narrative and invites awkward panel questions. -> Keep the public repo scoped to the locked
   narrative; do not publish that guide.
7. **Underestimating the rebuild.** "2 days" assumes the lab is already up; the rebuild is its
   own milestone that can eat a day. -> Treat Step 0 as a separate gated milestone.
8. **Marking an artifact "done" without the teach-back.** Surface knowledge is the exact
   weakness this project exists to fix. -> No teach-back, not done.

---

## 12. Verification (how you prove the whole project is done)

- **Technical truth:** `wazuh-logtest` shows the custom rule matching; re-running the attack
  produces the alert on the dashboard; the before/after coverage numbers are real, taken from
  captured logs.
- **Defensibility:** you pass the 2-minute teach-back, unaided, on the custom rule and on the
  incident report.
- **Visibility (HR):** the public repo renders cleanly, the README is readable in 30 seconds,
  and it is pinned on your profile.
- **Integrity audit:** no fabricated ML results; the realizability note is labelled
  conceptual; built-in rules are credited; the glyph check returns zero non-ASCII glyphs; no
  secrets or personal paths in git history.

---

## 13. Open flag (not blocking this project)

There are two different theses living in this repo:

- **Locked narrative (use this):** Adversarial ML for NIDS, the realizability gap, Ennaji et
  al. (2025). It appears in `PROJECT_STATUS.md` and
  `phases/phase7_raspberry_pi/RPi_Suricata_Setup.md`.
- **Conflicting narrative (do not use here):** XAIT / IoT / SHAP / CIC-IoT-2023. This came from
  an early unverified draft that carried aspirational metrics and an outdated thesis framing.
  The draft was deleted from the repo on 2026-08-15; nothing in it was ever a real result.

This project uses only the locked narrative. If the XAIT framing turns up anywhere else in the
lab docs, it is a leftover from that deleted draft and should be corrected, not cited.

---

## Appendix A -- Incident report template

(Also kept in `incidents/README.md`. Copy it per incident.)

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

---

## Appendix B -- Public repo README skeleton

```markdown
# Wazuh Detection Engineering: Closing a Real Detection Gap

A SOC case study. I ran one realistic intrusion across host and network layers, found a
technique that Wazuh logged but did not alert on by default, wrote and validated a custom rule
to close the gap, and documented the incident like an analyst.

## Architecture
<diagram: attacker -> target agent (Wazuh) + RPi (Suricata) -> Wazuh manager/dashboard>

## The detection gap (produced from real runs)
| Technique | Logged? | Alerted by default? | After custom rule? |
|---|---|---|---|
| T1046 nmap scan | yes | <result> | - |
| T1110 SSH brute force | yes | <result> | - |
| T1548.003 sudo / shadow access | yes | no | yes (rule 100015) |

## What I built vs what was built in
- Built in (credited): Wazuh default ruleset, Suricata Emerging Threats ruleset.
- My work: the detection-gap analysis, custom rule 100015, the tuning, and the incident report.

## Contents
- `rules/` -- the custom rule, with comments explaining the decoder fields and tuning.
- `incident-reports/` -- the full incident report.
- `screenshots/` -- evidence (redacted).

## Research connection (thesis direction, conceptual)
Suricata operates on real TCP/IP packets, not feature-extracted dataset values -- a concrete
demonstration of the realizability gap described in Ennaji et al. (2025). This is forward-looking
context for my thesis, not an ML experiment run on this lab.
```
