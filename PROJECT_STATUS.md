# Project Status — Wazuh SOC Home Lab

**Last updated:** 2026-06-19  
**Current phase:** Phase 3 + Phase 4 COMPLETE; **Windows endpoint now enrolled — 4-OS fleet live.** Phase 8 (Windows endpoint detection: Sysmon + Atomic Red Team) PLANNED, not yet executed.  
**Overall completion:** ~90% (server + 4 Active agents across 4 OS — Pop!_OS, Arch, Debian/Pi, Windows — plus Suricata sensor; Phase 3 + 4 live-fire proven; remaining = Phase 8 Windows detections + Phase 5 playbook write-ups + portfolio screenshots)

> **Reality check:** the original Wazuh server (VirtualBox VM) is gone. As of 2026-06-17 the
> server is **rebuilt and live** as Docker single-node (Wazuh 4.14.5) on the 12 GB Arch laptop
> at `https://192.168.1.50` (static IP). Dashboard, indexer (green), and manager API->dashboard
> connection all verified up; default passwords rotated. **3 nodes now enrolled and Active**
> (`zbook-arch`, `popos-mainpc`, `rpi-sensor`), with `rpi-sensor` also running Suricata as a
> network sensor feeding alerts into Wazuh. Full build + troubleshooting write-up:
> `docs/Server_Rebuild_Journal_2026-06-17.md`.

> **Update 2026-06-19 (verified via dashboard + nmap sweep):** the fleet is now **4 Active
> agents across 4 operating systems** — a Windows 10 Pro endpoint (`User-hp`, agent 007,
> 192.168.1.104) joined `popos-mainpc` (Pop!_OS, .105), `Ultran`/`zbook-arch` (Arch, .108),
> and `rpi-sensor` (Debian, now .101). The Windows agent runs concurrently with both Linux
> agents (all green at once), so it is a distinct host on the LAN, not a same-time dual-boot.
> The dashboard also shows **1 Disconnected agent** (TOP-5-OS counts windows=2 but only one
> Windows is Active) — likely a stale prior Windows enrollment; to be cleaned up.
> **IP note (DHCP shifted):** `rpi-sensor` is now at **192.168.1.101** (this doc previously
> listed it at .104; that address now belongs to the Windows box). Verified by nmap: .101 =
> SSH + Pi-hole + VNC (the Pi), .104 = all-filtered Windows. `popos-mainpc` agent is on
> v4.14.4 (dashboard red dot) and is being upgraded to v4.14.5 to match the manager.

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
- [x] **Identity file-integrity watches hardened 2026-06-18 (on `zbook-arch`):** added
      `/etc/audit/rules.d/identity.rules` with a dedicated `identity` key covering all four
      identity files -- `shadow`, `sudoers`, `passwd`, `gshadow`. shadow/sudoers/gshadow use
      `rwa` (reads of these are inherently suspicious); `passwd` uses `wa` only, because `r` on
      passwd floods the log (every `getpwnam` from sudo/login/etc. fires a record -- a single
      `sudo` produced 3+ passwd reads in testing). Removed the now-duplicate `wa` watches from
      `wazuh-soc.rules` (which had collided on load with a "Rule exists" error and left stacked
      `wa`+`rwa` watches); that file now carries only the `execve` exec rule. Verified end to end:
      `sudo cat /etc/shadow` produced a `type=SYSCALL syscall=257 (openat) success=yes
      comm="sudo" key="identity"` record for `/etc/shadow` in `ausearch -k identity`, confirming
      the watch fires and reaches the audit log (and therefore Wazuh).
      Note: the original task brief labeled this box "pop-os" -- it is actually `zbook-arch`
      (Arch Linux, hostname `Ultran`, 192.168.1.108). `popos-mainpc` is a separate box (already
      enrolled as Agent 2, see below); the same identity watches were also applied there
      (user-reported) but are not yet independently re-verified in this log.
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
      same machine).
- [x] **Phase 4 rules DEPLOYED + logtest-validated 2026-06-17:** all 6 rules (100015-100020)
      copied to `/var/ossec/etc/rules/local_rules.xml` on `single-node-wazuh.manager-1`,
      manager restarted, every rule confirmed firing in `wazuh-logtest`. Deploy surfaced and
      fixed several field/parent mismatches vs the drafted version (Suricata fields are root-
      level `src_ip`/`dest_port`/`alert.signature`, NOT `data.*`; sshd valid-user failures are
      `5760` not `5716` so brute force chains off built-in composites `5712`/`5763`; auditd
      parent is `80700` not `2902`; Suricata correlation uses `same_field` since it has no
      `srcip`). Full journal: `docs/Detection_Engineering_Journal_2026-06-17.md`.
- [x] **Phase 3 FULL ATTACK CHAIN live-fired 2026-06-18 — all 7 rules proven on dashboard:**
      A1 (loud scan → 100015 fired, 25 alerts Level 12, MITRE T1046), A2 (stealth scan →
      ZERO alerts — confirmed detection gap, documented in `incidents/phase3_stealth_scan_gap_report.md`),
      B1 (hydra 30-attempt burst → 100017 fired, 6 alerts Level 12, MITRE T1110), B2
      (compromise path, sequential `-t 1` → 100018 fired, Level 14, MITRE T1110+T1078), C
      (auditd identity access → 100019 fired 31,751 alerts Level 12 — over-tuned, known issue).
      VNC detection gap resolved via two-part fix: (1) custom Suricata rule `sid:9000020` added
      to `/var/lib/suricata/rules/suricata.rules` on the Pi (ET Open has no VNC signatures);
      (2) new Wazuh rule **100021** added (chains off 100015, triggers when scan hits port 5900)
      — 100020 was shadow-blocked by 100015 (same `if_sid:86601`). All 3 incident reports
      complete: `incidents/phase3_threat_sim_report.md`, `phase3_stealth_scan_gap_report.md`,
      `phase3_ssh_bruteforce_report.md`. Screenshots: `portfolio/screenshots/phase4/`.
      **Negative results documented honestly:** A2 full evasion; 100018 miss on `-t 4` parallel;
      100019 over-tuning (31k+ hits from broad auditd watch); 100020 rule shadowing by 100015.
- [x] **Agent 4 — Windows 10 endpoint enrolled (confirmed Active 2026-06-19):** `User-hp`
      (agent 007, Windows 10 Pro, 192.168.1.104), Wazuh agent v4.14.5, green on the dashboard.
      This closes the long-pending "Windows endpoint coverage" item. The lab now spans **4 OS**
      (Pop!_OS, Arch, Debian/Pi, Windows). Endpoint telemetry (Sysmon) is NOT yet configured —
      that is Phase 8 (planned).
- [x] **Lab recon sweep 2026-06-19 (nmap, documents the as-built attack surface):** discovery +
      service scan of 192.168.1.0/24. Findings: only the **Pi (.101)** exposes inbound services
      (OpenSSH 8.4p1 patched, dnsmasq/Pi-hole, RealVNC RA2 RSA-AES, lighttpd admin returning 403
      with hardened CSP headers); **Windows (.104) and Arch (.108) are fully firewalled — every
      port filtered** (correct default-deny posture, no network attack surface). Mystery host .103
      identified as a phone (randomized/locally-administered MAC, no listening services). Takeaway:
      no unauthenticated RCE anywhere — an attacker must win credentials; VNC and lighttpd auth
      logs are NOT yet monitored (future detection-engineering gap).
- [x] **Phase 8 plan authored 2026-06-19 (NOT executed):** full implementation plan for Windows
      endpoint detection at `phases/phase8_windows_endpoint_detection/PLAN.md` — Sysmon
      (SwiftOnSecurity config) + Wazuh `Microsoft-Windows-Sysmon/Operational` collection + two
      MITRE-tagged rules (100022 T1059.001 PowerShell EncodedCommand, 100023 T1003.001 LSASS dump
      via comsvcs), each proven with a RED/GREEN detection-TDD cycle and an Atomic Red Team test.

---

## What Is In Progress

- [x] **Windows agent — DONE 2026-06-19.** A Windows 10 Pro endpoint (`User-hp`, agent 007, .104) is enrolled and Active. Note: it came up as a **distinct host** running concurrently with the Pop!_OS and Arch agents (all green simultaneously), NOT as a same-time dual-boot of `popos-mainpc`. The old dual-boot framing is superseded by reality. **Next on this box = Phase 8 (Sysmon endpoint telemetry + detections).**
- [x] **Raspberry Pi 4 setup -- DONE 2026-06-17** (ahead of the June 21 target): Suricata + Wazuh agent live on `rpi-sensor`. See Phase 7 below.
- [x] **Phase 3 COMPLETE 2026-06-18** — see "What Is Done" above. All rules live-fire proven.

---

## What Is Next (Phase 5 — Investigation Playbooks + Portfolio)

Target: July 18, 2026

- [x] **Write investigation playbook for scan detection (100015 / stealth gap)** — DONE: `phases/phase5_playbooks/playbook_scan_detection.md` (PB-001, 8 sections, triage + stealth-gap + containment + escalation)
- [x] **Write investigation playbook for brute force / compromise (100017 / 100018)** — DONE: `phases/phase5_playbooks/playbook_bruteforce_compromise.md` (PB-002, 9 sections, P1 compromise response + parallel-race limitation)
- [x] **Tune rule 100019** — DONE (passwd watch `rwa`→`wa`, flood killed; PR #14)
- [x] **Windows agent — DONE 2026-06-19** (`User-hp`, agent 007, .104, Active). Endpoint coverage achieved; detections are Phase 8.
- [x] **Clean up `labvictim` account** — CONFIRMED GONE (`userdel -r` returned "user does not exist")
- [x] **Portfolio README polish** — DONE: attack-chain results table + full 21-image screenshots index in `portfolio/README.md`
- [ ] **Phase 8 — Windows endpoint detection (Sysmon + ART):** plan written `phases/phase8_windows_endpoint_detection/PLAN.md`; execution pending (rules 100022-100023, T1059.001 + T1003.001).
- [ ] **Upgrade `popos-mainpc` agent v4.14.4 → v4.14.5** to clear the dashboard version-drift red dot (in progress).
- [ ] **Investigate the 1 Disconnected agent** (stale prior Windows enrollment — remove if dead).
- [ ] (optional) nProbe NetFlow export → Wazuh / thesis PCAP pipeline (nProbe installed + licensed, not started)

---

## Upcoming Phases (brief)

| Phase | Target Date | Key Deliverable | Status |
|---|---|---|---|
| Phase 4: Detection Engineering | July 18 | 5+ custom Wazuh rules written, deployed, proven firing | ✅ DONE 2026-06-18 — 7 rules (100015-100021) live-fire proven; custom Suricata sid:9000020 deployed |
| Phase 5: Investigation Playbooks | Aug 1 | 3 incident reports done | ✅ 3 complete (PH3-001, PH3-002, PH3-003); playbook write-ups pending |
| Phase 6: Portfolio + GitHub | Aug 20 | Public GitHub repo ready | 🟡 README + diagram refreshed; screenshots pending |
| Phase 7: RPi Network Sensor | June 21 | Suricata live on `rpi-sensor`, alerts in Wazuh (host + network) | ✅ DONE 2026-06-17 |
| Phase 8: Windows Endpoint Detection | TBD | Sysmon telemetry + rules 100022-100023 (T1059.001, T1003.001) proven firing | 🟡 PLAN written 2026-06-19; execution pending |

---

## Known Issues / Blockers

- **100020 permanently shadow-blocked:** rule 100020 (`if_sid:86601`) will never fire for scan events because 100015 matches first on the same parent. Rule 100021 is the working replacement. 100020 can be removed from `local_rules.xml` in a future cleanup PR (low priority — it still fires for genuine non-scan VNC flows).
- **DHCP IP drift (2026-06-19):** agent IPs are not static. `rpi-sensor` moved .104 → **.101**; the Windows box took **.104**. Older docs/diagrams referencing `rpi-sensor` at .104 are stale. Consider DHCP reservations on the router so node IPs stop moving.
- **1 Disconnected agent:** dashboard shows windows=2 in TOP-5-OS but only one Windows Active — a stale prior Windows enrollment is lingering. Remove it from the manager if confirmed dead.
- **`popos-mainpc` agent version drift:** running v4.14.4 vs manager v4.14.5 (dashboard red dot). Upgrade in progress.

## Resolved Issues (closed 2026-06-18)

- ~~**100019 over-tuning:**~~ **FIXED** — `/etc/passwd` watch changed from `-p rwa` to `-p wa` on `zbook-arch`. Passwd reads are benign system activity; only writes now trigger alerts. See PR #14.
- ~~**labvictim account on rpi-sensor:**~~ **CONFIRMED GONE** — `sudo userdel -r labvictim` returned "user does not exist" confirming it was already removed.

---

## Thesis Connection Log

| Date | Activity | Thesis Relevance |
|---|---|---|
| 2026-06-17 | RPi + Suricata setup **DONE** | Real network-layer detection live (problem-space realizability); the Pi is the ARM edge device for the journal's edge-deployment claim |
| TBD | Attack simulation from RPi | Shows feature-space vs network-space attack gap |
| TBD | Cowrie honeypot logs | Real adversarial traffic under TCP/IP constraints |
