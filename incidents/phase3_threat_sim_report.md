# Incident Report - Phase 3 First Detection: Network Scan (nmap) Against the Pi Sensor

**Report ID:** PH3-001
**Date:** 2026-06-17
**Analyst:** Nazmus Sakib
**Classification:** Lab exercise (authorized self-test) - reconnaissance / scanning
**Status:** Detected and confirmed end-to-end

---

## 1. Summary

A controlled network scan was launched from the lab's attacker VM against the Raspberry Pi sensor.
The Suricata network IDS on the Pi detected the scan, the alerts were forwarded to the Wazuh SIEM,
and they were confirmed visible on the dashboard attributed to the correct agent. This is the
lab's first full **attacker -> network sensor -> SIEM** detection. The report records exactly what
was run, what was detected, what was NOT, and the follow-up work it feeds.

---

## 2. Environment

| Role | Host | IP | Notes |
|---|---|---|---|
| Attacker | Arch VM `zeno` (user `ultron`) | 192.168.1.106 | VirtualBox, bridged to the LAN, SSH-driven from the laptop |
| Target / Sensor | `rpi-sensor` (Raspberry Pi 4) | 192.168.1.104 | Suricata 6.0.1 on `wlan0` + Wazuh agent 4.14.5 |
| SIEM | Wazuh manager (Docker single-node 4.14.5) | 192.168.1.50 | dashboard `https://192.168.1.50` |

All on one LAN (`192.168.1.0/24`). Authorized: all hosts are the analyst's own lab.

---

## 3. Attack executed

From the attacker (`192.168.1.106`):

```
sudo nmap -sV -A 192.168.1.104
```

- `-sV` service/version detection, `-A` OS detection + default NSE scripts + traceroute.
- Duration ~51 s; full TCP connect/version probing of the top 1000 ports.

### Recon result (attacker's view) - the Pi's exposed services
| Port | Service | Detail |
|---|---|---|
| 22/tcp | SSH | OpenSSH 8.4p1 Debian |
| 53/tcp | DNS | dnsmasq 2.92.2 (**Pi-hole**) |
| 80/tcp | HTTP | Pi-hole admin (lighttpd/WebDAV methods exposed) |
| 443/tcp | HTTPS | Pi-hole admin (self-signed cert `pi.hole`) |
| 5900/tcp | VNC | RealVNC Enterprise 5.x |
| - | OS | Linux 4.x-5.x, MAC `DC:A6:32` (Raspberry Pi) |

---

## 4. Detection (defender's view)

Suricata on the Pi flagged the scan in real time (`/var/log/suricata/fast.log`), and the events
reached Wazuh.

**Primary signature (fired repeatedly):**
```
[1:2024364:4] ET SCAN Possible Nmap User-Agent Observed
[Classification: Web Application Attack] [Priority: 1]
{TCP} 192.168.1.106 -> 192.168.1.104:80
```
Suricata recognized the nmap scanner's HTTP user-agent during version probing of the Pi-hole web
service - dozens of hits, Suricata **Priority 1** (highest).

**Supporting protocol-anomaly alerts** (triggered by the aggressive `-A` probing):
- `SURICATA Applayer Detect protocol only one direction`
- `SURICATA HTTP Response invalid protocol`
- `SURICATA ICMPv4 unknown code`
- `SURICATA Applayer Wrong direction first Data` / `Mismatch protocol both directions`
  (against the VNC service on 5900)

**SIEM confirmation (Wazuh dashboard, Threat Hunting, Last 15 min):**
- A clear event **spike at ~21:38** (~36 events in a 30-second bucket) coinciding with the scan.
- Source agent: **`rpi-sensor`**.
- MITRE ATT&CK auto-mapping: **Remote Services**, plus Valid Accounts / Sudo Caching from host
  auditd telemetry in the same window.

---

## 5. Honest assessment - what worked, what did not

**Worked:**
- The end-to-end pipeline: Suricata captured on `wlan0`, matched ET Open rules, forwarded
  `eve.json` to Wazuh, and the alerts were correctly attributed to `rpi-sensor` on the dashboard.
- The scan was unmistakable as a burst + Priority-1 nmap signature.

**Limitations / negative results (recorded honestly):**
- **No Wazuh "Level 12 or above" alerts fired (0).** Suricata rated the scan Priority 1, but the
  mapped Wazuh rule levels stayed moderate - so a pure severity-12 filter would have missed it.
  Phase 4 should tune rule levels / add a custom high-severity rule for scan bursts.
- **Detection depended largely on the HTTP-layer nmap user-agent**, not a generic SYN-scan
  counter. A stealthier scan (`-sS` only, no version probing) would be quieter - a gap to close
  with a threshold/port-scan rule in Phase 4.
- **Visibility is host-local.** The Pi is on Wi-Fi (`wlan0`), so it only sees traffic addressed to
  itself. It would NOT have detected this scan if aimed at another host. Passive full-LAN coverage
  needs the wired SPAN/TAP/inline-bridge upgrade.
- A temporary local ICMP rule (`LOCAL PING TEST`) used earlier to validate the pipeline was removed
  after this test to avoid SIEM noise.

---

## 6. Recommendations / follow-up

1. **Phase 4 detection engineering:** add a custom Wazuh/Suricata rule that raises severity on a
   scan burst (many distinct ports/sec from one source); tune levels so scans surface in a
   Level-12+ view.
2. **Harden the Pi's surface:** the scan exposed **VNC (5900)** and the Pi-hole web admin - restrict
   VNC to localhost / firewall it; ensure the Pi-hole admin is password-protected and LAN-only.
3. **Stealth-scan test:** repeat with `-sS` (no `-sV`) to measure the quieter-scan gap.
4. **Expand Phase 3:** hydra SSH brute force, a handful of MITRE techniques, each documented.
5. **Wired sensor upgrade** for passive multi-host visibility (Option B/C from the Phase 7 runbook).

---

## 7. Reproducibility

- Attacker: `sudo nmap -sV -A 192.168.1.104` from `192.168.1.106`.
- Observe (Pi): `sudo tail -f /var/log/suricata/fast.log`.
- Confirm (SIEM): Wazuh -> Threat Hunting -> `rule.groups:suricata` (or `data.alert.signature: *Nmap*`), Last 15 min.
- Screenshots: `portfolio/screenshots/rpi_phase3/`.

---

## 8. Thesis relevance

This is a real packet-level attack, generated under genuine TCP/IP constraints, detected on real
NetFlow-adjacent network telemetry - a concrete instance of the problem-space realizability the
thesis argues for (an attack must be a real packet on the wire, not an edited feature vector). The
captured traffic can be exported to NetFlow features (NFStream/nProbe) and fed to the compression
NIDS model on the Pi as the edge-deployment leg. See `docs/Realizability_Lab_Feasibility.md`.
