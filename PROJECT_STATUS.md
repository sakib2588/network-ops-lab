# Project Status — Wazuh SOC Home Lab

**Last updated:** 2026-06-16  
**Current phase:** Rebuilding the lab (Step 0), then Phase 3 (Threat Simulation) + Phase 7 (RPi)  
**Overall completion:** ~25% (server being migrated)

> **Reality check:** the original Wazuh server lived on a VirtualBox VM that is now powered
> off. The server is being rebuilt as Docker single-node on the 12 GB Arch laptop, then agents
> re-enrolled. Follow `docs/Server_Migration_Runbook.md`. Earlier "4 nodes Active" status
> referred to the old VM and no longer holds until the rebuild gate passes.

---

## What Is Done

- [x] Original Wazuh lab built once (VM-based) -- Phases 0-2 reached, now being migrated
- [x] Old VM preserved as rollback (`phase_2_complete` snapshot)
- [x] Signature project script written (`docs/Signature_Project_Detection_Gap.md`)

---

## What Is In Progress

- [ ] Step 0: Rebuild Wazuh server (Docker on Arch laptop) per `docs/Server_Migration_Runbook.md`
- [ ] Re-enroll agents -- gate: dashboard reachable, >=2 agents Active
- [ ] Raspberry Pi 4 setup -- Suricata + Wazuh agent (target: June 21)
- [ ] Phase 3: Signature project attack chain (see `docs/Signature_Project_Detection_Gap.md`)

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
