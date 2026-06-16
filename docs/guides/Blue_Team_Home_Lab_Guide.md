# Architecting a Blue Team Home Lab: Complete Guide from Phase 0-4
## Building SOC Skills with Wazuh - A Comprehensive Tutorial

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Hardware Requirements](#hardware-requirements)
3. [Phase 0: Foundational Architecture and Environment Setup](#phase-0-foundational-architecture-and-environment-setup)
4. [Phase 1: Wazuh Server and Agent Deployment](#phase-1-wazuh-server-and-agent-deployment)
5. [Phase 2: Heterogeneous Log Ingestion and Data Normalization](#phase-2-heterogeneous-log-ingestion-and-data-normalization)
6. [Phase 3: Threat Simulation and Observational Analysis](#phase-3-threat-simulation-and-observational-analysis)
7. [Phase 4: Custom Detection Rule Engineering](#phase-4-custom-detection-rule-engineering)
8. [Troubleshooting Guide](#troubleshooting-guide)

---

## Project Overview

### Objective
Build a robust, multi-device home-based cybersecurity lab focused on blue team defense skills, targeting roles such as:
- Security Operations Center (SOC) Analyst
- Network Security Analyst
- Incident Response Analyst

### Timeline
- **Total Duration**: 11 weeks (maximum 2.5 months)
- **Weekly Commitment**: 15 hours
- **Approach**: Floating-phase model (strategic overlap of project stages)

### Core Technology Stack
- **SIEM Platform**: Wazuh 4.12+ (current version as of 2025)
- **Threat Simulation**: Atomic Red Team
- **Operating Systems**: Ubuntu-based (Pop!_OS), Windows 10/11

### Learning Outcomes
By completing this project, you will:
- Deploy and configure enterprise SIEM infrastructure
- Implement comprehensive log collection strategies
- Simulate real-world attacks using MITRE ATT&CK framework
- Engineer custom detection rules
- Build a professional cybersecurity portfolio

---

## Hardware Requirements

### Your Available Hardware

| Device | RAM | Primary OS | Role |
|--------|-----|------------|------|
| Desktop PC | 16GB | Pop!_OS (dual-boot) | Wazuh Server VM Host |
| Desktop PC | 4GB | Windows/Pop!_OS | Bare-metal Agent |
| Laptop | 12GB | Arch Linux → Pop!_OS | Windows VM Host + Agent |
| Raspberry Pi (future) | 4GB+ | Raspberry Pi OS | IoT Sensor Agent |

### Final Architecture Allocation

```
┌─────────────────────────────────────────────────────────────┐
│                    16GB RAM Desktop PC                      │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Pop!_OS Host (8GB RAM) + will work as an agent         │ │
│  │  - Daily computing tasks                               │ │
│  │  - Light browsing during idle                          │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Wazuh Server VM (8GB RAM, 2 CPU, 40GB Disk)            │ │
│  │  - Pop!_OS Guest OS                                    │ │
│  │  - Wazuh Manager + Indexer + Dashboard                 │ │
│  │  - Static IP: 192.168.1.10 (example)                   │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    4GB RAM Desktop PC                       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ This will work as native Windows agent                 │ │
│  │  - Wazuh Agent                                         │ │
│  │  - Generates syslog, auditd data                       │ │
│  │  - Static IP: 192.168.1.20 (example)                   │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│       Arch Linux Host (6GB RAM) + Atomic Red Team           │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Arch Linux Host (6GB RAM)                              │ │
│  │  - Wazuh Agent is the host                             │ │
│  │  - Static IP: 192.168.1.30 (example)                   │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Atomic Red Team VM (6GB RAM, 2 CPU, 60GB Disk)        │ │
│  │  - Corporate endpoint simulation                       │ │
│  │  - Atomic Red Team installation via VirtualBox         │ │
│  │  - Static IP: 192.168.1.31 (example)                   │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 0: Foundational Architecture and Environment Setup

**Duration**: Week 1 (12 hours)  
**Objective**: Establish stable, interconnected lab environment with all VMs running and network properly configured

### Why VM for Wazuh Server?

The Wazuh server is deployed in a VM rather than bare-metal for several critical reasons:

1. **Isolation**: Prevents misconfigurations from impacting host OS
2. **Snapshots**: Create safety checkpoints before risky operations
3. **Reproducibility**: Easy documentation and recreation
4. **Resource Management**: 8GB allocation leaves 8GB for host
5. **Learning-Friendly**: Encourages experimentation without fear

### Step 0.1: Install Hypervisor on 16GB Desktop

Choose **VirtualBox** (free, open-source) or **VMware Workstation Player** (free for personal use).

#### VirtualBox Installation (Recommended for Beginners)

```bash
# On Pop!_OS (Ubuntu-based), update system first
sudo apt update && sudo apt upgrade -y

# Install VirtualBox
sudo apt install virtualbox virtualbox-ext-pack -y

# Verify installation
vboxmanage --version

# Expected output: 7.0.x or higher
```

#### VMware Workstation Player Installation (Alternative)

```bash
# Download from VMware website
# https://www.vmware.com/products/workstation-player.html

# Install downloaded bundle (replace version number as needed)
chmod +x VMware-Player-*.bundle
sudo ./VMware-Player-*.bundle

# Follow GUI installer
```

### Step 0.2: Create Wazuh Server VM

#### Using VirtualBox

```bash
# Create VM from command line (or use GUI)
vboxmanage createvm --name "Wazuh-Server" --ostype Ubuntu_64 --register

# Configure VM resources
vboxmanage modifyvm "Wazuh-Server" \
  --memory 8192 \
  --cpus 2 \
  --vram 128 \
  --nic1 bridged \
  --bridgeadapter1 "$(ip route | grep default | awk '{print $5}')" \
  --boot1 disk \
  --boot2 dvd

# Create virtual hard disk (40GB)
vboxmanage createhd --filename ~/VirtualBox\ VMs/Wazuh-Server/Wazuh-Server.vdi --size 40960

# Attach disk to VM
vboxmanage storagectl "Wazuh-Server" --name "SATA Controller" --add sata --bootable on
vboxmanage storageattach "Wazuh-Server" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/Wazuh-Server/Wazuh-Server.vdi

# Download Pop!_OS ISO
cd ~/Downloads
wget https://iso.pop-os.org/22.04/amd64/intel/54/pop-os_22.04_amd64_intel_54.iso

# Attach ISO to VM
vboxmanage storageattach "Wazuh-Server" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium ~/Downloads/pop-os_22.04_amd64_intel_54.iso

# Start VM
vboxmanage startvm "Wazuh-Server"
```

**GUI Installation Steps:**
1. Open VirtualBox
2. Click "New"
3. Name: `Wazuh-Server`, Type: Linux, Version: Ubuntu (64-bit)
4. Memory: 8192 MB
5. Create virtual hard disk (VDI, Dynamically allocated, 40 GB)
6. Settings → System → Processor: 2 CPUs
7. Settings → Network → Adapter 1: Bridged Adapter
8. Settings → Storage → Controller: SATA → Add Optical Drive → Choose Pop!_OS ISO
9. Start VM and follow Pop!_OS installation

### Step 0.3: Install Pop!_OS on Wazuh Server VM

**During Pop!_OS Installation:**
- Select "Clean Install"
- Create user: `wazuhadmin` (use strong password)
- Hostname: `wazuh-server`
- Enable disk encryption (optional, recommended for sensitive data)

**Post-Installation Configuration:**

```bash
# SSH into or work directly in VM

# Update system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y \
  curl \
  wget \
  git \
  vim \
  net-tools \
  ufw \
  openssh-server

# Enable and configure SSH (for remote management)
sudo systemctl enable ssh
sudo systemctl start ssh

# Configure firewall (will add Wazuh ports later)
sudo ufw enable
sudo ufw allow ssh
sudo ufw status
```

### Step 0.4: Configure Static IP for Wazuh Server VM

**Method 1: Using Netplan (Pop!_OS 22.04)**

```bash
# Identify network interface
ip addr show
# Look for interface like enp0s3, ens33, etc.

# Edit netplan configuration
sudo vim /etc/netplan/01-network-manager-all.yaml
```

Add this configuration (adjust for your network):

```yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    enp0s3:  # Replace with your interface name
      dhcp4: no
      addresses:
        - 192.168.1.10/24  # Your chosen static IP
      routes:
        - to: default
          via: 192.168.1.1  # Your router/gateway IP
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

Apply configuration:

```bash
sudo netplan apply

# Verify
ip addr show
ping -c 4 8.8.8.8
```

**Method 2: Using NetworkManager (Alternative)**

```bash
# Get connection name
nmcli connection show

# Configure static IP (adjust values)
sudo nmcli connection modify "Wired connection 1" \
  ipv4.addresses 192.168.1.10/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "8.8.8.8 8.8.4.4" \
  ipv4.method manual

# Restart connection
sudo nmcli connection down "Wired connection 1"
sudo nmcli connection up "Wired connection 1"

# Verify
ip addr show
```

### Step 0.5: Prepare 4GB Desktop PC (Bare-Metal Agent)

**Option A: Dual-Boot with Existing Windows**

```bash
# On your main computer, create bootable USB:
# Download Pop!_OS ISO from https://pop.system76.com

# On Linux:
sudo dd if=pop-os_22.04_amd64_intel_54.iso of=/dev/sdX bs=4M status=progress && sync
# Replace /dev/sdX with your USB device (check with lsblk)

# On Windows, use Rufus or balenaEtcher
```

**Boot from USB and Install:**
1. Boot from USB (F12, F2, or DEL during startup)
2. Select "Try or Install Pop!_OS"
3. Choose "Custom (Advanced)" installation
4. Create partitions (if dual-booting):
   - 512 MB EFI partition (if needed)
   - Remaining space for Pop!_OS root (/)
5. Complete installation

**Post-Installation:**

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install necessary tools
sudo apt install -y curl wget net-tools openssh-server

# Set hostname
sudo hostnamectl set-hostname wazuh-agent-pc1

# Configure static IP (similar to Step 0.4)
# Example: 192.168.1.20/24
```

**Option B: Fresh Pop!_OS Installation (Erase Windows)**

Same steps as above, but choose "Clean Install" to erase existing OS.

### Step 0.6: Prepare 12GB Laptop

**Replace Arch Linux with Pop!_OS:**

```bash
# Backup any important data from Arch Linux first!

# Create bootable USB (same as Step 0.5)

# Boot from USB and install Pop!_OS
# Choose "Clean Install"
# Hostname: wazuh-workstation
# Static IP: 192.168.1.30/24
```

**Post-Installation on Laptop Host:**

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install VirtualBox for Windows VM
sudo apt install -y virtualbox virtualbox-ext-pack

# Install PowerShell (for Atomic Red Team later)
# Download Microsoft package
wget https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/powershell_7.4.1-1.deb_amd64.deb

# Install PowerShell
sudo dpkg -i powershell_7.4.1-1.deb_amd64.deb
sudo apt-get install -f

# Verify PowerShell installation
pwsh --version
```

### Step 0.7: Create Windows VM on Laptop

**Download Windows 10/11 ISO:**
- Windows 10: https://www.microsoft.com/software-download/windows10
- Windows 11: https://www.microsoft.com/software-download/windows11
- Use Media Creation Tool or direct ISO download

**Create Windows VM in VirtualBox:**

```bash
# Create Windows VM
vboxmanage createvm --name "Windows-Client" --ostype Windows10_64 --register

# Configure VM
vboxmanage modifyvm "Windows-Client" \
  --memory 6144 \
  --cpus 2 \
  --vram 128 \
  --nic1 bridged \
  --bridgeadapter1 "$(ip route | grep default | awk '{print $5}')" \
  --boot1 disk \
  --boot2 dvd

# Create 60GB virtual hard disk
vboxmanage createhd --filename ~/VirtualBox\ VMs/Windows-Client/Windows-Client.vdi --size 61440

# Attach storage
vboxmanage storagectl "Windows-Client" --name "SATA Controller" --add sata --bootable on
vboxmanage storageattach "Windows-Client" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/Windows-Client/Windows-Client.vdi

# Attach Windows ISO
vboxmanage storageattach "Windows-Client" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium ~/Downloads/Win10_22H2_English_x64.iso

# Start VM
vboxmanage startvm "Windows-Client"
```

**Windows Installation:**
1. Select language and keyboard
2. "Install now"
3. Enter product key or "I don't have a product key"
4. Select Windows 10/11 Pro
5. Accept license
6. Custom installation
7. Select disk and install
8. Complete OOBE (Out-of-Box Experience)

**Configure Static IP in Windows:**
1. Open Settings → Network & Internet → Ethernet
2. Click on your connection
3. Edit IP settings → Manual IPv4
   - IP: `192.168.1.31`
   - Subnet: `255.255.255.0`
   - Gateway: `192.168.1.1` (your router)
   - DNS: `8.8.8.8`, `8.8.4.4`
4. Save

### Step 0.8: Network Configuration Summary

Create this reference document and save it:

```bash
# Create network map file
vim ~/lab-network-config.txt
```

Add this content:

```
# Blue Team Home Lab - Network Configuration
# Created: [Current Date]

## Network Segment
LAN: 192.168.1.0/24
Gateway/Router: 192.168.1.1

## Device Inventory

### Wazuh Server (VM on 16GB Desktop)
- Hostname: wazuh-server
- IP Address: 192.168.1.10
- MAC Address: [Record from: ip link show]
- OS: Pop!_OS 22.04 LTS
- RAM: 8GB
- Role: SIEM Manager + Indexer + Dashboard

### 4GB Desktop PC (Bare-Metal)
- Hostname: wazuh-agent-pc1
- IP Address: 192.168.1.20
- MAC Address: [Record from: ip link show]
- OS: Pop!_OS 22.04 LTS
- RAM: 4GB
- Role: Linux Endpoint Agent

### 12GB Laptop Host
- Hostname: wazuh-workstation
- IP Address: 192.168.1.30
- MAC Address: [Record from: ip link show]
- OS: Pop!_OS 22.04 LTS
- RAM: 6GB (6GB reserved for Windows VM)
- Role: Linux Endpoint Agent + Attack Simulation Platform

### Windows Client VM (on Laptop)
- Hostname: WIN-CLIENT01
- IP Address: 192.168.1.31
- MAC Address: [Record from Windows: ipconfig /all]
- OS: Windows 10/11 Pro
- RAM: 6GB
- Role: Windows Endpoint Agent

## Required Firewall Ports

### Wazuh Server Inbound:
- TCP 1514: Agent-Server communication
- TCP 1515: Agent enrollment
- TCP 55000: Wazuh API
- TCP 9200: Wazuh Indexer (OpenSearch)
- TCP 443: Wazuh Dashboard (HTTPS)

### All Agents Outbound:
- TCP 1514 → Wazuh Server
- TCP 1515 → Wazuh Server (enrollment)
```

### Step 0.9: Verify Network Connectivity

Test connectivity between all devices:

```bash
# From Wazuh Server VM
ping -c 4 192.168.1.20  # 4GB PC
ping -c 4 192.168.1.30  # Laptop
ping -c 4 192.168.1.31  # Windows VM
ping -c 4 8.8.8.8       # Internet

# From 4GB PC
ping -c 4 192.168.1.10  # Wazuh Server

# From Laptop
ping -c 4 192.168.1.10  # Wazuh Server

# From Windows VM (in PowerShell or CMD)
ping 192.168.1.10  # Wazuh Server
```

**If ping fails:**

```bash
# Check firewall on target machine
sudo ufw status

# Temporarily allow ICMP for testing
sudo ufw allow from 192.168.1.0/24

# Check if interface is up
ip link show

# Verify routing
ip route show
```

### Step 0.10: Document Your Architecture

Create a visual diagram (use draw.io, Lucidchart, or even ASCII art):

```bash
# Create architecture document
vim ~/lab-architecture.md
```

Example content:

```markdown
# Blue Team Home Lab Architecture
Version 1.0

## Network Topology

Internet
   |
   |
[Router] 192.168.1.1
   |
   +-- [Switch] ---+
                   |
                   +-- [Wazuh Server VM] 192.168.1.10
                   |   (on 16GB Desktop)
                   |
                   +-- [4GB Desktop PC] 192.168.1.20
                   |   (Bare-Metal Agent)
                   |
                   +-- [Laptop] 192.168.1.30
                       (Host + Agent)
                       |
                       +-- [Windows VM] 192.168.1.31
                           (Inside Laptop)

## Data Flow

Agents (1.20, 1.30, 1.31) 
   → Port 1514/TCP 
   → Wazuh Server (1.10)
   → Process & Analyze
   → Store in Indexer
   → Display in Dashboard

## Access Points

- Wazuh Dashboard: https://192.168.1.10
- SSH to Server: ssh wazuhadmin@192.168.1.10
- SSH to PC: ssh user@192.168.1.20
- SSH to Laptop: ssh user@192.168.1.30
```

### Step 0.11: Create VM Snapshot (Critical!)

Before proceeding to Phase 1, create a snapshot of your Wazuh Server VM:

#### VirtualBox Snapshot

```bash
# Power off VM gracefully first
vboxmanage controlvm "Wazuh-Server" acpipowerbutton

# Wait for shutdown, then create snapshot
vboxmanage snapshot "Wazuh-Server" take "Phase0-Complete" \
  --description "Clean OS installation before Wazuh deployment"

# List snapshots to verify
vboxmanage snapshot "Wazuh-Server" list

# Power VM back on
vboxmanage startvm "Wazuh-Server"
```

#### VMware Snapshot (if using VMware)

Use GUI:
1. VM → Snapshot → Take Snapshot
2. Name: "Phase0-Complete"
3. Description: "Clean OS installation before Wazuh deployment"

---

## Phase 1: Wazuh Server and Agent Deployment

**Duration**: Weeks 2-3 (20 hours)  
**Objective**: Deploy functional Wazuh infrastructure with all agents communicating

### Understanding the Wazuh Stack

Wazuh consists of three main components:

1. **Wazuh Manager**: Core analysis engine, receives agent data
2. **Wazuh Indexer**: Based on OpenSearch, stores and indexes events
3. **Wazuh Dashboard**: Web interface for visualization and management

Current version: **Wazuh 4.12.0** (as of February 2025)

### Step 1.1: Install Wazuh Server (All-in-One Installation)

SSH into your Wazuh Server VM or work directly in the console:

```bash
# Switch to Wazuh Server VM
ssh wazuhadmin@192.168.1.10

# Update system
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y curl apt-transport-https unzip wget \
  libcap2-bin software-properties-common lsb-release gnupg2

# Download Wazuh installation script (version 4.12)
curl -sO https://packages.wazuh.com/4.12/wazuh-install.sh

# Make executable
chmod 744 wazuh-install.sh

# Run all-in-one installation (installs Manager + Indexer + Dashboard)
sudo bash ./wazuh-install.sh -a

# This will take 10-15 minutes
# The script will display credentials at the end - SAVE THESE!
```

**CRITICAL: Save the Output!**

The installation will display something like:

```
INFO: --- Summary ---
INFO: You can access the web interface https://192.168.1.10
    User: admin
    Password: <REDACTED — yours will be unique>  # This will be different!
INFO: Installation finished.
```

**Save credentials to a file:**

```bash
# Create secure credentials file
vim ~/wazuh-credentials.txt
```

Add:

```
Wazuh Dashboard Access
URL: https://192.168.1.10
Username: admin
Password: [PASTE YOUR PASSWORD HERE]

Wazuh API Credentials:
[Will be same as above]

Installation Date: [Current Date]
Wazuh Version: 4.12.0
```

Protect this file:

```bash
chmod 600 ~/wazuh-credentials.txt
```

### Step 1.2: Configure Wazuh Server Firewall

```bash
# Allow Wazuh-specific ports
sudo ufw allow 1514/tcp   # Agent communication
sudo ufw allow 1515/tcp   # Agent enrollment
sudo ufw allow 55000/tcp  # Wazuh API
sudo ufw allow 443/tcp    # Dashboard HTTPS

# Allow from your local network only (more secure)
sudo ufw allow from 192.168.1.0/24 to any port 1514 proto tcp
sudo ufw allow from 192.168.1.0/24 to any port 1515 proto tcp
sudo ufw allow from 192.168.1.0/24 to any port 55000 proto tcp
sudo ufw allow from 192.168.1.0/24 to any port 443 proto tcp

# Check status
sudo ufw status numbered
```

### Step 1.3: Verify Wazuh Services

```bash
# Check Wazuh Manager
sudo systemctl status wazuh-manager

# Check Wazuh Indexer
sudo systemctl status wazuh-indexer

# Check Wazuh Dashboard
sudo systemctl status wazuh-dashboard

# All should show "active (running)"

# Check Wazuh cluster status
sudo /var/ossec/bin/cluster_control -l

# View manager logs (useful for troubleshooting)
sudo tail -f /var/ossec/logs/ossec.log
```

### Step 1.4: Access Wazuh Dashboard

From any computer on your network:

1. Open web browser
2. Navigate to: `https://192.168.1.10`
3. You'll see SSL warning (expected) - click "Advanced" → "Proceed"
4. Login with saved credentials:
   - Username: `admin`
   - Password: [from your credentials file]

**First Login Tasks:**
- Explore the interface
- Note the "No agents connected" message
- Familiarize yourself with menu structure

### Step 1.5: Install Wazuh Agent on Server VM (Self-Monitoring)

Install agent on the Wazuh server itself to monitor its own security:

```bash
# On Wazuh Server VM

# Add Wazuh repository
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list

# Update package list
sudo apt update

# Install Wazuh agent
sudo apt install wazuh-agent -y

# Configure agent to point to local manager
sudo vi /var/ossec/etc/ossec.conf
```

Find the `<client>` section and modify:

```xml
<client>
  <server>
    <address>127.0.0.1</address>
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
</client>
```

Enable and start the agent:

```bash
# Enable agent to start on boot
sudo systemctl enable wazuh-agent

# Start agent
sudo systemctl start wazuh-agent

# Check status
sudo systemctl status wazuh-agent

# View agent logs
sudo tail -f /var/ossec/logs/ossec.log
```

**Verify in Dashboard:**
1. Refresh Wazuh Dashboard
2. Go to "Agents" section
3. You should see one agent (the server itself) listed
4. Status should be "Active"

### Step 1.6: Install Wazuh Agent on 4GB Desktop PC

```bash
# On the 4GB Desktop PC
ssh user@192.168.1.20

# Add Wazuh repository
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list

# Update and install
sudo apt update
sudo apt install wazuh-agent -y

# Configure agent
sudo vi /var/ossec/etc/ossec.conf
```

Modify the `<client>` section:

```xml
<client>
  <server>
    <address>192.168.1.10</address>  <!-- Wazuh Server IP -->
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
</client>
```

Set agent name and start:

```bash
# Set agent name (optional but recommended)
echo "wazuh-agent-pc1" | sudo tee /var/ossec/etc/agent-name

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent

# Check status
sudo systemctl status wazuh-agent

# View logs to confirm connection
sudo tail -f /var/ossec/logs/ossec.log

# Look for: "INFO: Connected to the server"
```

### Step 1.7: Install Wazuh Agent on Laptop (Pop!_OS Host)

```bash
# On your laptop
ssh user@192.168.1.30

# Same process as 4GB PC

# Add repository
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list

# Install
sudo apt update
sudo apt install wazuh-agent -y

# Configure
sudo vi /var/ossec/etc/ossec.conf
```

Set server address to `192.168.1.10` in the `<client>` section.

```bash
# Set agent name
echo "wazuh-workstation" | sudo tee /var/ossec/etc/agent-name

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent

# Verify
sudo systemctl status wazuh-agent
```

### Step 1.8: Install Wazuh Agent on Windows VM

**Download Windows Agent:**

1. On Windows VM, open browser
2. Go to Wazuh Dashboard: `https://192.168.1.10`
3. Login
4. Click "Add agent" or go to Settings → Agent

**Alternative: Direct Download**

Open PowerShell as Administrator on Windows VM:

```powershell
# Download Wazuh agent installer
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.12.0-1.msi -OutFile wazuh-agent.msi

# Install agent with server configuration
msiexec.exe /i wazuh-agent.msi /q WAZUH_MANAGER="192.168.1.10" WAZUH_AGENT_NAME="WIN-CLIENT01" WAZUH_REGISTRATION_SERVER="192.168.1.10"

# Start Wazuh service
NET START WazuhSvc

# Verify service is running
Get-Service WazuhSvc
```

**GUI Installation Method:**

1. Double-click downloaded `wazuh-agent-4.12.0-1.msi`
2. Follow wizard:
   - Accept license
   - **Important**: When asked for manager address, enter: `192.168.1.10`
   - Agent name: `WIN-CLIENT01`
   - Complete installation
3. Wazuh service starts automatically

**Verify Windows Agent:**

```powershell
# Check service status
Get-Service WazuhSvc | Format-List

# View agent log
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 20

# Check agent configuration
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.conf"
```

### Step 1.9: Verify All Agents in Dashboard

1. Login to Wazuh Dashboard: `https://192.168.1.10`
2. Navigate to "Agents" section
3. You should see 4 agents:
   - **wazuh-server** (or similar) - Status: Active
   - **wazuh-agent-pc1** - Status: Active
   - **wazuh-workstation** - Status: Active
   - **WIN-CLIENT01** - Status: Active

**If agent shows as "Disconnected":**

```bash
# On Linux agents:
sudo systemctl restart wazuh-agent
sudo tail -f /var/ossec/logs/ossec.log

# On Windows agent (PowerShell as Admin):
Restart-Service WazuhSvc
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 20
```

### Step 1.10: Generate Test Events

Create some activity to verify log collection:

**On Linux agents:**

```bash
# Create some authentication events
sudo su
exit

# Create some file changes
echo "test" > ~/testfile.txt
rm ~/testfile.txt

# Generate some system events
sudo systemctl status ssh
```

**On Windows agent:**

```powershell
# Create logon events
# Simply lock and unlock your screen (Windows+L)

# Create file system events
New-Item -Path C:\Users\Public\testfile.txt -ItemType File
Remove-Item C:\Users\Public\testfile.txt

# View Security event log
Get-EventLog -LogName Security -Newest 10
```

**Check Events in Dashboard:**

1. Go to Wazuh Dashboard → Events
2. You should see events from all agents
3. Filter by agent name to view specific agent events
4. Explore different event types

### Step 1.11: Create Phase 1 Snapshot

```bash
# On Wazuh Server VM, power off gracefully
sudo shutdown -h now

# From host machine
vboxmanage snapshot "Wazuh-Server" take "Phase1-Complete" \
  --description "Wazuh fully deployed, all 4 agents active"

# Start VM again
vboxmanage startvm "Wazuh-Server" --type headless
```

---

## Phase 2: Heterogeneous Log Ingestion and Data Normalization

**Duration**: Weeks 3-4 (15 hours)  
**Objective**: Configure comprehensive log collection from Windows and Linux endpoints

### Understanding Log Sources

| Log Source | Platform | Key Information |
|------------|----------|----------------|
| Windows Event Logs | Windows | Logons, account management, policy changes |
| Syslog | Linux | System events, service status |
| Auth.log | Linux | Authentication attempts, sudo usage |
| Auditd | Linux | System calls, file access |
| File Integrity Monitoring | Both | File changes in critical directories |

### Step 2.1: Configure Windows Event Log Collection

**On Windows VM**, edit Wazuh agent configuration:

```powershell
# Open config file in notepad (as Administrator)
notepad "C:\Program Files (x86)\ossec-agent\ossec.conf"
```

Find the `<localfile>` section and add these configurations:

```xml
<!-- Windows Security Event Channel -->
<localfile>
  <location>Security</location>
  <log_format>eventchannel</log_format>
</localfile>

<!-- Windows System Event Channel -->
<localfile>
  <location>System</location>
  <log_format>eventchannel</log_format>
</localfile>

<!-- Windows Application Event Channel -->
<localfile>
  <location>Application</location>
  <log_format>eventchannel</log_format>
</localfile>

<!-- Windows PowerShell Event Channel (Important for detecting malicious scripts) -->
<localfile>
  <location>Microsoft-Windows-PowerShell/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>

<!-- Windows Sysmon Event Channel (if Sysmon is installed - recommended) -->
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

**Restart Wazuh agent:**

```powershell
Restart-Service WazuhSvc

# Verify service restarted successfully
Get-Service WazuhSvc

# Check logs for errors
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 30
```

### Step 2.2: Install Sysmon on Windows (Highly Recommended)

Sysmon provides detailed process creation, network connection, and file creation events.

```powershell
# Download Sysmon
Invoke-WebRequest -Uri https://download.sysinternals.com/files/Sysmon.zip -OutFile C:\Users\Public\Sysmon.zip

# Extract
Expand-Archive C:\Users\Public\Sysmon.zip -DestinationPath C:\Users\Public\Sysmon

# Download SwiftOnSecurity's Sysmon config (excellent starting point)
Invoke-WebRequest -Uri https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml -OutFile C:\Users\Public\Sysmon\sysmonconfig.xml

# Install Sysmon with configuration
cd C:\Users\Public\Sysmon
.\Sysmon64.exe -accepteula -i sysmonconfig.xml

# Verify installation
Get-Service Sysmon64

# Check event log
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 10
```

**Restart Wazuh agent to start collecting Sysmon events:**

```powershell
Restart-Service WazuhSvc
```

### Step 2.3: Configure Linux System Log Collection

**On 4GB PC and Laptop**, edit Wazuh agent configuration:

```bash
sudo vi /var/ossec/etc/ossec.conf
```

Verify these `<localfile>` entries exist (should be default):

```xml
<!-- System log -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/syslog</location>
</localfile>

<!-- Authentication log -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/auth.log</location>
</localfile>

<!-- Kernel log -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/kern.log</location>
</localfile>
```

### Step 2.4: Enable Linux Audit Framework (auditd)

Auditd monitors system calls and provides detailed security-relevant events.

**Install and configure auditd:**

```bash
# Install auditd
sudo apt install -y auditd audispd-plugins

# Enable and start auditd
sudo systemctl enable auditd
sudo systemctl start auditd

# Check status
sudo systemctl status auditd

# View current audit rules
sudo auditctl -l
```

**Add custom audit rules:**

```bash
# Edit audit rules file
sudo vi /etc/audit/rules.d/audit.rules
```

Add these security-focused rules:

```bash
# Delete all existing rules
-D

# Buffer Size (increase if events are lost)
-b 8192

# Failure Mode (0=silent, 1=printk, 2=panic)
-f 1

# Monitor authentication files
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/gshadow -p wa -k gshadow_changes

# Monitor sudo configuration
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes

# Monitor system calls
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time_change

# Monitor user/group modifications
-a always,exit -F arch=b64 -S setuid -S setgid -S setreuid -S setregid -k privilege_escalation
-a always,exit -F arch=b32 -S setuid -S setgid -S setreuid -S setregid -k privilege_escalation

# Monitor network connections
-a always,exit -F arch=b64 -S socket -S connect -k network_connections
-a always,exit -F arch=b32 -S socket -S connect -k network_connections

# Make configuration immutable (reboot required to change)
-e 2
```

**Load the rules and configure Wazuh:**

```bash
# Reload audit rules
sudo augenrules --load

# Verify rules loaded
sudo auditctl -l

# Configure Wazuh to read audit logs
sudo vi /var/ossec/etc/ossec.conf
```

Add this in the `<localfile>` section:

```xml
<!-- Audit log -->
<localfile>
  <log_format>audit</log_format>
  <location>/var/log/audit/audit.log</location>
</localfile>
```

**Restart services:**

```bash
sudo systemctl restart auditd
sudo systemctl restart wazuh-agent
```

### Step 2.5: Configure File Integrity Monitoring (FIM)

FIM alerts on unauthorized changes to critical files and directories.

**On all Linux agents**, edit Wazuh configuration:

```bash
sudo vi /var/ossec/etc/ossec.conf
```

Find the `<syscheck>` section and configure:

```xml
<syscheck>
  <!-- Frequency of checks (every 12 hours) -->
  <frequency>43200</frequency>

  <!-- Directories to monitor -->
  
  <!-- Monitor /etc directory (system configuration) -->
  <directories check_all="yes" realtime="no" report_changes="yes">/etc</directories>
  
  <!-- Monitor user binaries -->
  <directories check_all="yes" realtime="no">/usr/bin</directories>
  <directories check_all="yes" realtime="no">/usr/sbin</directories>
  
  <!-- Monitor system binaries -->
  <directories check_all="yes" realtime="no">/bin</directories>
  <directories check_all="yes" realtime="no">/sbin</directories>
  
  <!-- Monitor user home directories (adjust based on your users) -->
  <directories check_all="yes" realtime="yes" report_changes="yes">/home</directories>
  
  <!-- Monitor boot directory -->
  <directories check_all="yes" realtime="no">/boot</directories>

  <!-- Files to ignore (reduce noise) -->
  <ignore>/etc/mtab</ignore>
  <ignore>/etc/hosts.deny</ignore>
  <ignore>/etc/mail/statistics</ignore>
  <ignore>/etc/random-seed</ignore>
  <ignore>/etc/random.seed</ignore>
  <ignore>/etc/adjtime</ignore>
  <ignore>/etc/httpd/logs</ignore>
  <ignore>/etc/utmpx</ignore>
  <ignore>/etc/wtmpx</ignore>
  <ignore>/etc/cups/certs</ignore>
  <ignore>/etc/dumpdates</ignore>
  <ignore>/etc/svc/volatile</ignore>

  <!-- Check every 6 hours -->
  <frequency>21600</frequency>
  
  <!-- Generate alerts for new files -->
  <alert_new_files>yes</alert_new_files>
  
  <!-- Use optimized synchronization -->
  <synchronization>
    <enabled>yes</enabled>
    <interval>5m</interval>
    <max_interval>1h</max_interval>
  </synchronization>
</syscheck>
```

**On Windows VM**, configure FIM:

```xml
<syscheck>
  <frequency>43200</frequency>
  
  <!-- Monitor Windows System directories -->
  <directories check_all="yes" realtime="yes" report_changes="yes">C:\Windows\System32</directories>
  <directories check_all="yes" realtime="yes">C:\Windows\SysWOW64</directories>
  <directories check_all="yes" realtime="yes">C:\Program Files</directories>
  <directories check_all="yes" realtime="yes">C:\Program Files (x86)</directories>
  
  <!-- Monitor user directories -->
  <directories check_all="yes" realtime="yes" report_changes="yes">C:\Users</directories>
  
  <!-- Monitor startup locations -->
  <directories check_all="yes" realtime="yes">C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup</directories>
  
  <!-- Ignore temp files -->
  <ignore>C:\Windows\Temp</ignore>
  <ignore>C:\Windows\System32\config\systemprofile\AppData\Local\Temp</ignore>
  <ignore>C:\Users\*\AppData\Local\Temp</ignore>
  
  <!-- Windows Registry monitoring -->
  <windows_registry check_all="yes">HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run</windows_registry>
  <windows_registry check_all="yes">HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunOnce</windows_registry>
  <windows_registry check_all="yes">HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunOnceEx</windows_registry>
  
  <alert_new_files>yes</alert_new_files>
  
  <synchronization>
    <enabled>yes</enabled>
    <interval>5m</interval>
    <max_interval>1h</max_interval>
  </synchronization>
</syscheck>
```

**Restart all agents after FIM configuration:**

```bash
# Linux
sudo systemctl restart wazuh-agent

# Windows (PowerShell as Admin)
Restart-Service WazuhSvc
```

### Step 2.6: Test Log Collection

**Generate Windows Events:**

```powershell
# Failed login (wrong password at login screen or with runas)
runas /user:fakeuser cmd

# Successful login (your current login already generated Event ID 4624)

# Create/modify file in monitored directory
New-Item -Path "C:\Program Files\testfile.txt" -ItemType File
Start-Sleep -Seconds 5
Remove-Item "C:\Program Files\testfile.txt"

# PowerShell command execution
Get-Process | Where-Object {$_.CPU -gt 1}

# Registry change (will trigger FIM)
New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "TestEntry" -Value "C:\test.exe" -PropertyType String -Force
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "TestEntry"
```

**Generate Linux Events:**

```bash
# Authentication events
sudo su
exit

# File modifications
sudo touch /etc/test_file
sudo rm /etc/test_file

# Network connection (will be caught by auditd)
curl https://www.google.com

# Privilege escalation
sudo whoami
```

**View Events in Dashboard:**

1. Login to Wazuh Dashboard
2. Go to "Security Events" or "Events"
3. Use filters:
   - Agent: Select specific agent
   - Rule Level: Different severity levels
   - Rule ID: Specific detection rules
4. Look for:
   - **Event ID 4624** (Windows successful logon)
   - **Event ID 4625** (Windows failed logon)
   - **Event ID 4688** (Windows process creation)
   - **FIM alerts** (syscheck events)
   - **Auditd events** on Linux

### Step 2.7: Create Custom Visualization

1. In Wazuh Dashboard, go to "Modules" → "Security Events"
2. Click "Visualizations"
3. Create a new visualization:
   - Type: Vertical Bar Chart
   - Data Source: wazuh-alerts-*
   - Metrics: Count
   - Buckets: Terms aggregation on `rule.level`
   - Size: 10
4. Save as "Events by Severity Level"

### Step 2.8: Export Configuration for Documentation

```bash
# On each Linux agent
sudo cat /var/ossec/etc/ossec.conf > ~/wazuh-agent-config-linux.xml

# On Wazuh Server
sudo cat /var/ossec/etc/ossec.conf > ~/wazuh-server-config.xml

# On Windows (PowerShell)
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.conf" | Out-File C:\Users\Public\wazuh-agent-config-windows.xml
```

**Create Phase 2 Documentation:**

```bash
# Create Phase 2 summary
vim ~/phase2-summary.md
```

Content:

```markdown
# Phase 2 Complete: Log Ingestion and Data Normalization

## Configured Log Sources

### Windows VM (192.168.1.31)
- Security Event Log
- System Event Log  
- Application Event Log
- PowerShell Operational Log
- Sysmon Operational Log (installed)
- File Integrity Monitoring on:
  - C:\Windows\System32
  - C:\Program Files
  - C:\Users
- Registry monitoring on Run keys

### Linux Endpoints (192.168.1.20, 192.168.1.30)
- /var/log/syslog
- /var/log/auth.log
- /var/log/kern.log
- /var/log/audit/audit.log (auditd configured)
- File Integrity Monitoring on:
  - /etc
  - /usr/bin, /usr/sbin
  - /bin, /sbin
  - /home
  - /boot

## Verification Results
- Total agents: 4
- All agents status: Active
- Average events per minute: [Record from dashboard]
- Total rules triggered: [Record from dashboard]

## Next Steps
- Phase 3: Threat simulation with Atomic Red Team
```

---

## Phase 3: Threat Simulation and Observational Analysis

**Duration**: Weeks 5-6 (25 hours)  
**Objective**: Simulate 10+ ATT&CK techniques and observe detection capabilities

### Understanding Atomic Red Team

Atomic Red Team is a library of simple tests mapped to the MITRE ATT&CK framework. Each test:
- Represents a specific adversary technique
- Can be executed with minimal setup
- Generates observable security events
- Helps validate detection capabilities

### Step 3.1: Create Wazuh Server Snapshot (Safety First!)

```bash
# Power off Wazuh Server gracefully
ssh wazuhadmin@192.168.1.10
sudo shutdown -h now

# Create snapshot
vboxmanage snapshot "Wazuh-Server" take "Phase2-Complete-PreAttackSim" \
  --description "Before attack simulation - all logs configured"

# Start VM
vboxmanage startvm "Wazuh-Server" --type headless
```

### Step 3.2: Install PowerShell on Linux (Required for Atomic Red Team)

**On your laptop (192.168.1.30):**

```bash
# Update package list
sudo apt update

# Install prerequisites
sudo apt install -y wget apt-transport-https software-properties-common

# Download Microsoft repository GPG keys
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"

# Register repository
sudo dpkg -i packages-microsoft-prod.deb

# Update package list
sudo apt update

# Install PowerShell
sudo apt install -y powershell

# Verify installation
pwsh --version

# Should output: PowerShell 7.4.x or higher
```

### Step 3.3: Install Atomic Red Team

```bash
# Launch PowerShell
pwsh

# Install Atomic Red Team module from PowerShell Gallery
Install-Module -Name invoke-atomicredteam,powershell-yaml -Scope CurrentUser -Force

# If prompted about untrusted repository, type 'Y' and press Enter

# Install Atomic Red Team framework
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing); 
Install-AtomicRedTeam -getAtomics -Force

# This downloads all atomic tests to ~/AtomicRedTeam/
# Takes 5-10 minutes

# Verify installation
Get-Command Invoke-AtomicTest

# List available atomic tests
Invoke-AtomicTest -ListOf AtomicTests | Select-Object -First 10
```

### Step 3.4: Create Attack Simulation Log

```bash
# Create directory for attack logs
mkdir -p ~/atomic-tests-log

# Create log template
cat > ~/atomic-tests-log/attack-log-template.md << 'EOF'
# Atomic Red Team Attack Simulation Log

## Test Information
- **Technique ID**: 
- **Technique Name**: 
- **Test Number**: 
- **Date/Time**: 
- **Tester**: 
- **Target System**: 

## Pre-Test State
- Wazuh Dashboard baseline: 
- Active alerts: 

## Test Execution
### Command Used:
```
[Paste command here]
```

### Execution Output:
```
[Paste output here]
```

## Observations

### Expected Behavior:


### Actual Behavior:


### Wazuh Alerts Generated:
- Alert ID: 
- Rule ID: 
- Rule Level: 
- Description: 
- Timestamp: 

### Screenshots:
[Attach screenshots if relevant]

## Analysis

### Detection Quality:
- [ ] Attack was detected
- [ ] Alert accuracy: High / Medium / Low
- [ ] False positive risk: High / Medium / Low

### Recommendations:
- [ ] Create custom rule
- [ ] Tune existing rule
- [ ] Add correlation
- [ ] No action needed

## Follow-Up Actions:


---
EOF
```

### Step 3.5: Execute First Attack - T1059.001 (PowerShell Command Execution)

**Understand the technique:**
- MITRE ATT&CK ID: T1059.001
- Tactic: Execution
- Description: Adversaries may abuse PowerShell for execution

**Check test details:**

```powershell
# In PowerShell
Invoke-AtomicTest T1059.001 -ShowDetails
```

**Execute the test:**

```powershell
# Run test #1 (simple PowerShell command)
Invoke-AtomicTest T1059.001 -TestNumbers 1

# You'll see output of commands being executed
```

**Observe in Wazuh Dashboard:**

1. Go to Wazuh Dashboard → Security Events
2. Filter by:
   - Agent: wazuh-workstation (192.168.1.30)
   - Time range: Last 15 minutes
3. Look for:
   - Rule descriptions containing "PowerShell" or "command"
   - Rule level ≥ 3

**Document findings:**

```bash
# Copy template
cp ~/atomic-tests-log/attack-log-template.md ~/atomic-tests-log/T1059.001-test.md

# Edit with findings
vim ~/atomic-tests-log/T1059.001-test.md
```

Example entry:

```markdown
## Test Information
- **Technique ID**: T1059.001
- **Technique Name**: Command and Scripting Interpreter: PowerShell
- **Test Number**: 1
- **Date/Time**: 2025-02-11 14:30:00
- **Tester**: [Your Name]
- **Target System**: wazuh-workstation (192.168.1.30)

## Test Execution
### Command Used:
```powershell
Invoke-AtomicTest T1059.001 -TestNumbers 1
```

### Execution Output:
```
Executing test: T1059.001-1 - Mimikatz
Executing: powershell.exe -exec bypass -command "Write-Host 'test'"
```

## Observations
### Wazuh Alerts Generated:
- Alert ID: 1708523400.123456
- Rule ID: 91816
- Rule Level: 3
- Description: PowerShell execution detected
- Timestamp: 2025-02-11 14:30:15

### Analysis:
Attack was detected by default Wazuh rules. Rule level is relatively low (3).
Recommendation: Create custom rule with higher severity for suspicious PowerShell patterns.
```

### Step 3.6: Execute Attack Series (10 Techniques)

Execute these 10 techniques systematically, documenting each:

#### Test 1: T1059.001 - PowerShell Execution
```powershell
Invoke-AtomicTest T1059.001 -TestNumbers 1,2
```

#### Test 2: T1003.001 - OS Credential Dumping: LSASS Memory
```powershell
# This simulates credential dumping (requires admin)
Invoke-AtomicTest T1003.001 -TestNumbers 1 -GetPrereqs
Invoke-AtomicTest T1003.001 -TestNumbers 1
```

#### Test 3: T1071.001 - Web Protocols (Command and Control)
```powershell
Invoke-AtomicTest T1071.001 -TestNumbers 1
```

#### Test 4: T1055 - Process Injection
```powershell
Invoke-AtomicTest T1055 -TestNumbers 1 -GetPrereqs
Invoke-AtomicTest T1055 -TestNumbers 1
```

#### Test 5: T1548.002 - Bypass User Account Control
```powershell
Invoke-AtomicTest T1548.002 -TestNumbers 1
```

#### Test 6: T1027 - Obfuscated Files or Information
```powershell
Invoke-AtomicTest T1027 -TestNumbers 1
```

#### Test 7: T1053.005 - Scheduled Task/Job: Scheduled Task
```powershell
Invoke-AtomicTest T1053.005 -TestNumbers 1 -GetPrereqs
Invoke-AtomicTest T1053.005 -TestNumbers 1
```

#### Test 8: T1566.001 - Phishing: Spearphishing Attachment
```powershell
Invoke-AtomicTest T1566.001 -TestNumbers 1
```

#### Test 9: T1082 - System Information Discovery
```powershell
Invoke-AtomicTest T1082 -TestNumbers 1,2
```

#### Test 10: T1070.004 - File Deletion
```powershell
Invoke-AtomicTest T1070.004 -TestNumbers 1
```

### For Windows VM Testing

**Test 11: T1547.001 - Boot or Logon Autostart Execution: Registry Run Keys**

On Windows VM (192.168.1.31), open PowerShell as Administrator:

```powershell
# Install Atomic Red Team on Windows
Set-ExecutionPolicy Bypass -Scope Process -Force
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
Install-AtomicRedTeam -getAtomics -Force

# Execute test
Invoke-AtomicTest T1547.001 -TestNumbers 1

# Check in Wazuh Dashboard for:
# - Registry modification alerts
# - FIM alerts on registry Run keys
```

### Step 3.7: Observational Analysis Framework

For each test, analyze using this framework:

```markdown
## Analysis Framework

### 1. Detection Quality
- Was the attack detected? (Yes/No)
- Time to detection: (seconds/minutes)
- Detection method: (Default rule / FIM / Network monitoring / etc.)

### 2. Alert Fidelity
- True Positive / False Positive / Unclear
- Alert noise level: (High / Medium / Low)
- Context provided: (Sufficient / Insufficient)

### 3. Response Recommendations
- Immediate action needed: (Yes/No)
- Investigation priority: (Critical / High / Medium / Low)
- Containment strategy: (Isolate / Block / Monitor / etc.)

### 4. Detection Gaps
- What was NOT detected?
- What additional logging is needed?
- What custom rules should be created?

### 5. MITRE ATT&CK Mapping
- Tactic: [e.g., Execution]
- Technique: [e.g., T1059.001]
- Sub-technique: [if applicable]
- Detection data source: [e.g., Process monitoring]
```

### Step 3.8: Cleanup After Tests

```powershell
# Clean up artifacts from Atomic Red Team tests
Invoke-AtomicTest T1059.001 -Cleanup
Invoke-AtomicTest T1003.001 -Cleanup
Invoke-AtomicTest T1071.001 -Cleanup
# etc. for each test

# Or clean up all tests at once
Get-AtomicTest | ForEach-Object { Invoke-AtomicTest $_.Technique -Cleanup }
```

### Step 3.9: Create Attack Simulation Report

```bash
# Create comprehensive report
vim ~/phase3-attack-simulation-report.md
```

Template:

```markdown
# Phase 3: Attack Simulation Report

## Executive Summary
- Total techniques tested: 11
- Successful detections: X/11
- Detection rate: X%
- Average time to detection: X seconds
- Critical gaps identified: X

## Detailed Results

### Technique Summary Table

| Technique ID | Name | Detected | Alert Level | Custom Rule Needed |
|--------------|------|----------|-------------|-------------------|
| T1059.001 | PowerShell | Yes | 3 | Yes |
| T1003.001 | LSASS Dump | Yes | 12 | No |
| ... | ... | ... | ... | ... |

## Detection Gaps Identified

1. **Base64 Obfuscation (T1027)**
   - Current status: Not detected by default rules
   - Recommendation: Create custom rule to detect Base64 patterns in PowerShell
   - Priority: High

2. **[Additional gaps...]**

## High-Value Detections

1. **LSASS Memory Dumping (T1003.001)**
   - Detected by: Rule 61693
   - Alert level: 12 (High)
   - Context: Excellent - process name, user, command line
   - Action: Already effective, no tuning needed

## Recommendations for Phase 4

Based on simulation results, the following custom rules should be developed:
1. Enhanced PowerShell Base64 detection
2. Suspicious scheduled task creation
3. Unusual network connections from office applications
4. Registry persistence mechanisms
5. File download via PowerShell/certutil

## MITRE ATT&CK Coverage

Tactics tested:
- [x] Execution
- [x] Persistence
- [x] Privilege Escalation
- [x] Defense Evasion
- [x] Credential Access
- [x] Discovery
- [x] Command and Control
- [ ] Lateral Movement (Phase 4)
- [ ] Exfiltration (Phase 4)

## Evidence Archive

All attack logs stored in: ~/atomic-tests-log/
Screenshots stored in: ~/atomic-tests-log/screenshots/
```

---

## Phase 4: Custom Detection Rule Engineering

**Duration**: Weeks 7-8 (30 hours)  
**Objective**: Create 12+ custom Wazuh rules based on Phase 3 observations

### Understanding Wazuh Rules

Wazuh rules are written in XML and consist of:
- **Rule ID**: Unique identifier (100000+ for custom rules)
- **Level**: Severity (0-15, where 15 is critical)
- **Description**: Human-readable alert message
- **Conditions**: Matching criteria (regex, field values, etc.)
- **Groups**: Categorization for organization

### Step 4.1: Access Wazuh Rule Structure

```bash
# SSH to Wazuh Server
ssh wazuhadmin@192.168.1.10

# View default rules (read-only)
ls /var/ossec/ruleset/rules/

# Custom rules go here
sudo ls -la /var/ossec/etc/rules/

# Create backup of local_rules.xml
sudo cp /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml.backup

# Edit custom rules file
sudo vim /var/ossec/etc/rules/local_rules.xml
```

### Step 4.2: Understanding Rule Syntax

Basic rule structure:

```xml
<group name="custom_rules,">
  <rule id="100001" level="10">
    <if_sid>PARENT_RULE_ID</if_sid>
    <field name="FIELD_NAME">REGEX_PATTERN</field>
    <description>Alert description text</description>
    <mitre>
      <id>T1059.001</id>
    </mitre>
  </rule>
</group>
```

Common elements:
- `<if_sid>`: Builds on existing rule
- `<field name="">`: Matches specific field
- `<regex>`: Pattern matching
- `<match>`: Simple string match
- `<options>`: Additional conditions (no_log, alert_by_email, etc.)

### Step 4.3: Custom Rule #1 - PowerShell Base64 Obfuscation

Based on Phase 3 findings, create rule to detect Base64 encoding/decoding:

```xml
<!--
Custom Rule: Detect PowerShell Base64 String Operations
Technique: T1027 (Obfuscated Files or Information)
Source: Phase 3 Attack Simulation
-->
<group name="custom_powershell,">
  
  <rule id="100001" level="12">
    <if_sid>91816</if_sid> <!-- PowerShell execution rule -->
    <field name="win.eventdata.commandLine" type="pcre2">(?i)(FromBase64String|ToBase64String|-enc|-EncodedCommand)</field>
    <description>PowerShell Base64 encoding/decoding detected - Possible obfuscation (T1027)</description>
    <mitre>
      <id>T1027</id>
    </mitre>
    <group>attack,execution,</group>
  </rule>

</group>
```

### Step 4.4: Custom Rule #2 - Suspicious Process Injection

```xml
<!--
Custom Rule: Detect Process Injection Attempts
Technique: T1055 (Process Injection)
Detection: Unusual parent-child process relationships
-->
<group name="custom_process_injection,">

  <rule id="100002" level="14">
    <if_sid>61603</if_sid> <!-- Windows process creation -->
    <field name="win.eventdata.parentImage" type="pcre2">(?i)(\\\\svchost\\.exe|\\\\services\\.exe)</field>
    <field name="win.eventdata.image" type="pcre2">(?i)(\\\\powershell\\.exe|\\\\cmd\\.exe|\\\\wscript\\.exe|\\\\cscript\\.exe)</field>
    <description>Suspicious parent-child process relationship detected - Possible injection (T1055)</description>
    <mitre>
      <id>T1055</id>
    </mitre>
    <group>attack,privilege_escalation,</group>
  </rule>

</group>
```

### Step 4.5: Custom Rule #3 - Credential Access via Registry

```xml
<!--
Custom Rule: Detect Credential Access in Registry
Technique: T1552.002 (Credentials in Registry)
Detection: Registry queries for passwords
-->
<group name="custom_credential_access,">

  <rule id="100003" level="10">
    <if_sid>61612</if_sid> <!-- Registry access -->
    <field name="win.eventdata.commandLine" type="pcre2">(?i)reg\s+query.*password|reg\s+query.*passwd|reg\s+query.*pwd</field>
    <description>Registry query for passwords detected - Credential harvesting attempt (T1552.002)</description>
    <mitre>
      <id>T1552.002</id>
    </mitre>
    <group>attack,credential_access,</group>
  </rule>

</group>
```

### Step 4.6: Custom Rule #4 - Suspicious Scheduled Task Creation

```xml
<!--
Custom Rule: Detect Suspicious Scheduled Task
Technique: T1053.005 (Scheduled Task/Job)
Detection: schtasks.exe with suspicious parameters
-->
<group name="custom_persistence,">

  <rule id="100004" level="12">
    <if_sid>61603</if_sid> <!-- Process creation -->
    <field name="win.eventdata.image" type="pcre2">(?i)\\\\schtasks\\.exe</field>
    <field name="win.eventdata.commandLine" type="pcre2">(?i)/create.*(/sc\s+(minute|hourly|daily)|/ru\s+system)</field>
    <description>Suspicious scheduled task creation detected (T1053.005)</description>
    <mitre>
      <id>T1053.005</id>
    </mitre>
    <group>attack,persistence,</group>
  </rule>

</group>
```

### Step 4.7: Custom Rule #5 - Network Connection from Office App

```xml
<!--
Custom Rule: Detect Network Connections from Office Applications
Technique: T1071.001 (Application Layer Protocol: Web)
Detection: Office apps making HTTP/HTTPS connections
-->
<group name="custom_command_control,">

  <rule id="100005" level="10">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.parentImage" type="pcre2">(?i)(\\\\WINWORD\\.EXE|\\\\EXCEL\\.EXE|\\\\POWERPNT\\.EXE)</field>
    <field name="win.eventdata.image" type="pcre2">(?i)(\\\\powershell\\.exe|\\\\cmd\\.exe|\\\\wscript\\.exe)</field>
    <description>Suspicious child process from Office application - Possible macro execution (T1071.001)</description>
    <mitre>
      <id>T1071.001</id>
    </mitre>
    <group>attack,command_and_control,</group>
  </rule>

</group>
```

### Step 4.8: Custom Rule #6 - LSASS Memory Access

```xml
<!--
Custom Rule: Enhanced LSASS Memory Access Detection
Technique: T1003.001 (OS Credential Dumping: LSASS)
Detection: Direct memory access to lsass.exe
-->
<group name="custom_credential_dump,">

  <rule id="100006" level="15">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.targetImage" type="pcre2">(?i)\\\\lsass\\.exe</field>
    <field name="win.eventdata.grantedAccess">0x1FFFFF</field>
    <description>CRITICAL: LSASS memory access detected - Credential dumping attempt (T1003.001)</description>
    <mitre>
      <id>T1003.001</id>
    </mitre>
    <group>attack,credential_access,</group>
    <options>alert_by_email</options>
  </rule>

</group>
```

### Step 4.9: Linux Custom Rules

#### Custom Rule #7 - Suspicious Sudo Usage

```xml
<!--
Custom Rule: Detect Suspicious Sudo Commands
Technique: T1548.003 (Sudo and Sudo Caching)
Detection: Unusual commands executed with sudo
-->
<group name="custom_linux_privilege,">

  <rule id="100007" level="12">
    <if_group>syslog</if_group>
    <match>sudo</match>
    <field name="command" type="pcre2">(?i)(nc|ncat|socat|bash -i|sh -i|/bin/sh|/bin/bash.*-c)</field>
    <description>Suspicious command executed with sudo - Possible reverse shell (T1548.003)</description>
    <mitre>
      <id>T1548.003</id>
    </mitre>
    <group>attack,privilege_escalation,linux,</group>
  </rule>

</group>
```

#### Custom Rule #8 - SSH Key Addition

```xml
<!--
Custom Rule: Detect SSH Authorized Keys Modification
Technique: T1098.004 (Account Manipulation: SSH Authorized Keys)
Detection: Changes to ~/.ssh/authorized_keys
-->
<group name="custom_linux_persistence,">

  <rule id="100008" level="10">
    <if_sid>550</if_sid> <!-- FIM rule -->
    <field name="file">authorized_keys</field>
    <description>SSH authorized_keys file modified - Possible persistence mechanism (T1098.004)</description>
    <mitre>
      <id>T1098.004</id>
    </mitre>
    <group>attack,persistence,linux,</group>
  </rule>

</group>
```

#### Custom Rule #9 - Suspicious Network Connections

```xml
<!--
Custom Rule: Detect Suspicious Outbound Connections
Technique: T1071.001 (Web Protocols)
Detection: Connections to unusual ports or IPs
-->
<group name="custom_linux_network,">

  <rule id="100009" level="8">
    <if_sid>2902</if_sid> <!-- Audit syscall -->
    <field name="syscall">connect</field>
    <field name="a2" type="pcre2">^(4444|31337|8888|9999)</field>
    <description>Suspicious outbound connection to non-standard port - Possible C2 (T1071.001)</description>
    <mitre>
      <id>T1071.001</id>
    </mitre>
    <group>attack,command_and_control,linux,</group>
  </rule>

</group>
```

### Step 4.10: Advanced Correlation Rules

#### Custom Rule #10 - Multiple Failed Logins Followed by Success

```xml
<!--
Custom Rule: Brute Force Detection - Multiple Failed Then Success
Technique: T1110 (Brute Force)
Detection: 5 failed logins within 5 minutes, then successful login
-->
<group name="custom_correlation,">

  <!-- First, detect failed login pattern -->
  <rule id="100010" level="0">
    <if_sid>60122</if_sid> <!-- Windows failed login -->
    <description>Windows failed login attempt</description>
    <group>authentication_failed,</group>
  </rule>

  <!-- Correlation rule: 5 failures -->
  <rule id="100011" level="10" frequency="5" timeframe="300">
    <if_matched_sid>100010</if_matched_sid>
    <same_source_ip />
    <description>Multiple failed login attempts from same source (5 in 5 min) - Possible brute force</description>
  </rule>

  <!-- High severity if followed by success -->
  <rule id="100012" level="14">
    <if_matched_sid>100011</if_matched_sid>
    <if_sid>60103</if_sid> <!-- Successful login -->
    <same_source_ip />
    <description>ALERT: Successful login after multiple failures - Brute force succeeded (T1110)</description>
    <mitre>
      <id>T1110</id>
    </mitre>
    <options>alert_by_email</options>
  </rule>

</group>
```

### Step 4.11: File Download Detection Rules

#### Custom Rule #11 - PowerShell Download File

```xml
<!--
Custom Rule: Detect File Downloads via PowerShell
Technique: T1105 (Ingress Tool Transfer)
Detection: PowerShell commands that download files
-->
<group name="custom_download,">

  <rule id="100013" level="12">
    <if_sid>91816</if_sid>
    <field name="win.eventdata.commandLine" type="pcre2">(?i)(Invoke-WebRequest|iwr|wget|curl|DownloadFile|DownloadString|Net\.WebClient|Start-BitsTransfer)</field>
    <description>File download via PowerShell detected - Ingress tool transfer (T1105)</description>
    <mitre>
      <id>T1105</id>
    </mitre>
    <group>attack,command_and_control,</group>
  </rule>

</group>
```

#### Custom Rule #12 - Certutil Abuse

```xml
<!--
Custom Rule: Detect Certutil Abuse for Downloads
Technique: T1105 (Ingress Tool Transfer)
Detection: Certutil used to download files
-->
<group name="custom_lolbas,">

  <rule id="100014" level="13">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.image" type="pcre2">(?i)\\\\certutil\\.exe</field>
    <field name="win.eventdata.commandLine" type="pcre2">(?i)-urlcache|-verifyctl|-f\s+http</field>
    <description>Certutil used for file download - Living-off-the-land technique (T1105)</description>
    <mitre>
      <id>T1105</id>
    </mitre>
    <group>attack,defense_evasion,lolbas,</group>
  </rule>

</group>
```

### Step 4.12: Complete Custom Rules File

Combine all rules into `/var/ossec/etc/rules/local_rules.xml`:

```xml
<!--
Custom Wazuh Rules - Blue Team Home Lab Project
Author: [Your Name]
Created: February 2025
Purpose: Enhanced detection based on Atomic Red Team simulations
-->

<group name="local,syslog,">

  <!-- PowerShell Base64 Obfuscation -->
  <rule id="100001" level="12">
    <if_sid>91816</if_sid>
    <field name="win.eventdata.commandLine" type="pcre2">(?i)(FromBase64String|ToBase64String|-enc|-EncodedCommand)</field>
    <description>PowerShell Base64 encoding/decoding detected - Possible obfuscation (T1027)</description>
    <mitre>
      <id>T1027</id>
    </mitre>
    <group>attack,execution,</group>
  </rule>

  <!-- Suspicious Process Injection -->
  <rule id="100002" level="14">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.parentImage" type="pcre2">(?i)(\\\\svchost\\.exe|\\\\services\\.exe)</field>
    <field name="win.eventdata.image" type="pcre2">(?i)(\\\\powershell\\.exe|\\\\cmd\\.exe|\\\\wscript\\.exe|\\\\cscript\\.exe)</field>
    <description>Suspicious parent-child process detected - Process injection (T1055)</description>
    <mitre>
      <id>T1055</id>
    </mitre>
    <group>attack,privilege_escalation,</group>
  </rule>

  <!-- Credential Access via Registry -->
  <rule id="100003" level="10">
    <if_sid>61612</if_sid>
    <field name="win.eventdata.commandLine" type="pcre2">(?i)reg\s+query.*password|reg\s+query.*passwd</field>
    <description>Registry query for passwords - Credential harvesting (T1552.002)</description>
    <mitre>
      <id>T1552.002</id>
    </mitre>
    <group>attack,credential_access,</group>
  </rule>

  <!-- Suspicious Scheduled Task -->
  <rule id="100004" level="12">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.image" type="pcre2">(?i)\\\\schtasks\\.exe</field>
    <field name="win.eventdata.commandLine" type="pcre2">(?i)/create.*(/sc\s+(minute|hourly)|/ru\s+system)</field>
    <description>Suspicious scheduled task creation (T1053.005)</description>
    <mitre>
      <id>T1053.005</id>
    </mitre>
    <group>attack,persistence,</group>
  </rule>

  <!-- Office App Spawning Process -->
  <rule id="100005" level="10">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.parentImage" type="pcre2">(?i)(\\\\WINWORD\\.EXE|\\\\EXCEL\\.EXE|\\\\POWERPNT\\.EXE)</field>
    <field name="win.eventdata.image" type="pcre2">(?i)(\\\\powershell\\.exe|\\\\cmd\\.exe)</field>
    <description>Office app spawned suspicious process - Macro execution (T1071.001)</description>
    <mitre>
      <id>T1071.001</id>
    </mitre>
    <group>attack,execution,</group>
  </rule>

  <!-- LSASS Memory Access -->
  <rule id="100006" level="15">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.targetImage" type="pcre2">(?i)\\\\lsass\\.exe</field>
    <field name="win.eventdata.grantedAccess">0x1FFFFF</field>
    <description>CRITICAL: LSASS memory access - Credential dumping (T1003.001)</description>
    <mitre>
      <id>T1003.001</id>
    </mitre>
    <group>attack,credential_access,</group>
    <options>alert_by_email</options>
  </rule>

  <!-- Suspicious Sudo Usage (Linux) -->
  <rule id="100007" level="12">
    <if_group>syslog</if_group>
    <match>sudo</match>
    <field name="command" type="pcre2">(?i)(nc|ncat|socat|bash -i|sh -i)</field>
    <description>Suspicious sudo command - Reverse shell attempt (T1548.003)</description>
    <mitre>
      <id>T1548.003</id>
    </mitre>
    <group>attack,privilege_escalation,linux,</group>
  </rule>

  <!-- SSH Key Modification (Linux) -->
  <rule id="100008" level="10">
    <if_sid>550</if_sid>
    <field name="file">authorized_keys</field>
    <description>SSH authorized_keys modified - Persistence (T1098.004)</description>
    <mitre>
      <id>T1098.004</id>
    </mitre>
    <group>attack,persistence,linux,</group>
  </rule>

  <!-- Suspicious Network Connection (Linux) -->
  <rule id="100009" level="8">
    <if_sid>2902</if_sid>
    <field name="syscall">connect</field>
    <field name="a2" type="pcre2">^(4444|31337|8888|9999)</field>
    <description>Connection to suspicious port - Possible C2 (T1071.001)</description>
    <mitre>
      <id>T1071.001</id>
    </mitre>
    <group>attack,command_and_control,linux,</group>
  </rule>

  <!-- Brute Force Detection - Failed Attempts -->
  <rule id="100010" level="0">
    <if_sid>60122</if_sid>
    <description>Failed login attempt</description>
    <group>authentication_failed,</group>
  </rule>

  <!-- Brute Force - Multiple Failures -->
  <rule id="100011" level="10" frequency="5" timeframe="300">
    <if_matched_sid>100010</if_matched_sid>
    <same_source_ip />
    <description>Multiple failed logins (5 in 5min) - Brute force attempt</description>
  </rule>

  <!-- Brute Force - Success After Failures -->
  <rule id="100012" level="14">
    <if_matched_sid>100011</if_matched_sid>
    <if_sid>60103</if_sid>
    <same_source_ip />
    <description>ALERT: Successful login after brute force - Attack succeeded (T1110)</description>
    <mitre>
      <id>T1110</id>
    </mitre>
    <options>alert_by_email</options>
  </rule>

  <!-- PowerShell Download -->
  <rule id="100013" level="12">
    <if_sid>91816</if_sid>
    <field name="win.eventdata.commandLine" type="pcre2">(?i)(Invoke-WebRequest|iwr|DownloadFile|DownloadString|Net\.WebClient)</field>
    <description>PowerShell file download - Tool transfer (T1105)</description>
    <mitre>
      <id>T1105</id>
    </mitre>
    <group>attack,command_and_control,</group>
  </rule>

  <!-- Certutil Abuse -->
  <rule id="100014" level="13">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.image" type="pcre2">(?i)\\\\certutil\\.exe</field>
    <field name="win.eventdata.commandLine" type="pcre2">(?i)-urlcache|-verifyctl|-f\s+http</field>
    <description>Certutil file download - LOLBin abuse (T1105)</description>
    <mitre>
      <id>T1105</id>
    </mitre>
    <group>attack,defense_evasion,lolbas,</group>
  </rule>

</group>
```

### Step 4.13: Load and Test Custom Rules

```bash
# Verify XML syntax
sudo /var/ossec/bin/wazuh-logtest

# This opens interactive testing console
# Paste sample log entries to test rule matching

# Example test log for PowerShell Base64:
# Type this at the prompt:
Feb 11 15:30:45 win-client01 WinEvtLog: Security: INFORMATION(4688): ...: powershell.exe -enc AAABBBCCC...

# Check if rule 100001 matches

# Exit logtest with CTRL+C

# Reload Wazuh manager to load new rules
sudo systemctl restart wazuh-manager

# Verify manager restarted successfully
sudo systemctl status wazuh-manager

# Check logs for rule loading errors
sudo tail -f /var/ossec/logs/ossec.log | grep -i "error\|warn"
```

### Step 4.14: Validate Custom Rules with Real Tests

Re-run some Atomic Red Team tests to verify custom rules trigger:

```powershell
# On laptop (PowerShell)

# Test Rule 100001 - Base64 obfuscation
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("test"))
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))

# Wait 30 seconds, then check Wazuh Dashboard for Rule ID 100001

# Test Rule 100004 - Scheduled task
schtasks /create /tn "TestTask" /tr "notepad.exe" /sc minute /mo 1

# Check for Rule ID 100004

# Cleanup
schtasks /delete /tn "TestTask" /f
```

**In Wazuh Dashboard:**

1. Go to Security Events
2. Filter: `rule.id:(100001 OR 100004)`
3. Verify alerts appear
4. Check alert details contain:
   - Correct MITRE ATT&CK mapping
   - Accurate description
   - Appropriate severity level

### Step 4.15: Fine-Tune Rules (Reduce False Positives)

If rules generate too many false positives:

```xml
<!-- Example: Exclude legitimate PowerShell scripts -->
<rule id="100001" level="12">
  <if_sid>91816</if_sid>
  <field name="win.eventdata.commandLine" type="pcre2">(?i)(FromBase64String|ToBase64String|-enc|-EncodedCommand)</field>
  <!-- Exclude known good processes -->
  <field name="win.eventdata.user" negate="yes">NT AUTHORITY\SYSTEM</field>
  <field name="win.eventdata.parentImage" negate="yes" type="pcre2">(?i)\\\\VSCode\\.exe|\\\\powershell_ise\\.exe</field>
  <description>PowerShell Base64 encoding/decoding detected - Possible obfuscation (T1027)</description>
  <mitre>
    <id>T1027</id>
  </mitre>
</rule>
```

### Step 4.16: Document Custom Rules

Create documentation for each custom rule:

```bash
vim ~/custom-rules-documentation.md
```

Template:

```markdown
# Custom Wazuh Rules Documentation

## Rule 100001: PowerShell Base64 Obfuscation Detection

### Purpose
Detects use of Base64 encoding/decoding in PowerShell, commonly used to obfuscate malicious payloads.

### MITRE ATT&CK Mapping
- **Technique**: T1027 - Obfuscated Files or Information
- **Tactic**: Defense Evasion

### Detection Logic
- Triggers on PowerShell execution events (parent rule 91816)
- Searches for Base64-related cmdlets and parameters in command line
- Regex pattern: `(FromBase64String|ToBase64String|-enc|-EncodedCommand)`

### Alert Level: 12 (High)

### False Positive Scenarios
- Legitimate scripts that use Base64 for encoding
- Administrative tools that encode configuration
- Development/testing activities

### Mitigation Recommendations
1. Investigate the full command line
2. Check parent process and user context
3. Verify if file hash is known good
4. Review PowerShell script block logging

### Testing Procedure
```powershell
# Trigger alert:
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("test"))
```

### Tuning Notes
- Exclude trusted admin accounts if needed
- Consider whitelisting known good script paths
- Monitor for legitimate use cases over 1 week before production deployment

---

## Rule 100002: Suspicious Process Injection
[Continue for all 14 rules...]
```

### Step 4.17: Create Rule Performance Dashboard

In Wazuh Dashboard, create custom visualization:

1. Go to "Discover"
2. Create search: `rule.id:(100001 OR 100002 OR 100003 ... OR 100014)`
3. Save search as "Custom Rules Activity"
4. Create visualizations:
   - **Pie chart**: Distribution by rule ID
   - **Line chart**: Custom rule alerts over time
   - **Data table**: Top triggered custom rules

### Step 4.18: Export Custom Rules for Portfolio

```bash
# Create rules package
mkdir -p ~/wazuh-custom-rules-package

# Copy custom rules
sudo cp /var/ossec/etc/rules/local_rules.xml ~/wazuh-custom-rules-package/

# Copy documentation
cp ~/custom-rules-documentation.md ~/wazuh-custom-rules-package/README.md

# Create rule testing script
cat > ~/wazuh-custom-rules-package/test-custom-rules.ps1 << 'EOF'
# Custom Rule Testing Script
# Tests all custom Wazuh rules

Write-Host "Testing Custom Wazuh Rules" -ForegroundColor Green

# Test 100001 - Base64
Write-Host "`nTest 1: Base64 Obfuscation (Rule 100001)"
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("malicious"))

# Test 100004 - Scheduled Task
Write-Host "`nTest 2: Scheduled Task (Rule 100004)"
schtasks /create /tn "TestTask" /tr "cmd.exe" /sc minute /mo 1 /f
Start-Sleep -Seconds 2
schtasks /delete /tn "TestTask" /f

# Test 100013 - Download
Write-Host "`nTest 3: PowerShell Download (Rule 100013)"
Invoke-WebRequest -Uri "http://example.com" -UseBasicParsing | Out-Null

Write-Host "`nAll tests complete. Check Wazuh Dashboard for alerts." -ForegroundColor Green
EOF

# Create archive
tar -czf ~/wazuh-custom-rules-package.tar.gz ~/wazuh-custom-rules-package/

echo "Custom rules package created: ~/wazuh-custom-rules-package.tar.gz"
```

---

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue: Agent shows "Disconnected" in dashboard

**Diagnosis:**
```bash
# On agent machine
sudo systemctl status wazuh-agent
sudo tail -f /var/ossec/logs/ossec.log
```

**Solutions:**
```bash
# 1. Check firewall
sudo ufw status
sudo ufw allow from 192.168.1.10 to any port 1514

# 2. Verify server address in config
sudo cat /var/ossec/etc/ossec.conf | grep -A 5 "<client>"

# 3. Restart agent
sudo systemctl restart wazuh-agent

# 4. Check connectivity
ping 192.168.1.10
telnet 192.168.1.10 1514
```

#### Issue: No events appearing in dashboard

**Diagnosis:**
```bash
# Check if agents are sending data
sudo tail -f /var/ossec/logs/archives/archives.log

# Check indexer status
sudo systemctl status wazuh-indexer

# Check dashboard status
sudo systemctl status wazuh-dashboard
```

**Solutions:**
```bash
# Restart services in order
sudo systemctl restart wazuh-indexer
sudo systemctl restart wazuh-manager
sudo systemctl restart wazuh-dashboard

# Clear browser cache and reload dashboard
```

#### Issue: Custom rule not triggering

**Diagnosis:**
```bash
# Use logtest to test rule
sudo /var/ossec/bin/wazuh-logtest

# Paste sample log and check if rule matches
```

**Solutions:**
```xml
<!-- Check rule syntax -->
<!-- Verify parent rule exists -->
<!-- Test regex patterns -->
<!-- Check field names match actual log fields -->
```

#### Issue: High false positive rate

**Solutions:**
```xml
<!-- Add exclusions -->
<field name="user" negate="yes">KNOWN_GOOD_USER</field>

<!-- Increase threshold -->
<rule id="100XXX" level="10" frequency="10" timeframe="300">

<!-- Add more specific conditions -->
<field name="process_name">specific_process.exe</field>
```

#### Issue: Performance degradation

**Diagnosis:**
```bash
# Check resource usage
top
htop
df -h
free -h

# Check Wazuh queue
/var/ossec/bin/wazuh-control status
```

**Solutions:**
```bash
# Reduce FIM frequency
# Disable unnecessary log sources
# Increase VM resources
# Optimize custom rules (reduce regex complexity)
```

---

## Phase Completion Checklist

### Phase 0 Checklist
- [ ] Hypervisor installed on 16GB desktop
- [ ] Wazuh Server VM created (8GB RAM, 2 CPU, 40GB disk)
- [ ] Pop!_OS installed on server VM
- [ ] Static IP configured for server (192.168.1.10)
- [ ] 4GB PC prepared with Pop!_OS
- [ ] Static IP configured for 4GB PC (192.168.1.20)
- [ ] Laptop prepared with Pop!_OS
- [ ] Static IP configured for laptop (192.168.1.30)
- [ ] Windows VM created on laptop
- [ ] Static IP configured for Windows VM (192.168.1.31)
- [ ] Network connectivity verified between all devices
- [ ] Architecture documented
- [ ] VM snapshot created

### Phase 1 Checklist
- [ ] Wazuh server installed (version 4.12+)
- [ ] Wazuh dashboard accessible
- [ ] Admin credentials saved securely
- [ ] Firewall configured on server
- [ ] Agent installed on server VM
- [ ] Agent installed on 4GB PC
- [ ] Agent installed on laptop
- [ ] Agent installed on Windows VM
- [ ] All 4 agents showing "Active" status
- [ ] Test events generated and visible
- [ ] Phase 1 snapshot created

### Phase 2 Checklist
- [ ] Windows Event Logs configured
- [ ] Sysmon installed on Windows
- [ ] Linux syslog collection verified
- [ ] Auditd installed and configured on Linux
- [ ] Audit rules deployed
- [ ] File Integrity Monitoring configured (Windows)
- [ ] File Integrity Monitoring configured (Linux)
- [ ] Test events generated from all sources
- [ ] Events visible in dashboard
- [ ] Custom visualization created
- [ ] Configuration exported and documented

### Phase 3 Checklist
- [ ] Pre-attack snapshot created
- [ ] PowerShell installed on Linux
- [ ] Atomic Red Team installed
- [ ] Attack log template created
- [ ] 10+ techniques tested
- [ ] Each test documented
- [ ] Wazuh alerts reviewed for each test
- [ ] Detection gaps identified
- [ ] Attack simulation report created
- [ ] Cleanup completed

### Phase 4 Checklist
- [ ] local_rules.xml backup created
- [ ] 12+ custom rules developed
- [ ] Each rule tested and validated
- [ ] False positives addressed
- [ ] MITRE ATT&CK mappings added
- [ ] Rules documented
- [ ] Performance dashboard created
- [ ] Custom rules package exported
- [ ] Testing script created
- [ ] All rules verified working

---

## Next Steps: Phases 5-7

This guide covered Phases 0-4. Continue with:

**Phase 5 (Week 9)**: Investigation Playbook Development
- Create 5 detailed investigation playbooks
- Map to MITRE ATT&CK techniques
- Document evidence collection procedures

**Phase 6 (Week 10)**: Final Integration
- Integrate Raspberry Pi
- Clean up lab environment
- Create final "gold master" snapshot

**Phase 7 (Week 11)**: Portfolio Documentation
- Create professional GitHub repository
- Write comprehensive README
- Add screenshots and diagrams
- Publish investigation playbooks
- Share custom rules

---

## Additional Resources

### Official Documentation
- Wazuh Documentation: https://documentation.wazuh.com
- Atomic Red Team Wiki: https://github.comredcanarycoinvoke-atomicredteam/wiki
- MITRE ATT&CK: https://attack.mitre.org

### Community Resources
- Wazuh Slack: https://wazuh.com/community/join-us-on-slack
- Reddit r/blueteamsec
- Sans DFIR Community

### Recommended Reading
- "The Practice of Network Security Monitoring" by Richard Bejtlich
- "Blue Team Handbook" series by Don Murdoch
- "Crafting the InfoSec Playbook" by Jeff Bollinger

---

**Document Version**: 1.0  
**Last Updated**: February 11, 2025  
**Author**: Blue Team Home Lab Project  
**License**: MIT (for educational purposes)

---

## Conclusion

You now have a comprehensive guide covering the first four critical phases of building a professional-grade Blue Team home lab. Each phase builds upon the previous one, creating a progression from basic infrastructure to advanced threat detection engineering.

**Key Achievements So Far:**
- ✅ Deployed production-like SIEM infrastructure
- ✅ Configured comprehensive log collection
- ✅ Simulated real-world attacks
- ✅ Developed custom detection rules

**Skills Demonstrated:**
- Systems administration (Linux & Windows)
- Network configuration
- SIEM deployment and management
- Threat simulation and red teaming
- Detection engineering
- Incident analysis
- Technical documentation

This project is portfolio-ready and demonstrates hands-on experience that employers value highly in SOC analyst roles.

**Remember**: The learning never stops. Continue to:
- Test new attack techniques
- Refine your detection rules
- Stay current with emerging threats
- Engage with the cybersecurity community
- Document everything you learn

Good luck with your cybersecurity career!
