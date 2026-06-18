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

## Results log — COMPLETE (live-fire proven 2026-06-18)

| Rule | logtest | Attack | Fired? | Level | Screenshot | Date |
|---|---|---|---|---|---|---|
| 100015 | ✅ 06-17 | `nmap -sV -A` from zeno | ✅ 25 alerts | 12 | `phase4_dashboard_100015_100016_fired_25hits_level12.png` | 06-18 |
| 100016 | ✅ 06-17 | burst from scan chain | ✅ (part of 100015 chain) | 12 | same screenshot | 06-18 |
| 100017 | ✅ 06-17 | `hydra` 30-attempt burst | ✅ 6 alerts | 12 | `phase4_dashboard_100017_brute_force_6hits_level12_MITRE_T1110.png` | 06-18 |
| 100018 | ✅ 06-17 | hydra `-t 1` with valid cred | ✅ 1 alert | 14 | `phase4_dashboard_100018_compromise_FIRED_level14_MITRE_T1110_T1078.png` | 06-18 |
| 100019 | ✅ 06-17 | `sudo cat /etc/shadow` on zbook-arch | ✅ 31,751 alerts | 12 | `phase4_dashboard_100019_file_access_31751hits_over_tuned.png` | 06-18 |
| 100020 | ✅ 06-17 | scan to port 5900 | ✅ shadow-blocked by 100015; replaced by 100021 | — | `phase4_dashboard_100020_NO_RESULTS_rule_shadowing_root_cause.png` | 06-18 |
| 100021 | ✅ 06-18 | `nmap -Pn -p 5900` from zeno | ✅ 1 alert | 12 | `phase4_dashboard_100021_VNC_FIRED_level12_MITRE_VNC_rpi_sensor.png` | 06-18 |

All screenshots in `../../portfolio/screenshots/phase4/`.

**Negative results (documented honestly):**
- `nmap -sS -T1` stealth scan: ZERO alerts — full evasion. Documented in `../../incidents/phase3_stealth_scan_gap_report.md`.
- 100018 missed on first B2 run (`hydra -t 4` parallel) — race condition. Documented in `../../incidents/phase3_ssh_bruteforce_report.md`.
- 100019 fired 31,751 alerts — passwd watch over-tuned. Fixed 2026-06-18 (passwd watch changed to `-p wa` on zbook-arch). See PR #14.

---

## Done when

- [x] All 7 rules validate clean in `wazuh-logtest` (parent ids + fields confirmed).
- [x] Each rule has at least one screenshot of it firing at the intended level.
- [x] The results table above is fully filled.
- [x] `PROJECT_STATUS.md` Phase 4 marked done and overall % bumped.
