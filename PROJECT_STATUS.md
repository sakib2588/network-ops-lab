# Project Status — Wazuh SOC Home Lab

**Last updated:** 2026-06-18  
**Current phase:** Phase 3 + Phase 4 COMPLETE — all 7 custom detection rules deployed and proven firing by live attacks; 3 incident reports complete; custom Suricata VNC rule + Wazuh rule 100021 engineered and confirmed end-to-end  
**Overall completion:** ~88% (server + 3 nodes + Suricata sensor live; Phase 3 full attack chain complete; Phase 4 all rules live-fire proven; remaining = Windows dual-boot agent + portfolio polish + playbook write-ups)

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

---

## What Is In Progress

- [ ] **Windows agent via dual-boot** -- the `popos-mainpc` box is dual-boot; the Pop!_OS side is already an Active Linux agent. Boot the SAME machine into Windows 10 and install the Wazuh Windows agent for endpoint coverage. There is NO separate "PC 2" box (the old `pc1-ubuntu` / `pc2-win10` plan is retired -- it was the same physical machine).
- [x] **Raspberry Pi 4 setup -- DONE 2026-06-17** (ahead of the June 21 target): Suricata + Wazuh agent live on `rpi-sensor`. See Phase 7 below.
- [x] **Phase 3 COMPLETE 2026-06-18** — see "What Is Done" above. All rules live-fire proven.

---

## What Is Next (Phase 5 — Investigation Playbooks + Portfolio)

Target: July 18, 2026

- [ ] Write investigation playbook for scan detection (100015 / stealth gap)
- [ ] Write investigation playbook for brute force / compromise (100017 / 100018)
- [ ] Tune rule 100019 (over-tuning: tighten auditd watch to `rwa` on shadow/sudoers/gshadow only; remove broad passwd read watch causing 31k+ alerts)
- [ ] Windows dual-boot agent on `popos-mainpc` (boot Windows 10 side, install Wazuh agent)
- [ ] Clean up `labvictim` account: `sudo userdel -r labvictim` on rpi-sensor
- [ ] Portfolio README polish — add attack chain results table, screenshots index

---

## Upcoming Phases (brief)

| Phase | Target Date | Key Deliverable | Status |
|---|---|---|---|
| Phase 4: Detection Engineering | July 18 | 5+ custom Wazuh rules written, deployed, proven firing | ✅ DONE 2026-06-18 — 7 rules (100015-100021) live-fire proven; custom Suricata sid:9000020 deployed |
| Phase 5: Investigation Playbooks | Aug 1 | 3 incident reports done | ✅ 3 complete (PH3-001, PH3-002, PH3-003); playbook write-ups pending |
| Phase 6: Portfolio + GitHub | Aug 20 | Public GitHub repo ready | 🟡 README + diagram refreshed; screenshots pending |
| Phase 7: RPi Network Sensor | June 21 | Suricata live on `rpi-sensor`, alerts in Wazuh (host + network) | ✅ DONE 2026-06-17 |

---

## Known Issues / Blockers

- **100020 permanently shadow-blocked:** rule 100020 (`if_sid:86601`) will never fire for scan events because 100015 matches first on the same parent. Rule 100021 is the working replacement. 100020 can be removed from `local_rules.xml` in a future cleanup PR (low priority — it still fires for genuine non-scan VNC flows).

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
