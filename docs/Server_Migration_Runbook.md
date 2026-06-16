# Wazuh Server Migration Runbook — VirtualBox VM → Docker on Arch Laptop

> **For the operator (you):** Execute task-by-task, top to bottom. Each task ends with a **VERIFY GATE** — do not start the next task until the gate passes. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the Wazuh server off the powered-off VirtualBox VM (on the 16 GB PC) to a fresh Docker deployment on the always-home 12 GB Arch laptop, then re-enroll all agents — without deleting the old VM until the new server is proven.

**Architecture:** Wazuh single-node stack (Manager + Indexer + Dashboard) runs as Docker containers via the official `wazuh-docker` compose on Arch Linux. Agents on the LAN point to the laptop's static IP. The old VM and its `phase_2_complete` snapshot are kept untouched as a rollback until verification passes.

**Tech Stack:** Docker + docker-compose, official `wazuh-docker` (single-node), Arch Linux host, Wazuh 4.x agents (Linux + Windows), Suricata on Raspberry Pi.

---

## Environment Variables (fill these in once, reuse everywhere)

Before starting, capture these real values. They are **data you look up**, not placeholders to skip:

| Name | How to get it | Your value |
|---|---|---|
| `SERVER_IP` | On the 12 GB laptop: `ip -4 addr show \| grep -oP '(?<=inet\s)\d+(\.\d+){3}' \| grep -v 127.0.0.1` | `__________` |
| `WAZUH_VERSION` | Latest stable tag — Task 2 Step 2 lists them | `__________` |
| `ADMIN_PASS` | A strong password you choose (Task 3) | `__________` |

Agent device IPs (for your own tracking):

| Device | OS | IP | Old agent? |
|---|---|---|---|
| 16 GB PC | Ubuntu | `____` | yes (was on VM) |
| 4 GB PC | Windows | `____` | yes |
| Pop!_OS box | Linux | `____` | new |
| Raspberry Pi 4 | Linux + Suricata | `____` | new (Phase 7) |

---

## Task 0: Safety — confirm the old VM is a safe rollback

**Files:** none (VirtualBox GUI on the 16 GB PC)

- [ ] **Step 1: Confirm the VM is powered off and snapshots exist**

In VirtualBox Manager, confirm `Wazuh-Server` shows **Powered Off** and the **`phase_2_complete`** snapshot is present. You saw this in your screenshot — good.

- [ ] **Step 2: Do NOT delete, clone-over, or "Reset" this VM**

Leave it exactly as-is for the whole migration. It is your only rollback. A powered-off VM costs nothing.

**VERIFY GATE:** VM is Powered Off, `phase_2_complete` snapshot visible, and you have not clicked Delete/Discard/Reset. ✅ before continuing.

---

## Task 1: Give the server laptop a fixed address

**Files:** router admin page (or `systemd-networkd` / NetworkManager on Arch)

A server must always be reachable at the same IP, or agents lose it on every reboot.

- [ ] **Step 1: Find the laptop's current IP and MAC**

```bash
ip -4 addr show | grep inet
ip link show | grep -A1 'state UP' | grep ether
```

Record the IP as `SERVER_IP` in the table above.

- [ ] **Step 2: Reserve that IP in your router (DHCP reservation)**

Log into your router (usually `http://192.168.0.1` or `http://192.168.1.1`) → DHCP / LAN settings → add a **DHCP reservation** binding the laptop's MAC to `SERVER_IP`. This is simpler and more reliable than a static IP set on Arch, and survives OS reinstalls.

- [ ] **Step 3: Reboot the laptop and confirm the IP stuck**

```bash
ip -4 addr show | grep "$SERVER_IP"
```
Expected: the line shows `SERVER_IP`.

**VERIFY GATE:** `ping SERVER_IP` from another device on the WiFi succeeds. ✅

---

## Task 2: Install Docker on Arch + kernel prep for the Indexer

**Files:** `/etc/sysctl.d/99-wazuh.conf` (create)

- [ ] **Step 1: Install Docker and compose**

```bash
sudo pacman -Syu --needed docker docker-compose git
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```
Then **log out and back in** (or reboot) so your user picks up the `docker` group.

- [ ] **Step 2: Verify Docker works without sudo**

```bash
docker run --rm hello-world
```
Expected: "Hello from Docker!" message. If you get a permission error, you didn't re-login after `usermod`.

- [ ] **Step 3: Raise `vm.max_map_count` (the Indexer/OpenSearch needs this or it crash-loops)**

```bash
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-wazuh.conf
sudo sysctl -p /etc/sysctl.d/99-wazuh.conf
sysctl vm.max_map_count
```
Expected: `vm.max_map_count = 262144`. This persists across reboots because it's in `/etc/sysctl.d/`.

**VERIFY GATE:** `docker run --rm hello-world` works AND `vm.max_map_count` is 262144. ✅

---

## Task 3: Deploy the Wazuh single-node stack

**Files:** `~/wazuh-docker/single-node/docker-compose.yml`, `.../config/wazuh_indexer/internal_users.yml`

- [ ] **Step 1: Clone the official repo**

```bash
cd ~
git clone https://github.com/wazuh/wazuh-docker.git
cd wazuh-docker
```

- [ ] **Step 2: Pick the latest stable version tag and check it out**

```bash
git tag | grep -E '^v4\.' | sort -V | tail -5
```
Pick the highest `v4.x.y` shown (e.g. `v4.9.0`). Record it as `WAZUH_VERSION`, then:
```bash
git checkout WAZUH_VERSION      # replace with the real tag, e.g. v4.9.0
cd single-node
```

- [ ] **Step 3: Change the default passwords BEFORE first start (default is public knowledge)**

Edit `docker-compose.yml` — find the `INDEXER_PASSWORD`, `DASHBOARD_PASSWORD`, and `API_PASSWORD` values (default `SecretPassword`/`MyS3cr37P450r.*-`) and replace with your `ADMIN_PASS`. Then update the hash in `config/wazuh_indexer/internal_users.yml` for the `admin` user:

```bash
docker run --rm -it wazuh/wazuh-indexer:WAZUH_VERSION \
  bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p 'YOUR_ADMIN_PASS'
```
Copy the printed hash into the `admin:` `hash:` field of `config/wazuh_indexer/internal_users.yml`.

> Lab shortcut: it's LAN-only, so if this step blocks you, you *may* start with defaults and change the password from the dashboard afterward — but never expose port 443 to the internet with default creds.

- [ ] **Step 4: Generate the indexer certificates**

```bash
docker compose -f generate-indexer-certs.yml run --rm generator
```
Expected: creates files under `config/wazuh_indexer_ssl_certs/`.

- [ ] **Step 5: Start the stack**

```bash
docker compose up -d
docker compose ps
```
Expected: `wazuh.manager`, `wazuh.indexer`, `wazuh.dashboard` all `Up`. First boot takes 1–3 minutes while the indexer initializes.

- [ ] **Step 6: Watch for a clean indexer start**

```bash
docker compose logs -f wazuh.indexer | grep -i -m1 'started'
```
Expected: a line indicating the indexer started. Ctrl-C out once seen.

**VERIFY GATE:** all three containers `Up`, no crash-loop (`docker compose ps` stable after 5 min). ✅

---

## Task 4: Confirm the dashboard is reachable

**Files:** none

- [ ] **Step 1: From the laptop, curl the dashboard**

```bash
curl -k -I https://localhost
```
Expected: `HTTP/1.1 200 OK` (the `-k` ignores the self-signed cert).

- [ ] **Step 2: From another LAN device, open the dashboard in a browser**

Go to `https://SERVER_IP` (accept the self-signed cert warning). Log in: user `admin`, password `ADMIN_PASS`.

**VERIFY GATE:** dashboard loads in a browser on a *different* device and you can log in. ✅ This proves the server is live on the LAN.

---

## Task 5: Re-enroll the agents to the new server

> The new server is fresh — it has none of the old VM's agent keys. Every agent must register against `SERVER_IP`. Do ONE agent first, prove it, then do the rest.

### 5a — First Linux agent (the Pop!_OS box) as the canary

**Files:** `/var/ossec/etc/ossec.conf` on the agent

- [ ] **Step 1: Install the agent (if not present) — Arch/Pop!_OS**

On Pop!_OS (Ubuntu-based):
```bash
curl -sO https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_WAZUH_VERSION-1_amd64.deb
sudo WAZUH_MANAGER="SERVER_IP" dpkg -i ./wazuh-agent_WAZUH_VERSION-1_amd64.deb
```
(Replace `WAZUH_VERSION` with your tag number, e.g. `4.9.0`.)

- [ ] **Step 2: Enroll and start**

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now wazuh-agent
sudo /var/ossec/bin/agent-auth -m SERVER_IP    # registers with the manager
sudo systemctl restart wazuh-agent
```

- [ ] **Step 3: Check the agent connected**

```bash
sudo tail -n 20 /var/ossec/logs/ossec.log | grep -i 'Connected to the server'
```
Expected: a "Connected to the server" line.

**VERIFY GATE:** in the dashboard (Agents page) the Pop!_OS box shows **Active**. ✅ Do not touch other agents until this one is green.

### 5b — Remaining agents (16 GB Ubuntu PC, then Windows PC)

- [ ] **Step 4: Ubuntu 16 GB PC — repoint existing agent OR install fresh**

If it already has an agent (it was on the VM): edit the manager address and re-register:
```bash
sudo sed -i 's#<address>.*</address>#<address>SERVER_IP</address>#' /var/ossec/etc/ossec.conf
sudo /var/ossec/bin/agent-auth -m SERVER_IP
sudo systemctl restart wazuh-agent
```
If no agent yet: repeat Steps 1–2 from 5a on this machine.

- [ ] **Step 5: Windows 4 GB PC — reinstall/repoint agent**

In an Administrator PowerShell:
```powershell
# If already installed, set manager and re-register:
& "C:\Program Files (x86)\ossec-agent\agent-auth.exe" -m SERVER_IP
Restart-Service -Name WazuhSvc
```
If not installed, download the Windows MSI for your `WAZUH_VERSION` from packages.wazuh.com, install with `WAZUH_MANAGER=SERVER_IP`, then run the two lines above.

**VERIFY GATE:** dashboard Agents page shows all expected nodes **Active**. Record the count. ✅

---

## Task 6: Raspberry Pi sensor (Phase 7) points to the new server

**Files:** `phases/phase7_raspberry_pi/RPi_Suricata_Setup.md` (your existing guide), agent `ossec.conf` on the Pi

- [ ] **Step 1: Follow your existing RPi guide, but set the manager to `SERVER_IP`**

Install the Wazuh agent on the Pi the same way as a Linux agent (Task 5a), using `WAZUH_MANAGER="SERVER_IP"`. Install Suricata per your `RPi_Suricata_Setup.md`.

- [ ] **Step 2: Forward Suricata's eve.json into the Wazuh agent**

In the Pi's `/var/ossec/etc/ossec.conf`, add:
```xml
<localfile>
  <log_format>json</log_format>
  <location>/var/log/suricata/eve.json</location>
</localfile>
```
Then `sudo systemctl restart wazuh-agent`.

**VERIFY GATE:** Pi shows Active in the dashboard AND a test (`ping`/`nmap` across the LAN) produces a Suricata-sourced alert visible in Wazuh. ✅ (This is also your Phase 3 first-detection deliverable.)

---

## Task 7: Retire the old VM — ONLY after everything above is green

**Files:** VirtualBox GUI

- [ ] **Step 1: Let the new server run 2–3 days collecting from all agents**

Confirm agents stay Active across reboots and you see live events. Do not rush this.

- [ ] **Step 2: Keep the VM, just leave it off**

The VM is already Powered Off. **Do not delete it.** Keep `phase_2_complete` as a permanent rollback. Reclaiming the disk is not worth losing your only backup of the working state.

> If you later truly need the disk space, *export* the VM to an `.ova` file first (`File → Export Appliance`), verify the `.ova` opens, and only then remove the VM — per your copy-verify-then-delete rule.

**VERIFY GATE:** new server has run clean for 2–3 days with all agents Active. Old VM untouched. ✅

---

## Task 8: Update project docs + commit (portfolio evidence)

**Files:** `PROJECT_STATUS.md`, this runbook

- [ ] **Step 1: Update the hardware table and status**

In `README.md` and `PROJECT_STATUS.md`, change the Wazuh Server row to: *12 GB laptop (Arch + Docker), always-on, static-reserved IP* and mark the migration done.

- [ ] **Step 2: Commit (git identity sakib2588)**

```bash
cd "/media/filwel/All/Sakib/Cyber Security Project"
git add -A
git commit -m "Migrate Wazuh server from VirtualBox VM to Docker on always-on Arch laptop"
```
(If this folder isn't a git repo yet, that's a separate step — initialize it when you build the public portfolio repo in Phase 6.)

**VERIFY GATE:** docs reflect reality; a reader of this repo understands the current topology. ✅

---

## Rollback (if the Docker server won't stabilize)

1. `docker compose down` on the laptop (stops the new stack; leaves data volumes).
2. Power the old `Wazuh-Server` VM back on in VirtualBox.
3. Re-point agents back to the **VM's** IP (reverse of Task 5).
4. You have lost nothing — the VM and its snapshot were never touched.

---

## Why these choices (interview-ready reasoning)

- **Server on the 12 GB always-home laptop, not the 32 GB ZBook:** a SIEM's value is continuous collection; uptime beats peak specs. The ZBook travels to uni, so it would create monitoring blind spots.
- **Docker, not bare-metal install:** Arch isn't an officially supported Wazuh server OS; Docker abstracts the host so the official images run anywhere, and the whole stack is reproducible and disposable.
- **Pi as Suricata sensor, never the server:** 4 GB ARM can't host the Indexer (OpenSearch), but it's ideal at the network edge for packet inspection.
- **Keep the old VM:** verify-before-delete. A powered-off VM is a free rollback.
