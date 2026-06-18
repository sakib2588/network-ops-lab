# SOC Lab Portfolio — Nazmus Sakib

**Role:** ML Security Researcher / SOC Analyst (BSc CSE final year, AIUB)
**Lab built:** June 2026 | **Repo:** github.com/sakib2588/cyber-security-soc-lab

This portfolio documents a home SOC lab built from scratch — server deployment, agent enrollment, network sensor integration, custom detection rule engineering, and live attack simulation. Every finding is real; negative results are documented honestly alongside positive ones.

---

## Lab Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Home LAN (192.168.1.0/24)               │
│                                                             │
│  [Wazuh 4.14.5 Docker]     [Pop!_OS Agent]                  │
│   192.168.1.50              192.168.1.105                   │
│   Manager + Indexer +       popos-mainpc                    │
│   Dashboard                 auditd active                   │
│                                                             │
│  [HP ZBook Agent]          [Attacker VM]                    │
│   192.168.1.108             192.168.1.106                   │
│   zbook-arch (Arch)         zeno (Arch, VirtualBox)         │
│   auditd + identity rules   nmap / hydra / scapy            │
│                                                             │
│  [Raspberry Pi 4]                                           │
│   192.168.1.104                                             │
│   rpi-sensor                                                │
│   Wazuh agent + Suricata 6.0.1 (ET Open, 50k+ rules)       │
│   Network sensor on wlan0                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## What Was Built

| Phase | Deliverable | Status |
|---|---|---|
| 0-1 | Wazuh 4.14.5 Docker single-node server | ✅ Done |
| 2 | 3 agents enrolled (popos-mainpc, zbook-arch, rpi-sensor) | ✅ Done |
| 3 | Live attack chain (scan, brute force, compromise, file access) | ✅ Done |
| 4 | 7 custom MITRE-tagged detection rules, deployed + proven | ✅ Done |
| 5 | Investigation playbooks (scan, brute force/compromise) | ✅ Done |
| 7 | Raspberry Pi 4 as Suricata network sensor | ✅ Done |

---

## Custom Detection Rules

All rules in `rules/local_rules.xml`. Each traces to a documented Phase 3 finding.

| Rule ID | Description | Level | MITRE | Live-fire result |
|---|---|---|---|---|
| 100015 | Suricata ET SCAN / Nmap → Level 12 | 12 | T1046 | ✅ 25 alerts |
| 100016 | Scan burst (8+ from same source in 60s) | 12 | T1046 | ✅ Fired |
| 100017 | SSH brute force escalated | 12 | T1110 | ✅ 6 alerts |
| 100018 | SSH brute force + success = compromise | 14 | T1110, T1078 | ✅ Fired |
| 100019 | Sensitive identity file accessed (auditd) | 12 | T1003, T1098 | ✅ Fired |
| 100020 | VNC port 5900 exposed | 10 | T1021.005 | ⚠️ Shadow-blocked (see 100021) |
| 100021 | VNC targeted during a network scan | 12 | T1021.005 | ✅ Fired |

Custom Suricata rule: `sid:9000020` — VNC RFB protocol detection (ET Open has no VNC signatures). Deployed to `/var/lib/suricata/rules/local.rules` on rpi-sensor. See `docs/Custom_Suricata_Rules.md`.

---

## Phase 3 Attack Chain Results (2026-06-18)

Full chain run from attacker VM `zeno` (192.168.1.106) against `rpi-sensor` (192.168.1.104).

| Attack | Tool | Result | Rule fired |
|---|---|---|---|
| A1 — loud scan | `nmap -sV -A` | **DETECTED** — 25 alerts | 100015 (L12) |
| A2 — stealth scan | `nmap -sS -T1` | **EVADED** — zero alerts (headline gap finding) | none |
| B1 — brute force burst | `hydra` 30 attempts | **DETECTED** — 6 alerts | 100017 (L12) |
| B2 — compromise | `hydra -t 1` + valid cred | **DETECTED** | 100018 (L14) |
| C — identity file access | `sudo cat /etc/shadow` | **DETECTED** — 31,751 alerts* | 100019 (L12) |
| VNC probe | `nmap -Pn -p 5900` | **DETECTED** | 100021 (L12) |

*100019 was over-tuned (passwd read watch); fixed post-live-fire. See `incidents/phase3_ssh_bruteforce_report.md`.

**Negative results are findings, not failures:** the stealth scan evasion and the 100018 race condition under parallel hydra are real-world detection limitations — documented honestly as they directly support the thesis realizability argument.

---

## Incident Reports

| Report | Finding |
|---|---|
| `incidents/phase3_threat_sim_report.md` | PH3-001: Loud nmap scan detected end-to-end |
| `incidents/phase3_stealth_scan_gap_report.md` | PH3-003: Stealth scan full evasion — 100% detection drop |
| `incidents/phase3_ssh_bruteforce_report.md` | PH3-002: SSH brute force + compromise proven; parallel race condition documented |

---

## Investigation Playbooks

| Playbook | Covers |
|---|---|
| `phases/phase5_playbooks/playbook_scan_detection.md` | How to triage 100015/100016/100021 alerts |
| `phases/phase5_playbooks/playbook_bruteforce_compromise.md` | How to triage 100017/100018; P1 compromise response |

---

## Screenshots

All 21 evidence screenshots in `portfolio/screenshots/phase4/`, grouped by attack stage. Filenames are self-describing (rule ID, hit count, alert level, MITRE technique).

**Pre-attack baseline**
| Screenshot | What it shows |
|---|---|
| `phase3_pi_fastlog_pre_attack_noise.png` | Suricata fast.log baseline noise before any attack |
| `phase3_attack_A1_runner_start_preflight.png` | Attack runner preflight — environment ready |

**A1 — loud scan (`nmap -sV -A`, detected)**
| Screenshot | What it shows |
|---|---|
| `phase3_attack_A1_nmap_loud_running.png` | Loud nmap scan in progress from attacker `zeno` |
| `phase3_attack_A1_pi_fastlog_ET_SCAN_nmap_detected.png` | Suricata ET SCAN signature catches the nmap probe |
| `phase3_attack_A1_pi_fastlog_nmap_useragent_full.png` | Full nmap user-agent string in Suricata log |
| `phase4_dashboard_100015_100016_fired_25hits_level12.png` | Loud scan detected — 25 Level-12 alerts (100015/100016) |
| `phase4_dashboard_events_100015_100016_descriptions.png` | Dashboard event view — 100015/100016 rule descriptions |

**A2 — stealth scan (`nmap -sS -T1`, EVADED — headline gap)**
| Screenshot | What it shows |
|---|---|
| `phase3_attack_A2_stealth_scan_starting.png` | Stealth SYN scan starting — produced zero alerts (full evasion) |

**B1/B2 — SSH brute force + compromise**
| Screenshot | What it shows |
|---|---|
| `phase4_dashboard_100017_brute_force_6hits_level12_MITRE_T1110.png` | SSH brute force detected — 6 alerts (100017, T1110) |
| `phase4_dashboard_100018_compromise_FIRED_level14_MITRE_T1110_T1078.png` | Compromise detected — Level 14 (100018, T1110+T1078) |
| `phase4_dashboard_100018_first_attempt_miss_parallel_timing.png` | 100018 miss on `hydra -t 4` parallel race (negative result) |

**C — identity file access (auditd)**
| Screenshot | What it shows |
|---|---|
| `phase4_dashboard_100019_file_access_31751hits_over_tuned.png` | 100019 firing — 31,751 hits, over-tuning visible |
| `phase4_dashboard_100019_file_access_29688hits_level12.png` | 100019 file-access alerts (earlier count) |
| `phase4_auditd_100019_passwd_watch_retuned_wa_only_flood_killed.png` | Auditd passwd watch retuned `rwa`→`wa` — flood fixed |

**VNC — rule shadowing + two-part fix**
| Screenshot | What it shows |
|---|---|
| `phase4_dashboard_100020_NO_RESULTS_rule_shadowing_root_cause.png` | 100020 no results — rule shadowing root cause |
| `phase4_dashboard_100020_VNC_NO_RESULTS_gap_finding.png` | VNC gap finding — 100020 silent |
| `phase4_dashboard_100020_VNC_STILL_GAP_ET_no_VNC_signatures.png` | Confirmed: ET Open ships no VNC signatures |
| `phase4_suricata_custom_VNC_rule_sid9000020_added_to_rules_file.png` | Custom Suricata rule sid:9000020 added to local.rules |
| `phase4_pi_fastlog_custom_sid9000020_VNC_FIRED.png` | Custom Suricata VNC rule firing on the Pi |
| `phase4_logtest_100021_VNC_scan_port5900_decode_confirmed.png` | wazuh-logtest confirms 100021 decode on port 5900 |
| `phase4_dashboard_100021_VNC_FIRED_level12_MITRE_VNC_rpi_sensor.png` | VNC detection working after two-part fix (100021, L12) |

---

## Key Technical Decisions

- **Wazuh field names differ between logtest and dashboard:** `data.src_ip` in the dashboard vs `src_ip` in rule matching — confirmed by running `wazuh-logtest` with real eve.json lines.
- **Rule shadowing:** two rules with the same `<if_sid>` — the first defined always wins. Companion rules for sub-cases must chain off the winning rule.
- **auditd `-p r` on world-readable files floods the queue:** only root-only files (shadow, sudoers, gshadow) should have read alerting.
- **ET Open has no VNC signatures:** custom Suricata rule required. Placed in `local.rules` (not `suricata.rules`) so `suricata-update` cannot overwrite it.
- **Fast parallel brute force can bypass frequency-based rules:** `hydra -t 4` outpaced the 120s failure-count window in 100018. Documented as a known limitation.

---

## Thesis Connection

This lab provides concrete problem-space realizability evidence for the thesis on Adversarial ML Hardening for NIDS:

- The stealth scan evasion is a measured, on-wire instance of the feature-space vs problem-space detection gap
- The brute force + compromise chain is a real credential-access attack under genuine TCP/IP + auth-protocol constraints
- The Raspberry Pi 4 is the actual ARM edge deployment target for the journal's edge-compression claim
- nProbe Enterprise S (licensed June 2026) will provide NetFlow feature extraction bridging lab PCAPs to the NF-UQ-NIDS-v2 training distribution

See `docs/Realizability_Lab_Feasibility.md` and `notes/` for full thesis connection records.
