# Wazuh Server Build — Docker on the Arch Laptop

> **For the operator (you):** Execute task-by-task, top to bottom. Each task ends with a **VERIFY GATE** — do not start the next task until the gate passes. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Note:** The previous Wazuh server (a VirtualBox VM on the 16 GB PC) was decommissioned on 2026-06-16. This is a **fresh build** on the always-home 12 GB Arch laptop — there is no VM to migrate from and no rollback to it. The lab is rebuilt from scratch to Phase 2 (server up, agents reporting), which is faster and cleaner than the old VM setup.

**Goal:** Stand up a fresh Wazuh server as Docker containers on the always-home 12 GB Arch laptop, then enroll all agents so the lab reaches Phase 2 (server live, nodes reporting).

**Architecture:** Wazuh single-node stack (Manager + Indexer + Dashboard) runs as Docker containers via the official `wazuh-docker` compose on Arch Linux. Agents on the LAN point to the laptop's static IP.

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

| Device | OS | IP | Notes |
|---|---|---|---|
| 16 GB PC | Ubuntu | `____` | enroll fresh |
| 4 GB PC | Windows | `____` | enroll fresh |
| Pop!_OS box | Linux | `____` | enroll fresh |
| Raspberry Pi 4 | Linux + Suricata | `____` | enroll fresh (Phase 7) |

---

## Pre-flight: 2 checks on the laptop (10 seconds)

Run these **on the 12 GB laptop** before anything else. Both must pass:

```bash
free -h     # RAM: want ~9 GB+ free  (lean Arch idles ~2.5 GB on a 12 GB box)
df -h /     # Disk: want 20 GB+ free
```

- RAM free under ~7 GB → close apps (browser, IDE) first.
- Disk free under ~15 GB → free space before starting.

---

## Quick Start (the happy path)

The whole flow at a glance. Each line maps to a Task below — **if anything fails or is unclear, drop to that Task for the full detail and verify gate.** Do not skip the heap pin in Task 3.

```bash
# Task 1 — reserve a fixed IP for the laptop in your router (GUI step, no command)

# Task 2 — Docker + kernel prep
sudo pacman -Syu --needed docker docker-compose git
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"          # then LOG OUT and back in
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-wazuh.conf
sudo sysctl -p /etc/sysctl.d/99-wazuh.conf
docker run --rm hello-world              # must print "Hello from Docker!"

# Task 3 — deploy Wazuh
git clone https://github.com/wazuh/wazuh-docker.git && cd wazuh-docker
git tag | grep -E '^v4\.' | sort -V | tail -5     # pick the highest, e.g. v4.9.0
git checkout v4.9.0 && cd single-node             # <-- use the real tag you picked
#  *** REQUIRED: edit docker-compose.yml -> add to wazuh.indexer environment:
#      - "OPENSEARCH_JAVA_OPTS=-Xms2g -Xmx2g"      (Task 3 Step 5 — DO NOT SKIP)
docker compose -f generate-indexer-certs.yml run --rm generator
docker compose up -d && docker compose ps         # all 3 containers must be Up

# Task 4 — open https://<SERVER_IP> in a browser, log in admin / your password
# Task 5 — enroll each agent (one at a time) pointing at <SERVER_IP>
```

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

- [ ] **Step 5: Pin the Indexer heap — REQUIRED on the 12 GB laptop (do NOT skip)**

By default the Indexer (OpenSearch) grabs up to **half the host RAM** for its JVM heap. On a 12 GB laptop that is ~6 GB, which crowds the manager + dashboard and **OOM-kills the stack on first boot**. Pin the heap to 2 GB before you ever run `docker compose up`.

Open `docker-compose.yml` (you are in `wazuh-docker/single-node/`) and find the `wazuh.indexer:` service. Under its `environment:` block, add the heap line so it looks like this:

```yaml
  wazuh.indexer:
    # ...existing settings (image, hostname, ports, volumes)...
    environment:
      - "OPENSEARCH_JAVA_OPTS=-Xms2g -Xmx2g"   # <-- ADD THIS LINE (pins heap to 2 GB)
```

If an `environment:` block already exists on that service, just add the `- "OPENSEARCH_JAVA_OPTS=..."` line to it — do not create a second `environment:` key.

Then save the file. Also close heavy apps (browser, IDE) during the first boot.

**VERIFY (before continuing):** confirm the line is present:
```bash
grep -n 'OPENSEARCH_JAVA_OPTS' docker-compose.yml
```
Expected: one line showing `-Xms2g -Xmx2g`. If it prints nothing, you have not saved the edit — fix it before starting the stack.

- [ ] **Step 6: Start the stack**

```bash
docker compose up -d
docker compose ps
```
Expected: `wazuh.manager`, `wazuh.indexer`, `wazuh.dashboard` all `Up`. First boot takes 1–3 minutes while the indexer initializes.

- [ ] **Step 7: Watch for a clean indexer start, and confirm RAM headroom**

```bash
docker compose logs -f wazuh.indexer | grep -i -m1 'started'   # Ctrl-C once you see it
docker stats --no-stream                                       # no container should sit near its MEM limit
```
Expected: an indexer "started" line, and `docker stats` shows the indexer using roughly 2–3 GB (not 6+).

> **If the indexer crash-loops** (`docker compose ps` shows it restarting): it is almost always one of two things — (1) you skipped the heap pin in Step 5, or (2) `vm.max_map_count` is not 262144 (Task 2, Step 3). Re-check both, then `docker compose down && docker compose up -d`.

**VERIFY GATE:** all three containers `Up`, no crash-loop (`docker compose ps` stable after 5 min), and `docker stats` shows the indexer near 2–3 GB. ✅

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

> The server is fresh — every agent must register against `SERVER_IP`. Do ONE agent first, prove it, then do the rest.

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

## Task 7: Update project docs + commit (portfolio evidence)

**Files:** `PROJECT_STATUS.md`, `README.md`, this runbook

- [ ] **Step 1: Let the new server run 2–3 days collecting from all agents**

Confirm agents stay Active across reboots and you see live events before declaring Phase 2 done. Do not rush this.

- [ ] **Step 2: Update the hardware table and status**

In `README.md` and `PROJECT_STATUS.md`, confirm the Wazuh Server row reads: *12 GB laptop (Arch + Docker), always-on, static-reserved IP*, and mark the rebuild to Phase 2 done.

- [ ] **Step 3: Commit (git identity sakib2588)**

```bash
cd <path-to-your-repo>     # your local clone of this repo
git add -A
git commit -m "Rebuild Wazuh server: Docker single-node on always-on Arch laptop"
```

**VERIFY GATE:** docs reflect reality; a reader of this repo understands the current topology. ✅

---

## Rollback (if the Docker server won't stabilize)

There is no VM to fall back to — this is a fresh build. If the stack misbehaves:

1. `docker compose down` on the laptop (stops the stack; named data volumes persist).
2. Check the failing container's logs: `docker compose logs wazuh.indexer` (most issues are the Indexer needing `vm.max_map_count=262144` or insufficient RAM).
3. Fix the cause, then `docker compose up -d` again. Because the stack is disposable, you can `docker compose down -v` to wipe volumes and start clean as a last resort.

---

## Why these choices (interview-ready reasoning)

- **Server on the 12 GB always-home laptop, not the 32 GB ZBook:** a SIEM's value is continuous collection; uptime beats peak specs. The ZBook travels to uni, so it would create monitoring blind spots.
- **Docker, not bare-metal install:** Arch isn't an officially supported Wazuh server OS; Docker abstracts the host so the official images run anywhere, and the whole stack is reproducible and disposable.
- **Pi as Suricata sensor, never the server:** 4 GB ARM can't host the Indexer (OpenSearch), but it's ideal at the network edge for packet inspection.
