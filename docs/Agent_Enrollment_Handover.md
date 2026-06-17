# Agent Enrollment Handover - Wazuh SOC Lab

**Purpose:** everything needed to enroll every endpoint agent in this lab, the reasoning behind
each choice, and the edge cases / pitfalls that actually bite. Written to be followed by hand,
top to bottom, one machine at a time.

> Redaction note: this file contains the lab's private LAN IP (`192.168.1.50`, RFC1918, not
> routable from the internet) because the agents need it. It contains NO passwords. Before this
> repo is ever made public, you may still want to swap the IP for `<SERVER_IP>`.

---

## 0. Server facts (the constants every agent points at)

| Fact | Value | Why it matters |
|---|---|---|
| Server (manager) IP | `192.168.1.50` | static IP on the always-on Arch laptop; agents target this |
| Enrollment port | `1515/tcp` | one-time registration (authd) - agent gets its key here |
| Data/events port | `1514/tcp` | the agent ships logs here continuously after registering |
| Manager / Wazuh version | `4.14.5` | agents must be the SAME or OLDER, never newer (see Pitfall P2) |
| Dashboard (for verification) | `https://192.168.1.50` | Endpoints page shows agents Active/Disconnected |
| Auto-registration | enabled (wazuh-docker default) | no password needed to enroll on the LAN |

**Reachability rule (objective):** an agent can only enroll if, from that machine,
`ping 192.168.1.50` succeeds AND TCP 1515/1514 are reachable. Everything else is secondary.

---

## 1. The agents in this lab

| # | Machine | OS | CPU arch | Install method | Suggested agent name |
|---|---|---|---|---|---|
| 1 | Pop!_OS main PC | Pop!_OS (Ubuntu base) | x86_64 | `.deb` amd64 | `popos-mainpc` |
| 2 | PC1 (16 GB) | Ubuntu | x86_64 | `.deb` amd64 | `pc1-ubuntu` |
| 3 | PC2 (4 GB) | Windows 10 | x86_64 | `.msi` | `pc2-win10` |
| 4 | HP ZBook (32 GB) | Arch Linux | x86_64 | AUR (`wazuh-agent`) | `zbook-arch` |
| 5 | Raspberry Pi 4 | RPi OS / Ubuntu | **aarch64 (ARM)** | `.deb` **arm64** | `rpi-sensor` |

The Pi (5) is also the Suricata network sensor (Phase 7); its agent setup is the same as any
Linux box plus a log-forward step (Section 6).

**Confirm the CPU arch before downloading** - run `uname -m` on the target:
`x86_64` -> amd64 package; `aarch64` / `arm64` -> arm64 package. Guessing here is Pitfall P1.

---

## 2. Method and order (objective logic)

**Canary first, then fan out.** Enroll ONE machine, prove it goes Active, then do the rest.
Reason: if something is wrong (firewall, time skew, wrong IP), you find it once on one box
instead of debugging the same failure four times. Recommended canary: the **Pop!_OS PC**
(Debian-family, officially packaged, you control it directly).

**Naming convention.** Lowercase, role-based, unique. Agent names are **immutable after
enrollment** (Pitfall P4), so decide now. The names in the table above are a sane default.

**Version rule.** Install agent `4.14.5` (= the manager). An agent OLDER than the manager is
supported; an agent NEWER than the manager is not (Pitfall P2). Pin the version explicitly.

---

## 3. Linux: Debian / Ubuntu / Pop!_OS (machines 1, 2)

Run on the target machine (needs sudo + internet). Replace the name per machine.

```bash
# 1. Confirm arch is x86_64 (amd64). If it prints aarch64, use the Pi section instead.
uname -m

# 2. Download the agent (pinned to the manager version)
wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.14.5-1_amd64.deb

# 3. Install with server IP + a UNIQUE name baked in (this triggers auto-enrollment on start)
sudo WAZUH_MANAGER='192.168.1.50' WAZUH_AGENT_NAME='popos-mainpc' \
     dpkg -i ./wazuh-agent_4.14.5-1_amd64.deb

# 4. Enable + start
sudo systemctl daemon-reload
sudo systemctl enable --now wazuh-agent

# 5. Verify (client side) - look for "Connected to the server"
sudo tail -n 40 /var/ossec/logs/ossec.log | grep -iE 'connect|enroll|error'
```

Success = a line like `Connected to the server (192.168.1.50:1514)`.

> If this machine had an agent before (it was on the old VM lab), DO NOT just reinstall blindly -
> it carries a stale key. See Pitfall P5 (remove old registration first, or re-key).

---

## 4. Linux: Arch (machine 4 - the HP ZBook)

Arch is not officially packaged by Wazuh; the dashboard wizard does not list it. Use the AUR.

```bash
# 0. Need an AUR helper (yay or paru) and base-devel. If you lack one:
#    sudo pacman -S --needed base-devel git
#    git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si

# 1. Build + install the agent from the AUR
yay -S wazuh-agent            # or: paru -S wazuh-agent

# 2. Point it at the server
sudo sed -i 's|<address>.*</address>|<address>192.168.1.50</address>|' /var/ossec/etc/ossec.conf

# 3. Register with the manager (pulls the key over 1515); -A sets the unique name
sudo /var/ossec/bin/agent-auth -m 192.168.1.50 -A zbook-arch

# 4. Enable + start
sudo systemctl daemon-reload
sudo systemctl enable --now wazuh-agent

# 5. Verify
sudo tail -n 40 /var/ossec/logs/ossec.log | grep -iE 'connect|enroll|error'
```

**Arch caveats (objective):**
- The AUR version may lag behind 4.14.5. If it is OLDER, fine. If it is NEWER than the manager,
  do not use it (Pitfall P2) - install a matching version or upgrade the manager first.
- This is a laptop that travels (per the migration runbook). It will be **Active at home,
  Disconnected at uni**. That is expected behaviour, not a fault (Pitfall P8).

---

## 5. Windows 10 (machine 3 - PC2)

In an **Administrator** PowerShell on the Windows box:

```powershell
# 1. Download the agent MSI (v4.14.5)
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.5-1.msi -OutFile $env:TEMP\wazuh-agent.msi

# 2. Install silently with server IP + unique name
msiexec.exe /i $env:TEMP\wazuh-agent.msi /q WAZUH_MANAGER='192.168.1.50' WAZUH_AGENT_NAME='pc2-win10'

# 3. Start the service
NET START WazuhSvc

# 4. Verify
Get-Service WazuhSvc
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 40 | Select-String -Pattern 'Connected|enroll|ERROR'
```

**Windows specifics:**
- Must be an elevated (Administrator) PowerShell, or `msiexec` and `NET START` fail.
- Endpoint logs are sparse by default. For real visibility install **Sysmon** with a good config
  (SwiftOnSecurity) afterwards - that is what makes Windows telemetry useful (Pitfall P10).
- Windows Defender / SmartScreen may warn on the download; it is the official Wazuh MSI.

---

## 6. Raspberry Pi 4 (machine 5 - ARM + Suricata sensor, Phase 7)

The Pi is ARM, so the package is **arm64**, not amd64 (Pitfall P1 is most common here).

```bash
# 1. Confirm ARM
uname -m            # expect aarch64 (or armv7l on 32-bit OS -> use armhf package)

# 2. Download the arm64 agent
wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.14.5-1_arm64.deb

# 3. Install with server IP + name
sudo WAZUH_MANAGER='192.168.1.50' WAZUH_AGENT_NAME='rpi-sensor' \
     dpkg -i ./wazuh-agent_4.14.5-1_arm64.deb
sudo systemctl daemon-reload
sudo systemctl enable --now wazuh-agent

# 4. (Phase 7) forward Suricata's alerts into Wazuh - add to /var/ossec/etc/ossec.conf:
#    <localfile>
#      <log_format>json</log_format>
#      <location>/var/log/suricata/eve.json</location>
#    </localfile>
sudo systemctl restart wazuh-agent
```

See `phases/phase7_raspberry_pi/RPi_Suricata_Setup.md` for the full Suricata install.

---

## 7. Verifying enrollment (three independent checks)

1. **On the agent:** `Connected to the server` in `/var/ossec/logs/ossec.log`.
2. **On the dashboard:** `https://192.168.1.50` -> Endpoints -> the agent shows **Active**.
3. **On the server (this laptop), authoritative list:**
   ```bash
   sudo docker exec single-node-wazuh.manager-1 /var/ossec/bin/agent_control -l
   ```
   Shows every agent and its status (Active / Disconnected / Never connected).

A green dashboard alone is not enough - confirm the agent log says Connected, so you know the
link is live in both directions.

---

## 8. Edge cases and pitfalls (read before you start)

| ID | Pitfall | Symptom | Why | Fix / guardrail |
|---|---|---|---|---|
| P1 | Wrong CPU arch | `dpkg` install error or agent will not run | amd64 pkg on ARM (Pi), or vice versa | `uname -m` first; amd64 for x86_64, arm64 for aarch64 |
| P2 | Agent newer than manager | flaky connect, decode errors | Wazuh supports older-or-equal agents, not newer | pin agents to `4.14.5` (the manager version) |
| P3 | Wrong / changed server IP | "Unable to connect to enrollment service" | agent points at the wrong address | use `192.168.1.50` (static); this is why we fixed the IP |
| P4 | Duplicate or wrong agent name | one agent overwrites another; name stuck | names are unique and immutable after enroll | pick unique names up front; to change, remove + re-add |
| P5 | Stale key from the old VM lab | "invalid agent key" / never connects | machine still holds a key from the decommissioned server | on manager: `manage_agents -r <id>`; on agent: re-run agent-auth |
| P6 | Firewall blocks 1514/1515 | "Never connected" | a firewall (ufw/firewalld/Windows FW) drops the ports | open 1514-1515; the Arch server has no firewall by default |
| P7 | Clock skew (no NTP) | events misordered, TLS oddities | agent and manager clocks disagree | enable `systemd-timesyncd` / NTP on every node |
| P8 | Laptop/agent goes away | shows Disconnected | the ZBook travels; a PC is off; server asleep | expected; we disabled sleep on the server so it stays up |
| P9 | Different subnet / guest Wi-Fi | cannot reach `.50` | agent on another network or behind a 2nd router (NAT) | put all nodes on the same LAN/subnet |
| P10 | "Active but quiet" | agent green, almost no alerts | no log sources configured yet | Linux: enable `auditd`; Windows: install Sysmon |
| P11 | Server disk fills as agents grow | indexer goes read-only ~85-95% | more agents = more events on `/home` | watch `df -h /home`; set an ISM retention policy later |
| P12 | Exposing 1514/1515 to the internet | external attack surface | port-forwarding the manager | keep the manager LAN-only; never forward these ports |
| P13 | Reinstalling over an existing agent | half-broken state | leftover `/var/ossec` from a prior install | purge first (`apt purge wazuh-agent` / remove AUR pkg) or repoint cleanly |
| P14 | Arch AUR build deps missing | `makepkg` fails | no `base-devel` | `sudo pacman -S --needed base-devel git` |
| P15 | Windows install not elevated | MSI / service start fails | non-admin PowerShell | run PowerShell as Administrator |

---

## 9. Troubleshooting decision tree (agent not Active)

```
Agent not showing Active?
|
+- Dashboard shows "Never connected"  -> registration/reachability problem
|    1. From the agent: ping 192.168.1.50           (LAN reachable?)
|    2. From the agent: test port 1515 is open       (enrollment reachable?)
|         Linux:   nc -vz 192.168.1.50 1515
|         Windows: Test-NetConnection 192.168.1.50 -Port 1515
|    3. Re-run enrollment (agent-auth on Linux, reinstall on Windows)
|    4. Check stale key (P5): remove on manager, re-register
|
+- Dashboard shows "Disconnected" (was Active)  -> link dropped
|    1. Is the server laptop awake + on the LAN? (we disabled sleep)
|    2. Is the agent machine on + on the same Wi-Fi?
|    3. On the agent: systemctl status wazuh-agent  (is it running?)
|
+- Agent log shows a specific error  -> read it
     - "invalid key"        -> P5 (stale key)
     - "enrollment ... timeout" -> P6 firewall or P3 wrong IP
     - decode/version error -> P2 version mismatch
```

Key log locations:
- Linux agent: `/var/ossec/logs/ossec.log`
- Windows agent: `C:\Program Files (x86)\ossec-agent\ossec.log`
- Manager (in container): `sudo docker exec single-node-wazuh.manager-1 tail -f /var/ossec/logs/ossec.log`

---

## 10. After an agent is Active (so it is not "quiet")

- **Linux:** install and enable `auditd` to capture command execution and sudo use; add the log
  files you care about under `<localfile>` in `/var/ossec/etc/ossec.conf` (e.g. `/var/log/auth.log`).
- **Windows:** install **Sysmon** (SwiftOnSecurity config) and confirm Security + PowerShell
  event channels are collected. This is what turns a green agent into useful telemetry.
- **Pi:** forward `eve.json` (Section 6) so Suricata's network alerts reach Wazuh.

---

## 11. Removing or renaming an agent (clean rollback)

```bash
# On the server (this laptop): find the id, then remove
sudo docker exec single-node-wazuh.manager-1 /var/ossec/bin/agent_control -l
sudo docker exec single-node-wazuh.manager-1 /var/ossec/bin/manage_agents -r <AGENT_ID>

# On the agent machine: stop + purge, then re-enroll fresh if needed
sudo systemctl stop wazuh-agent
sudo apt purge wazuh-agent     # Debian/Ubuntu/Pop!_OS
#   Arch: yay -R wazuh-agent
```

Renaming = remove + re-enroll with the new name (names cannot be edited in place).

---

## 12. Quick reference (copy/paste targets)

- Server IP: `192.168.1.50`  - Ports: `1514` (data), `1515` (enroll)  - Version: `4.14.5`
- Verify on server: `sudo docker exec single-node-wazuh.manager-1 /var/ossec/bin/agent_control -l`
- Suggested names: `popos-mainpc`, `pc1-ubuntu`, `pc2-win10`, `zbook-arch`, `rpi-sensor`
- Golden rule: canary first, confirm Connected in the agent log, then fan out.

---

## 13. Field notes from real enrollments

### `zbook-arch` (HP ZBook, Arch) - enrolled 2026-06-17 (canary, Section 4 validated)

Worked end to end; AUR `wazuh-agent` was exactly `4.14.5-1` (= manager, no P2 issue).
`agent-auth` returned "Valid key received", service went Active, ESTABLISHED TCP to
`192.168.1.50:1514`, green on the dashboard. Three things that bit during the process - avoid
them on the remaining agents:

1. **AUR build via `yay` choked on interactive prompts** (cleanBuild / diff / edit) when run
   through a non-interactive wrapper - it hit EOF and aborted. Fix: pre-answer them:
   `yay -S --needed --noconfirm --answerclean None --answerdiff None --answeredit None wazuh-agent`.
2. **Long one-liner `sudo sh -c '...'` got line-wrap-mangled on paste** - the terminal inserted
   real newlines mid-command, so `sed` got an empty script and everything downstream failed with
   "command not found". Fix: put the steps in a small script file and run `sudo sh /path/script.sh`
   instead of pasting a long chained command. Also: **one `sudo` (a single root shell) = one
   fingerprint prompt**; many chained `sudo`s each re-prompt and the fingerprint timeouts compound.
3. **`gdb-add-index ... No debugging symbols` spam during the build is harmless** - it is just the
   optional `wazuh-agent-debug` package failing to index; the agent itself installs fine.

Post-enroll: node is "Active but quiet" until log sources are added (P10) - enable `auditd`
(`sudo pacman -S --needed audit && sudo systemctl enable --now auditd`) for command/sudo telemetry.
