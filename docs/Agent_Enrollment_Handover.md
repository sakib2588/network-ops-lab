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
| 1 | Main PC (16 GB) | Pop!_OS 24.04 (Ubuntu base) | x86_64 | `.deb` amd64 | `popos-mainpc` |
| 2 | PC2 (4 GB) | Windows 10 | x86_64 | `.msi` | `pc2-win10` |
| 3 | HP ZBook (32 GB) | Arch Linux | x86_64 | AUR (`wazuh-agent`) | `zbook-arch` |
| 4 | Raspberry Pi 4 | RPi OS / Ubuntu | **aarch64 (ARM)** | `.deb` **arm64** | `rpi-sensor` |

> **Correction (2026-06-17):** an earlier draft listed a separate node `pc1-ubuntu` (PC1, 16 GB
> Ubuntu). That was NOT a second machine - it is the **same physical box** as `popos-mainpc`
> (Pop!_OS is Ubuntu-based, 16 GB RAM). The duplicate has been removed; there is no `pc1-ubuntu`.
> Real lab = `popos-mainpc`, `pc2-win10`, `zbook-arch`, `rpi-sensor`, plus the server.

The Pi (4) is also the Suricata network sensor (Phase 7); its agent setup is the same as any
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

## 3. Linux: Debian / Ubuntu / Pop!_OS (machine 1)

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
- Suggested names: `popos-mainpc`, `pc2-win10`, `zbook-arch`, `rpi-sensor`
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

### `popos-mainpc` (Pop!_OS 24.04 main PC, amd64) - enrolled 2026-06-17 (Section 3 / Debian-family validated)

Always-on main PC (16 GB, IP 192.168.1.105; this is the box an earlier draft mis-listed as a
separate `pc1-ubuntu` - same machine, now merged). Installed `wazuh-agent 4.14.5-1` from the amd64
`.deb` with `WAZUH_MANAGER` / `WAZUH_AGENT_NAME` baked in (Section 3 method). Ended Active,
ESTABLISHED TCP to `192.168.1.50:1514` (verified stable - byte counters climbing and acked, ~12 MB
shipped), green on the dashboard. Five things that bit - avoid them on the remaining agents:

1. **Stale OLD-server IP lurking in `ossec.conf` (this box ran the decommissioned VM lab).** It
   enrolled to `192.168.1.50` fine, but a later `systemctl restart` reverted the target to the old
   `192.168.1.10` and it fell into a connect/close loop (no "Connected" line, no hard error). Fix:
   force every address with
   `sudo sed -i 's#<address>[^<]*</address>#<address>192.168.1.50</address>#g' /var/ossec/etc/ossec.conf`
   then restart. Lesson (P3/P5): on any machine that ran the old VM lab, confirm `<address>` both
   after install AND after the first restart.
2. **`sudo` has no password channel through any non-interactive path.** Neither an automation
   wrapper, nor a `!`-prefixed command, nor `pkexec` surfaced a prompt (no TTY / no polkit agent
   reachable), so every `sudo` silently failed with "a terminal is required to read the password".
   Fix: run all `sudo` steps in a real terminal window (paste with Ctrl+Shift+V).
3. **Long chained one-liners line-wrap-mangle on paste** (same failure as note 2 under zbook). A
   `printf ... | sudo tee -a ...` got split mid-pipe, so the redirect ran as the normal user ->
   "Permission denied"; `sudo apt-get` + `update` split across lines -> "update: command not found".
   Fix: single unbroken lines, or put steps in a script file.
4. **`apt` was wedged before anything could install** - the MEGA repo was declared twice
   (`/etc/apt/sources.list.d/mega.list` AND `megaio.sources`) with two different `Signed-By` keys,
   so apt refused every operation ("Conflicting values set for option Signed-By"). Fix: disable one
   (`sudo mv /etc/apt/sources.list.d/mega.list /etc/apt/sources.list.d/mega.list.disabled`), then
   `sudo apt-get update` is clean. Worth checking on any box before relying on apt.
5. **Made non-quiet (P10):** `sudo apt-get install -y auditd audispd-plugins`, then add an audit
   localfile to `ossec.conf` (`<log_format>audit</log_format>` +
   `<location>/var/log/audit/audit.log</location>`) and restart. Verify it is shipping by watching
   the data socket counters grow (`ss -tin | grep 192.168.1.50:1514`) or by checking the agent's
   events on the dashboard. This box already carried a rich audit ruleset (exec / network /
   identity / sudoers / sshd); a fresh box needs rules added.

### `rpi-sensor` (Raspberry Pi 4, aarch64) - enrolled 2026-06-17 (Section 6 + Phase 7 sensor)

Raspberry Pi 4, Raspberry Pi OS / Debian 11 (bullseye), IP 192.168.1.104 over **Wi-Fi `wlan0`**
(eth0 was `NO-CARRIER` - cable/port not linking; deferred, Wi-Fi is fine for own-traffic
monitoring). Clean box (no prior agent). Installed `wazuh-agent 4.14.5-1` from the **arm64** `.deb`
with `WAZUH_MANAGER` / `WAZUH_AGENT_NAME` baked in; came up Active, "Connected to the server
(192.168.1.50:1514)", manager pushed shared config. Agent side was painless - the real fight was
Phase 7 (Suricata). Things that bit, with fixes:

1. **eth0 dead, not a config bug.** `ip link show eth0` = `<NO-CARRIER>` even with the jack LEDs
   lit. That is layer-1 (no link partner) - DHCP cannot fix it. Don't chase it; capture on `wlan0`.
   Wi-Fi can't go promiscuous (can't sniff *other* hosts), but for Option-A (attacks generated
   *from* the Pi) it sees its own traffic fine. Full passive LAN visibility needs a wired SPAN/TAP/
   inline-bridge upgrade later.
2. **Install Suricata from the Debian repo, NOT the OISF PPA** (PPAs are Ubuntu-only and fail on
   Pi OS). `sudo apt install suricata` gives 6.0.1 - fine.
3. **The big one - Debian rule-path mismatch -> 0 rules loaded -> 0 alerts.** `suricata-update`
   writes the ruleset to `/var/lib/suricata/rules/suricata.rules`, but the stock `suricata.yaml`
   has `default-rule-path: /etc/suricata/rules` (empty). Result: engine runs, captures perfectly
   (verified `iface-stat`: pkts rising, 0 drops), but `detect.rules_loaded: 0` and never alerts.
   Fix: `sudo sed -i 's|^default-rule-path:.*|default-rule-path: /var/lib/suricata/rules|'
   /etc/suricata/suricata.yaml` then restart. Confirm with `... rules successfully loaded` (~50685)
   in `suricata.log`, not 0.
4. **Set the capture interface in BOTH `suricata.yaml` (af-packet) AND `/etc/default/suricata`
   (`IFACE`/`LISTENMODE=af-packet`)** - mismatch = listens on the wrong NIC, silent.
5. **The `testmynids` curl test is a false negative.** Its rule (sid 2100498) lives in
   `emerging-deleted.rules`, which `suricata-update` skips - so the classic test never alerts even
   when Suricata is healthy. Prove the pipeline with a **local test rule** instead:
   `echo 'alert icmp any any -> any any (msg:"LOCAL PING TEST"; sid:9000001; rev:1;)' | sudo tee -a
   /var/lib/suricata/rules/suricata.rules`, reload (`sudo suricatasc -c reload-rules`), `ping`, and
   it fires. **Remove that rule afterwards** (`sudo sed -i '/LOCAL PING TEST/d' .../suricata.rules`)
   - it alerts on every ping and will spam the SIEM.
6. **Forward into Wazuh:** add a `<localfile><log_format>json</log_format><location>
   /var/log/suricata/eve.json</location></localfile>` block to `ossec.conf` (single-line `printf |
   sudo tee -a` to avoid paste-mangling), restart `wazuh-agent`, confirm `Analyzing file:
   '/var/log/suricata/eve.json'` in `ossec.log`, then verify on the dashboard with
   `data.alert.signature:"LOCAL PING TEST"` filtered to `agent.name:rpi-sensor`.

Result: host + network detection both feeding the SIEM. Disk hygiene matters on the Pi's SD card -
see the Phase 7 runbook (logrotate, capped pcaps, watch `df -h /`). Full as-built walkthrough:
`phases/phase7_raspberry_pi/Phase7_Suricata_LIVE_Runbook.md`.

### `zbook-arch` telemetry (2026-06-17)

**Telemetry enabled on `zbook-arch` (2026-06-17).** `auditd` installed + enabled, with rules in
`/etc/audit/rules.d/wazuh-soc.rules`:
```
-a always,exit -F arch=b64 -S execve -k exec     # every command execution
-w /etc/sudoers -p wa -k sudoers                 # sudoers changes
-w /etc/passwd  -p wa -k identity                # account changes
-w /etc/shadow  -p wa -k identity                # credential changes
```
Then a `<localfile>` with `<log_format>audit</log_format>` pointing at `/var/log/audit/audit.log`
was added to `ossec.conf` (backed up first) and the agent restarted, so these events reach the
manager. Caveat: the unfiltered `execve` rule logs **every** command - chatty by design; if event
volume stresses the server disk (P11), narrow it (e.g. add `-F auid>=1000` or scope to specific
paths). Apply the same two steps (auditd + localfile) on the other Linux agents to avoid P10.
