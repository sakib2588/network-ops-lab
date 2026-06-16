# 🛡️ Wazuh SOC Home Lab - Complete Implementation Guide
## Customized for Your Hardware & Timeline (10.5 Weeks, 15 hrs/week)

---

## 📋 Your Hardware Reality & Strategy

### Final Hardware Assignments
| Device | Role | Specs | Status | Notes |
|--------|------|-------|--------|-------|
| **Laptop** | 🎯 **Wazuh Server** | 12GB RAM, Ubuntu | Available NOW | Main server, slightly below 16GB ideal but workable |
| **PC 1** | **Linux Agent** | 16GB RAM, Ubuntu (dual boot) | Available in 2 days | Will run DL training (11-12GB used), but 4-5GB free for lightweight agent |
| **PC 2** | **Windows Agent** | 4GB RAM, Windows | Available NOW | Perfect for Windows monitoring |
| **PC 1 (Windows side)** | **Optional Windows Agent** | 16GB RAM, Windows | Boot when needed | Alternative Windows test environment |
| **Raspberry Pi** | **Network Sensor** | Model 4B, 4GB+ | Arriving Week 3-4 | Suricata/OSSEC for network detection |

### Why This Works
✅ Laptop has enough RAM for Wazuh (12GB is 75% of recommended 16GB)  
✅ PC 1's Ubuntu can run agent even during DL training (agents use ~150MB RAM)  
✅ PC 2 provides immediate Windows monitoring capability  
✅ Dual-boot PC 1 gives flexibility for Windows testing when needed  
✅ All devices on same network = easy communication  

---

## 🗓️ Master Timeline (10.5 Weeks)

| Phase | Week | Hours | Focus | Key Deliverable |
|-------|------|-------|-------|-----------------|
| **Phase 0** | Week 1 | 12h | Environment Setup | Ubuntu on laptop, network configured |
| **Phase 1** | Week 2-3 | 20h | Wazuh Deployment | Wazuh server running on laptop |
| **Phase 2** | Week 3-4 | 15h | Log Ingestion | All agents feeding logs to Wazuh |
| **Phase 3** | Week 5-6 | 25h | Threat Simulation | 10+ attack techniques tested |
| **Phase 4** | Week 7-8 | 30h | Detection Engineering | 12+ custom detection rules |
| **Phase 5** | Week 9 | 20h | Investigation Playbooks | 5 detailed incident reports |
| **Phase 6** | Week 10 | 18h | Documentation & Portfolio | GitHub repo ready for employers |
| **Phase 7** | Week 11 | 10h | Raspberry Pi Integration | Network sensor operational |
| **TOTAL** | | **150h** | | **Complete SOC Lab Portfolio** |

---

# 🚀 PHASE 0: Environment Setup (Week 1 - 12 hours)

## Goals
- [ ] Install Ubuntu 24.04 LTS on laptop (replacing Arch)
- [ ] Configure network for lab environment
- [ ] Set up essential tools and test connectivity
- [ ] Create initial GitHub repository

## Day 1-2: Ubuntu Installation (4 hours)

### Step 1: Backup Your Arch Data
```bash
# On current Arch laptop - backup important files
rsync -av ~/Documents /media/external_drive/arch_backup/
rsync -av ~/.ssh /media/external_drive/arch_backup/
rsync -av ~/.config /media/external_drive/arch_backup/
```

### Step 2: Download Ubuntu 24.04 LTS
1. Go to: https://ubuntu.com/download/desktop
2. Download Ubuntu 24.04 LTS ISO (~5GB)
3. Create bootable USB:
   - **On Windows (PC 2)**: Use Rufus (https://rufus.ie/)
   - **On Arch (current laptop)**: 
     ```bash
     sudo dd if=ubuntu-24.04-desktop-amd64.iso of=/dev/sdX bs=4M status=progress && sync
     # Replace /dev/sdX with your USB device (find it with 'lsblk')
     ```

### Step 3: Install Ubuntu on Laptop
1. Boot from USB (usually F12 or F2 during startup)
2. Select "Install Ubuntu"
3. **Critical Settings**:
   - ✅ Erase disk and install Ubuntu (since you're replacing Arch)
   - ✅ Create user: `soclab` (or your preferred username)
   - ✅ Enable "Download updates while installing"
   - ✅ Install third-party software (for WiFi drivers)
4. Complete installation and reboot

### Step 4: Post-Installation Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y \
    vim nano \
    net-tools \
    openssh-server \
    curl wget \
    git \
    htop \
    tree

# Enable SSH for remote access
sudo systemctl enable ssh
sudo systemctl start ssh

# Find your laptop's IP address (WRITE THIS DOWN!)
ip addr show | grep "inet 192.168"
# Example output: inet 192.168.1.50/24
# Your laptop IP: 192.168.1.50 (yours will differ)
```

**🔍 CHECKPOINT**: Can you SSH into your laptop from PC 2?
```bash
# From PC 2 (open PowerShell):
ssh soclab@192.168.1.50
# Enter your password - you should get Ubuntu prompt
```

**❌ If stuck**: 
- Check firewall: `sudo ufw status` (should be inactive or allow ssh)
- Verify SSH running: `sudo systemctl status ssh`
- Ping laptop from PC 2: `ping 192.168.1.50`

---

## Day 3-4: Network Configuration (3 hours)

### Step 1: Document Your Network
Create a network diagram (we'll use this for your GitHub repo):

```bash
# On laptop, discover all devices on your network
sudo apt install nmap -y
nmap -sn 192.168.1.0/24

# Your network should look like:
# 192.168.1.1      - Router
# 192.168.1.50     - Laptop (Wazuh Server) ← YOU ARE HERE
# 192.168.1.X      - PC 1 (will be Ubuntu soon)
# 192.168.1.Y      - PC 2 (Windows)
```

**Create Network Map** (save as `network_map.txt`):
```
SOC Lab Network Map
===================
Router:    192.168.1.1
Laptop:    192.168.1.50  (Wazuh Server - Ubuntu 24.04)
PC 1:      192.168.1.X   (Linux Agent - Ubuntu 24.04) [DL Training Active]
PC 2:      192.168.1.Y   (Windows Agent - Windows 10/11)
Pi:        192.168.1.Z   (Network Sensor - Raspberry Pi OS) [Coming Week 3]
```

### Step 2: Configure Static IP for Laptop (Recommended)
```bash
# Find your network interface name
ip link show
# Look for something like 'enp3s0' (wired) or 'wlp2s0' (wireless)

# Edit netplan configuration
sudo nano /etc/netplan/01-network-manager-all.yaml

# Add this configuration (adjust for your interface):
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    enp3s0:  # Replace with YOUR interface name
      dhcp4: no
      addresses:
        - 192.168.1.50/24  # Your chosen static IP
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]

# Apply changes
sudo netplan apply

# Verify
ip addr show enp3s0
```

**🔍 CHECKPOINT**: Reboot laptop and verify static IP persists
```bash
sudo reboot
# After reboot:
ip addr show | grep "inet 192.168"
# Should still show 192.168.1.50
```

---

## Day 5: Essential Tools & GitHub Setup (3 hours)

### Step 1: Install Docker (for optional testing containers)
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group
sudo usermod -aG docker $USER

# Log out and back in, then test
docker --version
docker run hello-world
```

### Step 2: Create GitHub Repository
1. Go to https://github.com (create account if needed)
2. Click "New Repository"
   - Name: `wazuh-soc-homelab`
   - Description: "Home lab SOC environment using Wazuh SIEM for detection engineering and threat hunting"
   - ✅ Public (for portfolio)
   - ✅ Add README
3. Clone to laptop:
```bash
cd ~
git clone https://github.com/YOUR_USERNAME/wazuh-soc-homelab.git
cd wazuh-soc-homelab

# Create initial structure
mkdir -p {docs,rules,playbooks,screenshots,scripts}
tree  # Verify structure
```

### Step 3: Create Initial README
```bash
nano README.md
```

**Add this content**:
```markdown
# Wazuh SOC Home Lab

## Project Status: 🏗️ In Progress

### Overview
A production-like Security Operations Center (SOC) home lab built with Wazuh SIEM to develop detection engineering and threat hunting skills.

### Architecture
- **Wazuh Server**: Ubuntu 24.04 LTS (12GB RAM)
- **Windows Agent**: Windows 10/11 (4GB RAM)
- **Linux Agent**: Ubuntu 24.04 LTS (16GB RAM)
- **Network Sensor**: Raspberry Pi 4B (Suricata NIDS)

### Progress
- [x] Phase 0: Environment Setup
- [ ] Phase 1: Wazuh Deployment
- [ ] Phase 2: Log Ingestion
- [ ] Phase 3: Threat Simulation
- [ ] Phase 4: Detection Engineering
- [ ] Phase 5: Investigation Playbooks
- [ ] Phase 6: Documentation
- [ ] Phase 7: Network Sensor

### Technologies
- Wazuh 4.x (SIEM/XDR)
- Elastic Stack (OpenSearch)
- Atomic Red Team (Threat Emulation)
- MITRE ATT&CK Framework
- Kibana Query Language (KQL)

---
*Portfolio project demonstrating SOC analyst capabilities*
```

```bash
# Commit and push
git add README.md
git commit -m "Initial commit: Project structure"
git push origin main
```

**🔍 CHECKPOINT**: Visit your GitHub repo - you should see the README

---

## Day 6-7: PC 1 Ubuntu Setup (2 hours)

### Step 1: Install Ubuntu on PC 1 (Dual Boot)
**⚠️ CRITICAL**: Back up your Windows DL project first!

1. Create Ubuntu USB (same process as laptop)
2. Boot PC 1 from USB
3. **Important**: Select "Install Ubuntu alongside Windows"
4. Allocate at least 150GB to Ubuntu partition
5. Complete installation

### Step 2: Verify Dual Boot Works
```bash
# After installation, you should see GRUB menu:
# 1. Ubuntu
# 2. Windows Boot Manager

# Boot into Ubuntu and update:
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y vim net-tools openssh-server curl wget git

# Enable SSH
sudo systemctl enable ssh
sudo systemctl start ssh

# Find IP address
ip addr show | grep "inet 192.168"
# Write this down as PC 1 IP
```

### Step 3: Test Network Connectivity
```bash
# From laptop, SSH into PC 1:
ssh your_username@192.168.1.X  # PC 1's IP

# From PC 1, ping laptop:
ping 192.168.1.50  # Laptop IP
```

---

## 📊 Phase 0 Completion Checklist

Before moving to Phase 1, verify:

- [ ] Laptop running Ubuntu 24.04 with static IP (192.168.1.50)
- [ ] Laptop has SSH enabled and accessible from other devices
- [ ] PC 1 dual-booted with Ubuntu, SSH enabled
- [ ] PC 2 (Windows) can ping laptop and PC 1
- [ ] All devices on same network (192.168.1.x)
- [ ] GitHub repository created with initial README
- [ ] Network map documented (you know all IPs)
- [ ] Docker installed on laptop
- [ ] Can SSH between all devices

### Network Test (from laptop):
```bash
# Test connectivity to all devices
ping -c 4 192.168.1.1    # Router
ping -c 4 192.168.1.X    # PC 1
ping -c 4 192.168.1.Y    # PC 2

# Test SSH
ssh user@192.168.1.X     # PC 1 Ubuntu
```

**🎉 Phase 0 Complete!** You now have a solid foundation.

---

# 🔧 PHASE 1: Wazuh Deployment (Week 2-3 - 20 hours)

## Goals
- [ ] Install Wazuh server on laptop
- [ ] Access Wazuh web dashboard
- [ ] Configure firewall rules
- [ ] Understand Wazuh architecture

## Week 2, Day 1-2: Wazuh Server Installation (6 hours)

### Step 1: System Requirements Check
```bash
# On laptop, verify resources
free -h  # Should show ~12GB total RAM
df -h    # Should have 50GB+ free space in /
nproc    # Should show 2+ CPU cores

# Update system
sudo apt update && sudo apt upgrade -y
```

### Step 2: Download Wazuh Installation Script
```bash
cd ~
curl -sO https://packages.wazuh.com/4.9/wazuh-install.sh
curl -sO https://packages.wazuh.com/4.9/config.yml

# Verify download
ls -lh wazuh-install.sh config.yml
```

### Step 3: Install Wazuh (All-in-One)
```bash
# Make script executable
chmod +x wazuh-install.sh

# Run installation (this takes 15-30 minutes)
sudo bash wazuh-install.sh -a

# The script will output credentials - SAVE THESE!
# Example output:
# INFO: --- Summary ---
# INFO: You can access the web interface https://192.168.1.50:443
#   User: admin
#   Password: <REDACTED — generated at install; save to your password manager>

# COPY THE PASSWORD IMMEDIATELY!
```

**📝 Save these in a secure note**:
```
Wazuh Dashboard Access:
URL: https://192.168.1.50:443
Username: admin
Password: [YOUR_GENERATED_PASSWORD]
```

**❌ If installation fails**:
```bash
# Common issues:

# 1. Port already in use
sudo netstat -tlnp | grep :443
sudo netstat -tlnp | grep :9200
# Kill any conflicting processes

# 2. Not enough RAM/disk
free -h
df -h
# Close unnecessary applications

# 3. Clean slate restart
sudo bash wazuh-install.sh -u  # Uninstall
sudo bash wazuh-install.sh -a  # Reinstall
```

### Step 4: First Login to Dashboard
1. Open browser on **PC 2** (Windows)
2. Navigate to: `https://192.168.1.50:443`
3. **You'll see "Your connection is not private"** - this is normal (self-signed certificate)
   - Chrome: Click "Advanced" → "Proceed to 192.168.1.50"
   - Firefox: "Advanced" → "Accept Risk"
4. Login with admin credentials
5. **🎉 You should see Wazuh Dashboard!**

**🔍 CHECKPOINT**: Can you see the Wazuh welcome screen?

**❌ If you can't access**:
```bash
# On laptop, check Wazuh services
sudo systemctl status wazuh-manager
sudo systemctl status wazuh-indexer
sudo systemctl status wazuh-dashboard

# All should show "active (running)"

# Check firewall
sudo ufw status
# If active, allow ports:
sudo ufw allow 443/tcp
sudo ufw allow 1514/tcp
sudo ufw allow 1515/tcp

# Restart services
sudo systemctl restart wazuh-manager
sudo systemctl restart wazuh-dashboard
```

---

## Week 2, Day 3-4: Understanding Wazuh Architecture (4 hours)

### Activity 1: Explore the Dashboard (2 hours)
Click through these sections and take screenshots for your portfolio:

1. **Overview** → Shows system health
   - Screenshot this main page
2. **Modules** → See available detection capabilities
   - Security Events
   - Integrity Monitoring
   - Vulnerability Detection
3. **Management** → Where you'll add agents
4. **Discover** → Where you'll write KQL queries

### Activity 2: Learn Wazuh File Structure (2 hours)
```bash
# On laptop, explore Wazuh directories
sudo su  # Become root for easier navigation

cd /var/ossec
tree -L 2  # See directory structure

# Key directories:
ls -la /var/ossec/etc/      # Configuration files
ls -la /var/ossec/logs/     # Wazuh logs
ls -la /var/ossec/ruleset/  # Detection rules
ls -la /var/ossec/queue/    # Agent communication

# View main config
cat /var/ossec/etc/ossec.conf | less

# View default rules
ls /var/ossec/ruleset/rules/ | head -20
```

**📝 Document your findings**:
```bash
cd ~/wazuh-soc-homelab/docs
nano wazuh-architecture-notes.md
```

**Write**:
```markdown
# Wazuh Architecture Notes

## Installation Details
- Installation Date: [TODAY'S DATE]
- Version: 4.9.x
- Server IP: 192.168.1.50
- Installation Type: All-in-One

## Key Components
1. **Wazuh Manager** (`/var/ossec/bin/wazuh-control`)
   - Receives logs from agents
   - Applies detection rules
   - Generates alerts

2. **Wazuh Indexer** (Elasticsearch-based)
   - Stores all logs and alerts
   - Enables fast searching

3. **Wazuh Dashboard** (OpenSearch Dashboards)
   - Web UI at https://192.168.1.50:443
   - Visualizations and KQL queries

## Communication Ports
- 1514: Agent→Manager (syslog)
- 1515: Agent→Manager (events)
- 443: HTTPS dashboard access
- 9200: Indexer API

## Important Files
- `/var/ossec/etc/ossec.conf` - Main configuration
- `/var/ossec/etc/rules/local_rules.xml` - Custom rules (we'll create these)
- `/var/ossec/logs/ossec.log` - Wazuh logs
- `/var/ossec/logs/alerts/alerts.json` - All alerts

## Resource Usage
```bash
# Check during idle
free -h
htop
```
[Paste your actual memory usage here]
```

---

## Week 3, Day 1-2: Security Hardening (4 hours)

### Step 1: Change Default Passwords
```bash
# On laptop
cd /usr/share/wazuh-indexer/plugins/opensearch-security/tools/

# Change admin password
sudo ./hash.sh -p 'YourNewStrongPassword123!'
# Copy the hash output

# Update security config
sudo nano /etc/wazuh-indexer/opensearch-security/internal_users.yml

# Find the admin user and replace the hash:
admin:
  hash: "[PASTE YOUR NEW HASH HERE]"
  reserved: true
  backend_roles:
  - "admin"

# Apply changes
sudo /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
  -cd /etc/wazuh-indexer/opensearch-security/ \
  -nhnv \
  -cacert /etc/wazuh-indexer/certs/root-ca.pem \
  -cert /etc/wazuh-indexer/certs/admin.pem \
  -key /etc/wazuh-indexer/certs/admin-key.pem

# Restart
sudo systemctl restart wazuh-dashboard
```

### Step 2: Configure Firewall (UFW)
```bash
# Enable firewall
sudo ufw enable

# Allow SSH from your local network only
sudo ufw allow from 192.168.1.0/24 to any port 22

# Allow Wazuh dashboard from local network
sudo ufw allow from 192.168.1.0/24 to any port 443

# Allow Wazuh agent connections
sudo ufw allow 1514/tcp
sudo ufw allow 1515/tcp

# Check rules
sudo ufw status numbered

# Enable firewall
sudo ufw reload
```

### Step 3: Set Up Log Rotation
```bash
# Wazuh has built-in log rotation, but verify it
sudo cat /var/ossec/etc/ossec.conf | grep -A 5 "jsonout_output"

# Ensure logs don't fill your disk
sudo nano /var/ossec/etc/ossec.conf

# Find this section and adjust if needed:
<jsonout_output>yes</jsonout_output>
<logging>
  <log_alert_level>3</log_alert_level>
</logging>
```

---

## Week 3, Day 3: Testing & Documentation (3 hours)

### Step 1: Generate Test Alert
```bash
# On laptop, trigger a test alert
sudo /var/ossec/bin/wazuh-control restart

# Check logs for successful start
sudo tail -f /var/ossec/logs/ossec.log

# In Dashboard → Discover, you should see logs appearing
```

### Step 2: Take Portfolio Screenshots
Capture these from the Wazuh dashboard (PC 2 browser):
1. Main Overview showing "Wazuh is running"
2. Modules page
3. Management → Agents (showing "No agents connected" - we'll fix this next)

Save to: `~/wazuh-soc-homelab/screenshots/phase1/`

### Step 3: Update GitHub
```bash
cd ~/wazuh-soc-homelab

# Copy screenshots
mkdir -p screenshots/phase1
# (Copy your browser screenshots here)

# Update README
nano README.md
```

**Add under Progress**:
```markdown
### Progress
- [x] Phase 0: Environment Setup
- [x] Phase 1: Wazuh Deployment ✅
  - Wazuh 4.9 server installed on laptop
  - Dashboard accessible at https://192.168.1.50
  - Security hardening completed
  - Firewall configured
- [ ] Phase 2: Log Ingestion
...
```

```bash
# Commit
git add .
git commit -m "Phase 1 complete: Wazuh server deployed"
git push origin main
```

---

## 📊 Phase 1 Completion Checklist

- [ ] Wazuh server installed and running on laptop
- [ ] Can access dashboard at https://192.168.1.50:443
- [ ] Changed default admin password
- [ ] Firewall configured (UFW enabled with proper rules)
- [ ] Dashboard screenshots captured
- [ ] Architecture notes documented
- [ ] GitHub repo updated

### Verification Commands:
```bash
# All should show "active (running)"
sudo systemctl status wazuh-manager
sudo systemctl status wazuh-indexer  
sudo systemctl status wazuh-dashboard

# Check disk space (should have 30GB+ free)
df -h /var/ossec

# Check memory usage (should be under 10GB)
free -h
```

**🎉 Phase 1 Complete!** Your SIEM is operational.

---

# 📡 PHASE 2: Log Ingestion (Week 3-4 - 15 hours)

## Goals
- [ ] Install Wazuh agent on PC 2 (Windows)
- [ ] Install Wazuh agent on PC 1 (Ubuntu - during DL training)
- [ ] Configure log sources on both agents
- [ ] Verify logs flowing to server
- [ ] Learn basic KQL queries

## Week 3, Day 4-5: Windows Agent (PC 2) - 4 hours

### Step 1: Deploy Windows Agent

**On PC 2 (Windows), open PowerShell as Administrator**:

```powershell
# Download Wazuh agent installer
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.9.0-1.msi -OutFile wazuh-agent.msi

# Install agent (replace 192.168.1.50 with your laptop IP)
msiexec.exe /i wazuh-agent.msi /q WAZUH_MANAGER="192.168.1.50" WAZUH_AGENT_NAME="PC2-Windows"

# Start the agent service
NET START WazuhSvc

# Verify it's running
Get-Service WazuhSvc
# Should show "Running"
```

**🔍 CHECKPOINT**: On Wazuh Dashboard (laptop browser):
1. Go to **Management** → **Agents**
2. You should see "PC2-Windows" with status "Active"

**❌ If agent not appearing**:
```powershell
# On PC 2, check agent log
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 50

# Check if manager IP is correct
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.conf" | Select-String -Pattern "address"

# Restart agent
NET STOP WazuhSvc
NET START WazuhSvc
```

### Step 2: Configure Windows Event Log Collection

**On PC 2 PowerShell (Administrator)**:
```powershell
# Navigate to Wazuh config
cd "C:\Program Files (x86)\ossec-agent"

# Backup original config
Copy-Item ossec.conf ossec.conf.backup

# Edit config (use Notepad++)
notepad.exe ossec.conf
```

**Find the `<localfile>` section and add**:
```xml
  <!-- Windows Security Events -->
  <localfile>
    <location>Microsoft-Windows-Sysmon/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>

  <localfile>
    <location>Security</location>
    <log_format>eventchannel</log_format>
  </localfile>

  <localfile>
    <location>System</location>
    <log_format>eventchannel</log_format>
  </localfile>

  <localfile>
    <location>Application</location>
    <log_format>eventchannel</log_format>
  </localfile>

  <!-- PowerShell Logging -->
  <localfile>
    <location>Microsoft-Windows-PowerShell/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
```

**Save and restart agent**:
```powershell
NET STOP WazuhSvc
NET START WazuhSvc
```

### Step 3: Install Sysmon (Critical for Visibility)
```powershell
# Download Sysmon
Invoke-WebRequest -Uri https://live.sysinternals.com/Sysmon64.exe -OutFile Sysmon64.exe

# Download SwiftOnSecurity's config
Invoke-WebRequest -Uri https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml -OutFile sysmonconfig.xml

# Install Sysmon
.\Sysmon64.exe -accepteula -i sysmonconfig.xml

# Verify it's running
Get-Service Sysmon64
```

**🔍 CHECKPOINT**: In Wazuh Dashboard → Discover
```
agent.name: "PC2-Windows" AND winlog.event_id: 1
```
You should see Sysmon process creation events (Event ID 1)

---

## Week 4, Day 1-2: Linux Agent (PC 1 Ubuntu) - 4 hours

**⚠️ Note**: Even though PC 1 is running DL training, the Wazuh agent uses minimal resources (~150MB RAM, <5% CPU)

### Step 1: Install Agent on PC 1

**SSH into PC 1 Ubuntu**:
```bash
ssh your_username@192.168.1.X  # PC 1 IP
```

**On PC 1**:
```bash
# Download and install agent
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg

echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee -a /etc/apt/sources.list.d/wazuh.list

sudo apt update

# Install agent
sudo apt install wazuh-agent -y

# Configure manager IP
sudo sed -i 's/MANAGER_IP/192.168.1.50/' /var/ossec/etc/ossec.conf

# Set agent name
sudo sed -i 's/<client_name>.*<\/client_name>/<client_name>PC1-Ubuntu-DL<\/client_name>/' /var/ossec/etc/ossec.conf

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent

# Verify
sudo systemctl status wazuh-agent
```

**🔍 CHECKPOINT**: In Wazuh Dashboard → Management → Agents
You should now see TWO agents:
- PC2-Windows (Active)
- PC1-Ubuntu-DL (Active)

### Step 2: Configure Linux Log Collection

**On PC 1**:
```bash
# Edit agent config
sudo nano /var/ossec/etc/ossec.conf

# Find <localfile> section and add:
```

```xml
  <!-- System Logs -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/kern.log</location>
  </localfile>

  <!-- Monitor command executions -->
  <localfile>
    <log_format>audit</log_format>
    <location>/var/log/audit/audit.log</location>
  </localfile>
```

**Save (Ctrl+X, Y, Enter) and restart**:
```bash
sudo systemctl restart wazuh-agent
```

### Step 3: Enable Auditd for Command Logging
```bash
# Install auditd
sudo apt install auditd audispd-plugins -y

# Add rules to monitor commands
sudo nano /etc/audit/rules.d/audit.rules

# Add these lines:
-a exit,always -F arch=b64 -S execve -k exec
-w /bin/bash -p x -k bash_exec
-w /usr/bin/sudo -p x -k sudo_exec

# Restart auditd
sudo systemctl restart auditd

# Verify rules loaded
sudo auditctl -l
```

**🔍 CHECKPOINT**: Run a test command
```bash
# On PC 1
sudo ls /root

# Then in Wazuh Dashboard → Discover:
agent.name: "PC1-Ubuntu-DL" AND data.audit.exe: "/usr/bin/sudo"
```
You should see the sudo command logged

---

## Week 4, Day 3-4: Learning KQL & Verification (5 hours)

### Activity 1: Basic KQL Queries (3 hours)

Open Wazuh Dashboard → **Discover** tab

**Query 1: See all Windows Security Events**
```
agent.name: "PC2-Windows" AND winlog.channel: "Security"
```

**Query 2: Failed Login Attempts (Windows)**
```
agent.name: "PC2-Windows" AND winlog.event_id: 4625
```

**Query 3: Successful Logins (Windows)**
```
agent.name: "PC2-Windows" AND winlog.event_id: 4624
```

**Query 4: PowerShell Executions**
```
agent.name: "PC2-Windows" AND winlog.event_id: 4104
```

**Query 5: Linux SSH Logins**
```
agent.name: "PC1-Ubuntu-DL" AND data.srcip: *
```

**Query 6: All Process Creations (Sysmon)**
```
winlog.event_id: 1 AND winlog.provider_name: "Microsoft-Windows-Sysmon"
```

**Query 7: Processes Started by Users**
```
winlog.event_id: 1 AND winlog.event_data.User: *
```

**Query 8: Time-Based Query (Last Hour)**
```
@timestamp > "now-1h" AND agent.name: "PC2-Windows"
```

### Activity 2: Create Saved Searches (1 hour)

1. After running each query above, click **Save** (top right)
2. Name them:
   - "Failed Logins - Windows"
   - "PowerShell Activity"
   - "SSH Logins - Linux"
   - "All Process Creations"

### Activity 3: Build Your First Visualization (1 hour)

1. **Dashboard** → **Create visualization**
2. **Vertical Bar Chart**:
   - **Metrics**: Count
   - **Buckets**: 
     - X-axis: Date Histogram (@timestamp)
     - Split Series: Terms (agent.name.keyword)
3. **Title**: "Events by Agent Over Time"
4. **Save**

---

## Week 4, Day 5: Documentation (2 hours)

### Document Your Log Sources

```bash
cd ~/wazuh-soc-homelab/docs
nano log-sources-inventory.md
```

**Write**:
```markdown
# Log Sources Inventory

## Active Agents

### PC2-Windows (192.168.1.Y)
**Role**: Primary Windows monitoring endpoint  
**OS**: Windows 10/11  
**Agent Version**: 4.9.0

**Collected Logs**:
- Windows Security Events (Event ID 4624, 4625, 4672, etc.)
- Windows System Events
- Windows Application Events  
- Sysmon Events (Process Creation, Network Connections, File Creation)
- PowerShell Operational Logs (Script Block Logging)

**Average Event Rate**: ~500 events/hour

**Key Use Cases**:
- Detecting suspicious PowerShell usage
- Monitoring failed login attempts (brute force)
- Tracking process creations for malware analysis

---

### PC1-Ubuntu-DL (192.168.1.X)
**Role**: Linux monitoring endpoint (concurrent with DL training)  
**OS**: Ubuntu 24.04 LTS  
**Agent Version**: 4.9.0

**Collected Logs**:
- /var/log/syslog (general system logs)
- /var/log/auth.log (SSH logins, sudo usage)
- /var/log/kern.log (kernel messages)
- Auditd logs (command executions)

**Average Event Rate**: ~200 events/hour

**Key Use Cases**:
- SSH brute force detection
- Privilege escalation monitoring (sudo abuse)
- Suspicious command execution detection

---

## Baseline Metrics (Week 4, Day 5)

| Metric | Value | Notes |
|--------|-------|-------|
| Total Agents | 2 | Windows: 1, Linux: 1 |
| Events/Day | ~16,800 | 700/hour × 24h |
| Index Size | ~2GB/week | Growing linearly |
| Oldest Data | [DATE] | When agents first connected |

## Known Gaps (To Address in Phase 7)
- ❌ No network-level visibility (waiting for Raspberry Pi)
- ❌ No firewall logs yet
- ❌ No web server logs

## Query Performance
- Simple queries (<1 field): <1 second
- Complex queries (3+ fields): 2-5 seconds
- Acceptable for threat hunting
```

### Create KQL Cheatsheet
```bash
nano ~/wazuh-soc-homelab/docs/kql-cheatsheet.md
```

**Write**:
```markdown
# KQL Quick Reference for Wazuh

## Basic Syntax
```kql
# Single field match
field: value

# Multiple conditions (AND)
field1: value1 AND field2: value2

# OR condition
field1: value1 OR field1: value2

# NOT condition
NOT field: value

# Wildcard
field: *partial*

# Range
field: [100 TO 200]

# Time range
@timestamp > "now-1h"
```

## Common Wazuh Fields
```kql
agent.name: "PC2-Windows"          # Filter by agent
rule.level: [10 TO *]              # High severity (10+)
rule.mitre.id: "T1059.001"         # MITRE ATT&CK technique
winlog.event_id: 4625              # Windows Event ID
data.srcip: "192.168.1.*"          # Source IP (Linux logs)
```

## Useful Queries
```kql
# Failed logins (Windows)
winlog.event_id: 4625 AND winlog.event_data.Status: "0xC000006D"

# PowerShell downloads
winlog.event_id: 4104 AND data.ScriptBlockText: *DownloadString*

# Sudo usage (Linux)
data.audit.key: "sudo_exec"

# Sysmon network connections
winlog.event_id: 3 AND winlog.event_data.DestinationPort: 443

# High severity alerts
rule.level: >= 10
```

## Time Filters
```kql
@timestamp > "now-1h"              # Last hour
@timestamp > "now-1d"              # Last day  
@timestamp > "now-7d"              # Last week
@timestamp: ["now-2h" TO "now"]    # Last 2 hours
```
```

### Update GitHub
```bash
cd ~/wazuh-soc-homelab
git add docs/
git add screenshots/phase2/  # Add your new agent screenshots
nano README.md
```

**Update Progress**:
```markdown
### Progress
- [x] Phase 0: Environment Setup ✅
- [x] Phase 1: Wazuh Deployment ✅
- [x] Phase 2: Log Ingestion ✅
  - 2 active agents (Windows, Linux)
  - ~16,800 events/day ingested
  - Sysmon deployed on Windows
  - Auditd configured on Linux
  - 8+ saved KQL searches created
- [ ] Phase 3: Threat Simulation
...
```

```bash
git add .
git commit -m "Phase 2 complete: Multi-source log ingestion"
git push origin main
```

---

## 📊 Phase 2 Completion Checklist

- [ ] Windows agent (PC 2) installed and active
- [ ] Linux agent (PC 1) installed and active (running alongside DL training)
- [ ] Sysmon installed on Windows
- [ ] Auditd configured on Linux
- [ ] Can query logs from both agents in Dashboard
- [ ] Created 8+ saved KQL searches
- [ ] Built at least 1 visualization
- [ ] Log sources documented
- [ ] KQL cheatsheet created
- [ ] GitHub updated with agent screenshots

### Verification Queries:
```kql
# Should return results from BOTH agents
agent.name: *

# Should show Windows events
agent.name: "PC2-Windows" AND winlog.event_id: *

# Should show Linux events
agent.name: "PC1-Ubuntu-DL" AND data.srcip: *

# Should show Sysmon process creations
winlog.provider_name: "Microsoft-Windows-Sysmon" AND winlog.event_id: 1
```

**🎉 Phase 2 Complete!** You now have multi-source visibility.

---

# 🎭 PHASE 3: Threat Simulation (Week 5-6 - 25 hours)

## Goals
- [ ] Install Atomic Red Team on both endpoints
- [ ] Execute 10+ MITRE ATT&CK techniques
- [ ] Document each attack's log artifacts
- [ ] Identify detection gaps

## Week 5, Day 1-2: Setup Atomic Red Team - Windows (6 hours)

### Step 1: Install Atomic Red Team on PC 2

**On PC 2, open PowerShell as Administrator**:

```powershell
# Install PowerShell Gallery modules
Set-ExecutionPolicy Bypass -Scope CurrentUser -Force
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# Install Invoke-AtomicRedTeam
Install-Module -Name invoke-atomicredteam -Scope CurrentUser -Force

# Import module
Import-Module invoke-atomicredteam

# Install Atomic tests
Invoke-AtomicTest All -GetPrereqs

# Verify installation
Get-Command -Module invoke-atomicredteam
```

**🔍 CHECKPOINT**: You should see commands like `Invoke-AtomicTest`, `Get-AtomicTechnique`

### Step 2: First Test Run (T1059.001 - PowerShell)

```powershell
# List available tests for PowerShell technique
Get-AtomicTechnique -Id T1059.001

# Run FIRST test only (test #1)
Invoke-AtomicTest T1059.001 -TestNumbers 1

# This should execute: Write-Host "Hello from PowerShell"
```

**Now check Wazuh Dashboard**:
1. Go to **Discover**
2. Query:
```kql
agent.name: "PC2-Windows" AND winlog.event_id: 4104 AND data.ScriptBlockText: *Hello from PowerShell*
```
3. **Screenshot the result** - this is your first detected attack!

### Step 3: Document the Test

```bash
# On laptop (SSH or direct)
cd ~/wazuh-soc-homelab/docs
mkdir -p attack-simulations
nano attack-simulations/T1059.001-PowerShell.md
```

**Write**:
```markdown
# T1059.001 - Command and Scripting Interpreter: PowerShell

## Test Information
- **Date**: [TODAY'S DATE]
- **Tested On**: PC2-Windows
- **Tool**: Atomic Red Team
- **Test Number**: 1

## Attack Description
Executes a benign PowerShell command to test logging visibility.

## Command Executed
```powershell
Write-Host "Hello from PowerShell"
```

## Expected Log Artifacts
- **Log Source**: PowerShell Operational Log
- **Event ID**: 4104 (Script Block Logging)
- **Key Fields**:
  - `data.ScriptBlockText`: Contains executed command
  - `winlog.user.name`: User who ran the command

## Detection Query (KQL)
```kql
agent.name: "PC2-Windows" AND winlog.event_id: 4104 AND data.ScriptBlockText: *Write-Host*
```

## Results
✅ **DETECTED**: Event ID 4104 logged the full script block  
❌ **NOT ALERTED**: No Wazuh alert generated (expected - benign command)

## Screenshots
- [Link to screenshot in screenshots/phase3/T1059.001-test1.png]

## Lessons Learned
- PowerShell logging works correctly
- Need to create alert rule for suspicious PowerShell keywords (e.g., DownloadString, Invoke-Expression, EncodedCommand)
```

---

## Week 5, Day 3-5: Execute Windows Attack Techniques (10 hours)

### Attack Scenario 1: Credential Access (T1003.001)

**On PC 2**:
```powershell
# This attempts to dump LSASS memory (DANGEROUS - will generate alert)
Invoke-AtomicTest T1003.001 -TestNumbers 1

# Wait 30 seconds, then check Wazuh Dashboard
```

**Query**:
```kql
agent.name: "PC2-Windows" AND (winlog.event_id: 10 OR rule.description: *lsass*)
```

**Document it** in `attack-simulations/T1003.001-LSASS-Dump.md`

---

### Attack Scenario 2: Persistence (T1547.001 - Registry Run Keys)

```powershell
# Add malicious registry run key
Invoke-AtomicTest T1547.001 -TestNumbers 1

# Check what happened
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Run
```

**Query**:
```kql
agent.name: "PC2-Windows" AND winlog.event_id: 13 AND winlog.event_data.TargetObject: *CurrentVersion\\Run*
```

**Document it** in `attack-simulations/T1547.001-Registry-Persistence.md`

---

### Attack Scenario 3: Defense Evasion (T1562.001 - Disable Windows Defender)

```powershell
# Attempt to disable Windows Defender (will likely fail due to protections)
Invoke-AtomicTest T1562.001 -TestNumbers 1

# Check for alert
```

**Query**:
```kql
agent.name: "PC2-Windows" AND data.win.eventdata.commandLine: *Set-MpPreference*
```

---

### Attack Scenario 4: Discovery (T1087.001 - Local Account Discovery)

```powershell
# Enumerate local users
Invoke-AtomicTest T1087.001 -TestNumbers 1

# This runs: net user
```

**Query**:
```kql
agent.name: "PC2-Windows" AND winlog.event_id: 1 AND winlog.event_data.CommandLine: *net user*
```

---

### Attack Scenario 5: Lateral Movement (T1021.001 - RDP)

```powershell
# Simulate RDP connection attempt (to yourself)
Invoke-AtomicTest T1021.001 -TestNumbers 1
```

**Query**:
```kql
agent.name: "PC2-Windows" AND winlog.event_id: 4624 AND winlog.event_data.LogonType: "10"
```

---

## Week 6, Day 1-2: Execute Linux Attack Techniques (5 hours)

### Setup Atomic Red Team on PC 1 (Ubuntu)

**SSH into PC 1**:
```bash
ssh your_username@192.168.1.X
```

```bash
# Install prerequisites
sudo apt install -y git curl

# Clone Atomic Red Team repo
cd ~
git clone https://github.com/redcanaryco/atomic-red-team.git
cd atomic-red-team

# Install Atomic executor (if needed)
# Most tests can run directly with bash
```

### Attack Scenario 6: Initial Access (T1078.001 - SSH Brute Force)

```bash
# Create a test user
sudo useradd -m testuser
echo "testuser:TestPassword123!" | sudo chpasswd

# Simulate failed SSH attempts
for i in {1..10}; do
  sshpass -p 'wrongpassword' ssh testuser@localhost 2>&1
  sleep 1
done

# Check Wazuh Dashboard
```

**Query**:
```kql
agent.name: "PC1-Ubuntu-DL" AND data.srcip: "127.0.0.1" AND data.srcuser: "testuser"
```

**Document it** in `attack-simulations/T1078.001-SSH-Brute-Force.md`

---

### Attack Scenario 7: Privilege Escalation (T1548.003 - Sudo Abuse)

```bash
# Attempt to run sudo commands
sudo cat /etc/shadow

# This generates audit logs
```

**Query**:
```kql
agent.name: "PC1-Ubuntu-DL" AND data.audit.key: "sudo_exec" AND data.audit.exe: "/usr/bin/sudo"
```

---

### Attack Scenario 8: Execution (T1059.004 - Unix Shell)

```bash
# Execute suspicious commands
echo "echo 'malicious payload' > /tmp/test.sh" | bash
bash -c 'whoami; id; uname -a'

# Check logs
```

**Query**:
```kql
agent.name: "PC1-Ubuntu-DL" AND data.audit.exe: "/bin/bash" AND data.audit.key: "bash_exec"
```

---

## Week 6, Day 3-4: Gap Analysis & Documentation (4 hours)

### Create Detection Gap Matrix

```bash
cd ~/wazuh-soc-homelab/docs
nano detection-gap-analysis.md
```

**Write**:
```markdown
# Detection Gap Analysis

## Tested Techniques Summary

| ATT&CK ID | Technique Name | Platform | Detected? | Alert Generated? | Gap |
|-----------|----------------|----------|-----------|------------------|-----|
| T1059.001 | PowerShell | Windows | ✅ Yes | ❌ No | Need rule for suspicious keywords |
| T1003.001 | LSASS Dump | Windows | ✅ Yes | ✅ Yes | Existing rule works |
| T1547.001 | Registry Persistence | Windows | ✅ Yes | ❌ No | Need rule for Run key modifications |
| T1562.001 | Disable Defender | Windows | ✅ Yes | ❌ No | Need rule for Set-MpPreference |
| T1087.001 | Account Discovery | Windows | ✅ Yes | ❌ No | Need rule for 'net user' commands |
| T1021.001 | RDP Login | Windows | ✅ Yes | ✅ Yes | Existing rule works |
| T1078.001 | SSH Brute Force | Linux | ✅ Yes | ✅ Yes | Existing rule works (5+ failures) |
| T1548.003 | Sudo Abuse | Linux | ✅ Yes | ❌ No | Need rule for /etc/shadow access |
| T1059.004 | Unix Shell | Linux | ✅ Yes | ❌ No | Need context-aware rule |

## Key Findings

### Strengths
- ✅ Log visibility is excellent across both platforms
- ✅ Sysmon provides rich process telemetry
- ✅ Auditd captures command-line activity
- ✅ Default Wazuh rules catch obvious attacks (LSASS, brute force)

### Weaknesses
- ❌ Many techniques logged but not alerted
- ❌ No correlation rules (multi-step attacks)
- ❌ High false positive risk for some detections
- ❌ No network-level detection yet (waiting for Pi)

## Priority Detection Rules to Create (Phase 4)
1. PowerShell obfuscation/suspicious commands
2. Registry Run key persistence
3. Windows Defender tampering
4. 'net user' discovery commands
5. Sudo abuse with sensitive files
6. Suspicious bash command patterns
7. Process injection (Sysmon Event ID 8)
8. Unusual parent-child process relationships
```

### Screenshot Everything

Create organized screenshots:
```
screenshots/phase3/
├── T1059.001-powershell-detected.png
├── T1003.001-lsass-alert.png
├── T1547.001-registry-event.png
├── T1078.001-ssh-bruteforce.png
└── dashboard-overview.png
```

### Update GitHub

```bash
cd ~/wazuh-soc-homelab
git add docs/attack-simulations/
git add docs/detection-gap-analysis.md
git add screenshots/phase3/
nano README.md
```

**Update Progress**:
```markdown
### Progress
- [x] Phase 0: Environment Setup ✅
- [x] Phase 1: Wazuh Deployment ✅
- [x] Phase 2: Log Ingestion ✅
- [x] Phase 3: Threat Simulation ✅
  - Atomic Red Team deployed on both endpoints
  - 9 MITRE ATT&CK techniques tested
  - Detection gap analysis completed
  - 9 attack simulation docs created
- [ ] Phase 4: Detection Engineering
...
```

```bash
git add .
git commit -m "Phase 3 complete: Threat simulation and gap analysis"
git push origin main
```

---

## 📊 Phase 3 Completion Checklist

- [ ] Atomic Red Team installed on PC 2 (Windows)
- [ ] Atomic Red Team setup on PC 1 (Linux)
- [ ] Executed 9+ attack techniques across both platforms
- [ ] Documented each attack with:
  - [ ] Attack description
  - [ ] Commands used
  - [ ] Expected log artifacts
  - [ ] KQL detection query
  - [ ] Screenshot of detected event
- [ ] Created detection gap analysis matrix
- [ ] Identified 7+ rules to create in Phase 4
- [ ] GitHub updated with attack simulations

### Verification:
```bash
# Check you have these files:
ls ~/wazuh-soc-homelab/docs/attack-simulations/
# Should show 9 markdown files

ls ~/wazuh-soc-homelab/screenshots/phase3/
# Should show 9+ screenshots
```

**🎉 Phase 3 Complete!** You've tested your defenses and know exactly what to build next.

---

# 🔍 PHASE 4: Detection Engineering (Week 7-8 - 30 hours)

[Due to length constraints, I'm providing the structure. Shall I continue with the detailed Phase 4-7 content in a follow-up response?]

**This is a DETAILED roadmap covering your first 6 weeks. Would you like me to**:
1. ✅ Continue with detailed Phase 4-7 (Detection Engineering → Portfolio)
2. ✅ Create a separate "Troubleshooting Guide" document
3. ✅ Create a "Daily Checklist" for each week

Let me know and I'll generate the remaining phases with the same level of detail!

[Phases 4-7 content continues from Phase 3...]

# Continue with full implementation details for all remaining phases
