# Phase 4 — Detection Engineering

**Goal:** turn the Phase 3 gaps into custom Wazuh rules that fire at SOC-relevant severity.
**Deliverable:** 5+ custom rules in `../../rules/local_rules.xml`, each validated and proven to fire.
**Target date:** July 18, 2026.

---

## Why these rules exist (each traces to a Phase 3 finding)

Phase 3 (`incidents/phase3_threat_sim_report.md`) proved the pipeline works but exposed three
detection gaps. Phase 4 closes them. Nothing here is invented — every rule answers a documented miss.

| Rule | Finding it closes | Severity | MITRE |
|---|---|---|---|
| 100015 | nmap scan fired Suricata Priority 1 but **0 Wazuh Level-12+ alerts** | 12 | T1046 |
| 100016 | detection leaned on the HTTP user-agent; a stealth `-sS` scan is quieter | 12 (burst) | T1046 |
| 100017 | the Pi exposes SSH (22) — no high-sev brute-force alert existed | 12 | T1110 |
| 100018 | brute force that **succeeds** = compromise, must be the loudest alert | 14 | T1110 + T1078 |
| 100019 | agents watch `/etc/shadow` `/etc/sudoers` via auditd but nothing escalated access | 12 | T1003 + T1098 |
| 100020 | scan exposed **VNC 5900** — a remote-control surface that should be localhost-only | 10 | T1021.005 |

---

## Deploy + prove-it workflow (per rule)

Detection engineering is not "write XML" — it is **write → validate → trigger → confirm → document**.
For each rule:

1. **Back up** the live file (a syntax error takes the dashboard down):
   ```
   sudo cp /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml.bak
   ```
2. **Paste** the rule into `/var/ossec/etc/rules/local_rules.xml` on the manager.
3. **Validate parent id + field names** against a REAL log line:
   ```
   sudo /var/ossec/bin/wazuh-logtest
   ```
   Paste a real Suricata `eve.json` alert line (or a real `sshd` failure line). Read back the
   rule id it matched and the decoded field names. If they differ from the defaults in the rule
   comments, fix `<if_sid>` / `<field name>` to match YOUR ruleset version.
4. **Restart** the manager:
   ```
   docker exec -it single-node-wazuh.manager-1 /var/ossec/bin/wazuh-control restart
   ```
5. **Trigger** the matching attack (see `../phase3_threat_simulation/` run commands).
6. **Confirm** on the dashboard: Threat Hunting → filter `rule.id:100015` (etc.) → screenshot to
   `../../portfolio/screenshots/phase4/`.
7. **Record** the before/after in the table below.

---

## Results log (fill as each rule is proven)

| Rule | Validated in logtest | Attack that triggered it | Fired? (level) | Screenshot | Date |
|---|---|---|---|---|---|
| 100015 | ✅ 06-17 | `nmap -sV -A` → Pi | ☐ | ☐ | |
| 100016 | ✅ 06-17 | `nmap -sS` → Pi | ☐ | ☐ | |
| 100017 | ✅ 06-17 | `hydra ssh` → target | ☐ | ☐ | |
| 100018 | ✅ 06-17 | hydra with one valid cred | ☐ | ☐ | |
| 100019 | ✅ 06-17 | `sudo cat /etc/shadow` on an agent | ☐ | ☐ | |
| 100020 | ✅ 06-17 | `nc -vz <pi> 5900` from attacker | ☐ | ☐ | |

> **Deploy + validation note (2026-06-17):** all 6 rules deployed to the live manager and
> confirmed firing in `wazuh-logtest`. Five needed parent/field corrections vs the draft
> (Suricata fields are root-level not `data.*`; sshd valid-user failures are `5760`; brute
> force chains off `5712`/`5763`; auditd parent is `80700`; Suricata correlation uses
> `same_field`). Full failure-and-fix write-up: `../../docs/Detection_Engineering_Journal_2026-06-17.md`.
> The `Fired? / Screenshot` columns stay open until a live Phase 3 attack proves each on the dashboard.

---

## Done when

- [x] All 6 rules validate clean in `wazuh-logtest` (parent ids + fields confirmed).
- [ ] Each rule has at least one screenshot of it firing at the intended level.
- [ ] The results table above is fully filled.
- [ ] `PROJECT_STATUS.md` Phase 4 marked done and overall % bumped.
