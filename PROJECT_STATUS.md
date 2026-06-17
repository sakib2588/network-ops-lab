# Project Status — Wazuh SOC Home Lab

**Last updated:** 2026-06-17  
**Current phase:** Phase 3 threat simulation IN PROGRESS + Phase 4 detection engineering STARTED — 6 custom Wazuh rules drafted and committed (PR #9 merged 2026-06-17); next: deploy the rules to the manager, validate with `wazuh-logtest`, and prove each fires by running the remaining attack chain  
**Overall completion:** ~70% (server + 3 nodes + Suricata sensor live; Phase 3 first detection done; Phase 4 rules written + README/diagram refreshed; remaining 20% = deploy+prove the rules and run the stealth-scan + brute-force attacks to fill the 2 drafted reports)

> **Reality check:** the original Wazuh server (VirtualBox VM) is gone. As of 2026-06-17 the
> server is **rebuilt and live** as Docker single-node (Wazuh 4.14.5) on the 12 GB Arch laptop
> at `https://192.168.1.50` (static IP). Dashboard, indexer (green), and manager API->dashboard
> connection all verified up; default passwords rotated. **3 nodes now enrolled and Active**
> (`zbook-arch`, `popos-mainpc`, `rpi-sensor`), with `rpi-sensor` also running Suricata as a
> network sensor feeding alerts into Wazuh. Full build + troubleshooting write-up:
> `docs/Server_Rebuild_Journal_2026-06-17.md`.

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
- [x] **Agent 1 enrolled 2026-06-17 — `zbook-arch`:** the HP ZBook (Arch Linux, 32 GB, IP
      192.168.1.108). Installed `wazuh-agent 4.14.5-1` from the AUR (matches manager version),
      pointed at `192.168.1.50`, registered via `agent-auth` ("Valid key received"). Service
      Active, ESTABLISHED TCP to `192.168.1.50:1514`, visible green on the dashboard. Field
      notes (the gotchas that actually bit) appended to `docs/Agent_Enrollment_Handover.md`.
      Telemetry enabled (no longer "quiet"): `auditd` installed + enabled with 4 audit rules
      (execve command exec, plus `wa` watches on sudoers/passwd/shadow), and `ossec.conf` set to
      ingest `/var/log/audit/audit.log` so command-execution and identity events reach the SIEM.
- [x] **Agent 2 enrolled 2026-06-17 — `popos-mainpc`:** the always-on Pop!_OS 24.04 main PC
      (16 GB, IP 192.168.1.105 — also the day-to-day workstation). Installed `wazuh-agent 4.14.5-1`
      (amd64 `.deb`, Section 3 method), pointed at `192.168.1.50`. Service Active, ESTABLISHED TCP
      to `192.168.1.50:1514` (verified stable, ~12 MB shipped + acked), green on the dashboard.
      Made non-quiet (P10): `auditd` active + Wazuh ingesting `/var/log/audit/audit.log`. Field
      notes appended to `docs/Agent_Enrollment_Handover.md`.
- [x] **Agent 3 enrolled + Phase 7 sensor LIVE 2026-06-17 — `rpi-sensor`:** Raspberry Pi 4
      (aarch64, Raspberry Pi OS / Debian 11, IP 192.168.1.104 on Wi-Fi `wlan0` — eth0 is
      NO-CARRIER, deferred). `wazuh-agent 4.14.5-1` (arm64 `.deb`) Active to `192.168.1.50:1514`.
      **Suricata 6.0.1** (Debian repo) capturing on `wlan0` with 50,685 ET Open rules; `eve.json`
      forwarded into Wazuh and confirmed end-to-end (alerts visible on the dashboard under
      `agent.name:rpi-sensor`). The lab now has **host + network** detection. Full as-built runbook
      + gotchas: `phases/phase7_raspberry_pi/Phase7_Suricata_LIVE_Runbook.md`; field notes in
      `docs/Agent_Enrollment_Handover.md`.
- [x] **Phase 4 detection rules drafted + README refreshed 2026-06-17 (PR #9 merged):** wrote 6
      custom MITRE-tagged Wazuh rules in `rules/local_rules.xml` (100015-100020), each tracing to a
      measured Phase 3 gap — scan escalated to Level 12 (100015), stealth-scan burst (100016), SSH
      brute force (100017), brute-force-then-success/compromise (100018), identity-file access via
      auditd (100019), exposed VNC (100020). Added the Phase 4 deploy/prove workflow
      (`phases/phase4_detection_engineering/README.md`) and the live-attack runbook
      (`phases/phase3_threat_simulation/NEXT_SESSION_RUNBOOK.md`). README architecture diagram +
      inventory rebuilt to current reality (3 Active agents + attacker; Pi shown as both Suricata
      sensor AND host agent; dual-boot box = Pop!_OS Linux agent now, Windows agent planned on the
      same machine). Rules are written but NOT yet deployed/proven — that is the next step.

---

## What Is In Progress

- [ ] **Windows agent via dual-boot** -- the `popos-mainpc` box is dual-boot; the Pop!_OS side is already an Active Linux agent. Boot the SAME machine into Windows 10 and install the Wazuh Windows agent for endpoint coverage. There is NO separate "PC 2" box (the old `pc1-ubuntu` / `pc2-win10` plan is retired -- it was the same physical machine).
- [x] **Raspberry Pi 4 setup -- DONE 2026-06-17** (ahead of the June 21 target): Suricata + Wazuh agent live on `rpi-sensor`. See Phase 7 below.
- [~] Phase 3: Threat simulation IN PROGRESS -- attacker VM built + **first detection CONFIRMED 2026-06-17**: `nmap -sV -A` from `zeno` (.106) against the Pi (.104) -> Suricata fired `ET SCAN Possible Nmap User-Agent` (Priority 1) + protocol-anomaly alerts -> visible in Wazuh under `agent.name:rpi-sensor` (event spike, MITRE: Remote Services). Report: `incidents/phase3_threat_sim_report.md`; setup: `phases/phase3_threat_simulation/Attacker_VM_and_Phase3_Kickoff.md`. Remaining: hydra brute force, more MITRE techniques, stealth `-sS` gap test, more incident reports.

---

## What Is Next (Phase 3 — Threat Simulation)

Target: June 28, 2026 (2 weeks)

- [x] **Run a scan against a target + verify Wazuh catches it — DONE 2026-06-17:** `nmap -sV -A` from attacker `zeno` (.106) -> Pi (.104); detected (ET SCAN Nmap, Priority 1 + protocol anomalies) and confirmed on the dashboard.
- [x] **Write the first Phase 3 incident report** -> `incidents/phase3_threat_sim_report.md`
- [ ] Stealth-scan gap test (`-sS` only) -- measure the quieter-scan coverage gap. Report skeleton ready: `incidents/phase3_stealth_scan_gap_report.md` (fill the `[RUN]` blanks).
- [ ] hydra SSH brute force against a Linux target. Report skeleton ready: `incidents/phase3_ssh_bruteforce_report.md`.
- [ ] Simulate a few MITRE ATT&CK techniques -- document each
- [ ] Screenshot all alerts -> `portfolio/screenshots/rpi_phase3/` and `portfolio/screenshots/phase4/`
- [ ] Step-by-step run order for all of the above: `phases/phase3_threat_simulation/NEXT_SESSION_RUNBOOK.md`

---

## Upcoming Phases (brief)

| Phase | Target Date | Key Deliverable | Status |
|---|---|---|---|
| Phase 4: Detection Engineering | July 18 | 5+ custom Wazuh rules written, deployed, proven firing | 🟡 6 rules drafted (PR #9); deploy + prove pending |
| Phase 5: Investigation Playbooks | Aug 1 | 3 incident reports done | 🟡 1 done (PH3-001), 2 drafted (PH3-002/003) |
| Phase 6: Portfolio + GitHub | Aug 20 | Public GitHub repo ready | 🟡 README + diagram refreshed; screenshots pending |
| Phase 7: RPi Network Sensor | June 21 | Suricata live on `rpi-sensor`, alerts in Wazuh (host + network) | ✅ DONE 2026-06-17 |

---

## Known Issues / Blockers

None currently.

---

## Thesis Connection Log

| Date | Activity | Thesis Relevance |
|---|---|---|
| 2026-06-17 | RPi + Suricata setup **DONE** | Real network-layer detection live (problem-space realizability); the Pi is the ARM edge device for the journal's edge-deployment claim |
| TBD | Attack simulation from RPi | Shows feature-space vs network-space attack gap |
| TBD | Cowrie honeypot logs | Real adversarial traffic under TCP/IP constraints |
