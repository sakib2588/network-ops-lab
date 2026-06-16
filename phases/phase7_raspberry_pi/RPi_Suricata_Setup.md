# Phase 7 — Raspberry Pi 4 Network Sensor Setup

**Device:** Raspberry Pi 4B (4GB RAM)  
**Role:** Network-based IDS (Suricata) + Wazuh agent (5th monitored node)  
**Target date:** June 21, 2026  
**Estimated time:** 3-4 hours total

---

## Why This Matters

Your lab currently has **host-based detection only** (Wazuh agents on each machine watching their own logs). Adding the RPi with Suricata gives you **network-based detection** — it sees traffic between all devices on your network, even traffic that never touches the machines directly.

Real SOCs use both layers. This setup demonstrates you understand the difference.

**Thesis connection:** Suricata operates on real TCP/IP packets — it sees what actually travels on the wire, not feature-extracted values. This is direct evidence of the realizability gap your thesis addresses.

---

## Architecture After This Phase

```
[Router]
    |
[RPi4 - Suricata]  ← sees all traffic, sends alerts to Wazuh
    |
[Switch/Hub]
   /|\
  / | \
PC1 PC2 Laptop(Wazuh Server)
```

---

## Step 1: Flash Ubuntu Server 22.04 onto SD Card (30 min)

On your main PC:

```bash
# Download Raspberry Pi Imager
sudo apt install rpi-imager -y
# OR download from: https://www.raspberrypi.com/software/

# Launch and select:
# OS: Ubuntu Server 22.04 LTS (64-bit)
# Storage: your SD card (16GB minimum)
# Advanced settings: set hostname=rpi-sensor, enable SSH, set password
```

**Or via command line:**
```bash
# Download image
wget https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04.5-preinstalled-server-arm64+raspi.img.xz

# Flash to SD (replace /dev/sdX with your SD card device — check with lsblk)
xzcat ubuntu-22.04.5-preinstalled-server-arm64+raspi.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
sync
```

---

## Step 2: First Boot and Network Setup (15 min)

```bash
# SSH into RPi (find IP from router admin page or use nmap)
nmap -sn 192.168.1.0/24          # scan your network range
ssh ubuntu@192.168.1.XXX         # default password: ubuntu (you'll be forced to change)

# Update system
sudo apt update && sudo apt upgrade -y

# Set static IP (optional but recommended for lab)
sudo nano /etc/netplan/50-cloud-init.yaml
```

Static IP config (adjust to your network):
```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses: [192.168.1.100/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

```bash
sudo netplan apply
```

---

## Step 3: Install Suricata (45 min)

```bash
# Add Suricata PPA and install
sudo add-apt-repository ppa:oisf/suricata-stable -y
sudo apt update
sudo apt install suricata suricata-update -y

# Update threat intelligence rules
sudo suricata-update

# Check Suricata version
suricata --version
```

**Configure Suricata to watch your network interface:**
```bash
# Find your interface name
ip a                              # usually eth0 on RPi

sudo nano /etc/suricata/suricata.yaml
```

Edit these lines:
```yaml
af-packet:
  - interface: eth0              # your RPi ethernet interface

# Set your home network range
vars:
  address-groups:
    HOME_NET: "[192.168.1.0/24]"  # adjust to your subnet
    EXTERNAL_NET: "!$HOME_NET"
```

```bash
# Start and enable Suricata
sudo systemctl start suricata
sudo systemctl enable suricata

# Verify it's running and detecting traffic
sudo tail -f /var/log/suricata/fast.log
```

---

## Step 4: Install Wazuh Agent on RPi (30 min)

```bash
# Add Wazuh repo (replace 4.x with your Wazuh server version)
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | \
  sudo tee /etc/apt/sources.list.d/wazuh.list

sudo apt update
sudo apt install wazuh-agent -y

# Configure agent to point to your Wazuh server (laptop IP)
sudo nano /var/ossec/etc/ossec.conf
```

Edit the manager IP:
```xml
<client>
  <server>
    <address>192.168.1.XXX</address>    <!-- your laptop (Wazuh server) IP -->
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
</client>
```

```bash
# Start agent
sudo systemctl start wazuh-agent
sudo systemctl enable wazuh-agent

# On your Wazuh SERVER (laptop) — accept the new agent
sudo /var/ossec/bin/manage_agents     # list pending, accept RPi agent
```

---

## Step 5: Forward Suricata Alerts into Wazuh (20 min)

Tell Wazuh agent to also read Suricata logs:

```bash
sudo nano /var/ossec/etc/ossec.conf
```

Add inside `<ossec_config>`:
```xml
<localfile>
  <log_format>json</log_format>
  <location>/var/log/suricata/eve.json</location>
</localfile>
```

```bash
sudo systemctl restart wazuh-agent
```

Now Suricata alerts appear on your Wazuh dashboard automatically.

---

## Step 6: Verify Everything Works (30 min)

**Test 1 — From your PC, run nmap against RPi:**
```bash
nmap -sS 192.168.1.100           # SYN scan against RPi
```
Expected: Suricata logs the scan. Wazuh dashboard shows alert.

**Test 2 — From RPi, scan another device:**
```bash
nmap -sS 192.168.1.XXX           # scan PC1 or PC2
```
Expected: Wazuh agent on PC1/PC2 logs the connection attempt. Suricata on RPi also logs it.

**Screenshot both alerts in Wazuh dashboard → save to `portfolio/screenshots/`**

---

## Step 7 (Optional but Valuable) — Cowrie Honeypot

```bash
# Install dependencies
sudo apt install python3-virtualenv libssl-dev libffi-dev build-essential -y
sudo useradd -r -d /home/cowrie -m cowrie
sudo su - cowrie

# Setup Cowrie
git clone https://github.com/cowrie/cowrie.git
cd cowrie
virtualenv cowrie-env
source cowrie-env/bin/activate
pip install -r requirements.txt

cp etc/cowrie.cfg.dist etc/cowrie.cfg
# Edit: hostname, listen port (default 2222)

bin/cowrie start
```

**What this does:** Creates a fake SSH server on port 2222. Any connection attempt is logged with full session data — commands typed, files requested, credentials tried. Every log entry is a real attack attempt from your network.

Forward Cowrie logs to Wazuh same way as Suricata (add localfile entry for `/home/cowrie/cowrie/var/log/cowrie/cowrie.json`).

---

## Phase 7 Completion Checklist

- [ ] Ubuntu Server 22.04 running on RPi
- [ ] Suricata installed and detecting traffic
- [ ] Wazuh agent installed, RPi visible in dashboard as 5th node
- [ ] Suricata alerts flowing into Wazuh
- [ ] Test nmap scan logged and alerted
- [ ] Screenshots saved to `portfolio/screenshots/rpi_phase7/`
- [ ] Update `PROJECT_STATUS.md` phase 7 as done

---

## Thesis Documentation Note

After completing this phase, write a short note in your thesis notes:

> "Suricata IDS running on Raspberry Pi 4 monitors raw Ethernet frames on the lab network. Unlike feature-extracted dataset attacks, traffic generated here must conform to TCP/IP protocol constraints — providing a physical demonstration of the realizability gap described in Ennaji et al. (2025)."

Save that note at: `/media/filwel/All/Sakib/Theisis & Internship /thiesis  /MD files/lab_realizability_evidence.md`
