# Investigation Playbook — Network Scan Detection

**Playbook ID:** PB-001
**Rules covered:** 100015 (scan escalated), 100016 (scan burst), 100021 (VNC targeted during scan)
**MITRE:** T1046 (Network Service Discovery), T1595 (Active Scanning), T1021.005 (VNC)
**Severity:** Level 12
**Author:** Nazmus Sakib
**Last updated:** 2026-06-18

---

## 1. When this playbook fires

A Wazuh alert arrives with `rule.id` of **100015**, **100016**, or **100021**.

| Rule | Meaning |
|---|---|
| 100015 | Suricata caught an ET SCAN / Nmap signature from a single source |
| 100016 | Same source triggered 8+ scan alerts within 60 seconds (burst) |
| 100021 | A scan specifically probed port 5900 (VNC) — remote-control surface targeted |

These rules fire from the **rpi-sensor** agent (Suricata on the Pi). They represent the network layer view — traffic crossing the Wi-Fi segment.

---

## 2. Immediate triage (first 5 minutes)

**Step 1 — Identify the source:**
Go to Wazuh → Threat Hunting → filter `rule.id:(100015 OR 100016 OR 100021)`.
Note the `src_ip` field. Answer:
- Is this a known internal host? (lab IPs: .50 server, .104 Pi, .105 popos, .106 zeno attacker, .108 zbook)
- Is it the attacker VM `zeno` (192.168.1.106)? → Authorized lab test.
- Unknown IP on the LAN? → Escalate immediately.

**Step 2 — Identify the scope:**
- What ports did Suricata report in `dest_port`?
- Did **100021** fire? → VNC (5900) was probed. Treat as higher priority.
- How many alerts in the last 15 minutes? (`rule.id:100015`, count)

**Step 3 — Check the target:**
```bash
# On rpi-sensor — did Suricata log the scan?
sudo tail -100 /var/log/suricata/fast.log | grep <src_ip>
```

---

## 3. Investigation (next 15 minutes)

**Check for follow-on activity from the same source:**
```bash
# Wazuh Threat Hunting — all activity from the scanning IP in last 1h
# Filter: data.src_ip:<attacker_ip>  or  agent.name:rpi-sensor
```

Look for:
- SSH login attempts after the scan → brute force (check `rule.id:(100017 OR 100018)`)
- VNC connection attempts after 100021 → `rule.id:100021` + follow-on `src_ip` activity
- Any successful authentication → `rule.id:100018` (Level 14, MITRE T1078)

**Check Suricata for full context:**
```bash
# On rpi-sensor
sudo grep <src_ip> /var/log/suricata/eve.json | python3 -m json.tool | grep -E "timestamp|alert|src_ip|dest_port|proto" | head -50
```

---

## 4. Known detection gap — stealth scans evade this ruleset

A `nmap -sS -T1` (SYN-only stealth scan) produces **zero alerts** from this ruleset. This was confirmed during Phase 3 live-fire (2026-06-18):

- `-sV -A` (loud): 25 alerts, fully detected
- `-sS -T1` (stealth): 0 alerts, full evasion

**Why:** Suricata's ET SCAN signatures match HTTP user-agent strings and application-layer content that only appear during version/script probing (`-sV`). A pure SYN scan carries no payload.

**Implication:** absence of a 100015/100016 alert does NOT mean no scan occurred. If you suspect a stealthy recon, check the Pi's connection tracking or look for port-sweep patterns manually.

**Future mitigation:** add a Suricata flow/threshold rule counting SYN packets per source IP per minute.

---

## 5. Containment actions

| Scenario | Action |
|---|---|
| Known lab test (zeno) | No action — document the alert as authorized |
| Unknown internal IP | Isolate the host, check ARP table on the router |
| External IP somehow on LAN | Check for rogue device, change Wi-Fi credentials |
| VNC (100021) from unknown source | Immediately disable VNC on the Pi: `sudo systemctl stop vncserver` or add firewall rule |

---

## 6. Evidence to collect

- Screenshot of Wazuh Threat Hunting view (rule.id + src_ip + timestamps)
- `sudo grep <src_ip> /var/log/suricata/fast.log` output
- Output of `sudo netstat -tnp` on the Pi at time of alert (if real-time)
- Check if VNC was accessed: `sudo journalctl -u vncserver --since "1 hour ago"`

---

## 7. Escalation criteria

Escalate if any of the following:
- Source IP is not in the known lab inventory
- 100021 fired AND a subsequent SSH login succeeded (100018)
- Scan is followed by any outbound connection from the Pi to the scanner's IP
- Alert count exceeds 50 in 5 minutes (active automated scanner, not manual nmap)

---

## 8. Lab-specific notes

- This lab uses an **assumed-breach / east-west** threat model. The attacker VM (`zeno`) is on the same LAN segment as all monitored hosts. A real perimeter scan from outside the network would not reach the Pi directly (behind NAT). The lab exercises the detection logic; the network topology is an acknowledged limitation.
- Suricata only monitors traffic on `wlan0` (the Pi's Wi-Fi interface). Traffic between wired hosts that does not pass through the Pi's interface is invisible.
- See `docs/Custom_Suricata_Rules.md` for the VNC detection rule (sid:9000020).
