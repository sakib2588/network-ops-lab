# Project Status — Wazuh SOC Home Lab

**Last updated:** 2026-06-13  
**Current phase:** Phase 3 (Threat Simulation) + Phase 7 (RPi) in parallel  
**Overall completion:** ~30%

---

## What Is Done

- [x] Ubuntu 24.04 installed on laptop (Wazuh Server)
- [x] Wazuh server deployed and running
- [x] PC 1 (Ubuntu) — Wazuh agent connected
- [x] PC 2 (Windows) — Wazuh agent connected
- [x] PC 1 Windows side — agent configured
- [x] 4 nodes visible in Wazuh dashboard
- [x] Basic log ingestion confirmed

---

## What Is In Progress

- [ ] Raspberry Pi 4 setup — Ubuntu Server + Suricata + Wazuh agent (target: June 21)
- [ ] Phase 3: First threat simulation (nmap scan from RPi to other nodes)

---

## What Is Next (Phase 3 — Threat Simulation)

Target: June 28, 2026 (2 weeks)

- [ ] Run nmap scan from RPi against PC 1 and PC 2
- [ ] Verify Wazuh catches the scan (alert visible on dashboard)
- [ ] Run hydra SSH brute force against PC 1 (Linux)
- [ ] Test Metasploit basic module against a test VM
- [ ] Simulate 5 MITRE ATT&CK techniques — document each
- [ ] Screenshot all alerts — save to `portfolio/screenshots/`
- [ ] Write Phase 3 incident report → `incidents/phase3_threat_sim_report.md`

---

## Upcoming Phases (brief)

| Phase | Target Date | Key Deliverable |
|---|---|---|
| Phase 4: Detection Engineering | July 18 | 5+ custom Wazuh rules written |
| Phase 5: Investigation Playbooks | Aug 1 | 3 incident reports done |
| Phase 6: Portfolio + GitHub | Aug 20 | Public GitHub repo ready |
| Phase 7: RPi Network Sensor | June 21 | Suricata running, alerts in Wazuh |

---

## Known Issues / Blockers

None currently.

---

## Thesis Connection Log

| Date | Activity | Thesis Relevance |
|---|---|---|
| June 2026 | RPi + Suricata setup | Demonstrates real network-layer detection (problem-space realizability) |
| TBD | Attack simulation from RPi | Shows feature-space vs network-space attack gap |
| TBD | Cowrie honeypot logs | Real adversarial traffic under TCP/IP constraints |
