# Project Status — Wazuh SOC Home Lab

**Last updated:** 2026-06-17  
**Current phase:** Server live + first agent enrolled — next: enroll a 2nd agent (gate), then Phase 3 + Phase 7 (RPi)  
**Overall completion:** ~40% (Wazuh server live; 1 of >=2 agents Active)

> **Reality check:** the original Wazuh server (VirtualBox VM) is gone. As of 2026-06-17 the
> server is **rebuilt and live** as Docker single-node (Wazuh 4.14.5) on the 12 GB Arch laptop
> at `https://192.168.1.50` (static IP). Dashboard, indexer (green), and manager API->dashboard
> connection all verified up; default passwords rotated. Agents are NOT yet re-enrolled, so
> "agents registered" is still 0 until Task 5 of the runbook runs. Full build + troubleshooting
> write-up: `docs/Server_Rebuild_Journal_2026-06-17.md`.

---

## What Is Done

- [x] Original Wazuh lab built once (VM-based) -- Phases 0-2 reached, now migrated away from
- [x] Signature project script written (`docs/Signature_Project_Detection_Gap.md`)
- [x] **Step 0 (server side) — Wazuh server rebuilt 2026-06-17:** Docker single-node 4.14.5 on
      the Arch laptop. Docker data-root + containerd root both moved to `/home` (ext4, ~129 GB
      free) so images/volumes stay off the cramped 32 GB `/`. Dashboard at `https://192.168.1.50`
      (static IP), indexer (cluster green), and the dashboard->manager API connection all verified
      up; stack set to `restart: always` and `docker.service` enabled, so it survives reboot.
      Default credentials rotated (login `admin`; internal API password kept strong). Full
      step-by-step + 7-incident troubleshooting log: `docs/Server_Rebuild_Journal_2026-06-17.md`.
      Build log on the laptop: `~/wazuh-build.log`.
- [x] **Agent 1 enrolled 2026-06-17 — `zbook-arch`:** the HP ZBook (Arch Linux, 31 GB, IP
      192.168.1.108). Installed `wazuh-agent 4.14.5-1` from the AUR (matches manager version),
      pointed at `192.168.1.50`, registered via `agent-auth` ("Valid key received"). Service
      Active, ESTABLISHED TCP to `192.168.1.50:1514`, visible green on the dashboard. Field
      notes (the gotchas that actually bit) appended to `docs/Agent_Enrollment_Handover.md`.

---

## What Is In Progress

- [ ] Re-enroll agents -- gate: dashboard reachable (DONE), >=2 agents Active (1/2: `zbook-arch` Active; need 1 more)
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
