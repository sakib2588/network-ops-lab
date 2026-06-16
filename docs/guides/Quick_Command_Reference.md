# Blue Team Lab - Quick Command Reference

## Phase 2: Log Collection Configuration

### Windows Event Log Configuration (192.168.1.20)

```powershell
# Edit Wazuh config
notepad "C:\Program Files (x86)\ossec-agent\ossec.conf"

# Add PowerShell Operational log:
# <localfile>
#   <location>Microsoft-Windows-PowerShell/Operational</location>
#   <log_format>eventchannel</log_format>
# </localfile>

# Restart agent
Restart-Service WazuhSvc
```

### Install Sysmon (Windows)

```powershell
# Download
Invoke-WebRequest -Uri https://download.sysinternals.com/files/Sysmon.zip -OutFile C:\Tools\Sysmon.zip
Expand-Archive C:\Tools\Sysmon.zip -DestinationPath C:\Tools\Sysmon

# Download config
Invoke-WebRequest -Uri https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml -OutFile C:\Tools\Sysmon\sysmonconfig.xml

# Install
cd C:\Tools\Sysmon
.\Sysmon64.exe -accepteula -i sysmonconfig.xml

# Verify
Get-Service Sysmon64
```

### Install Auditd (Linux - All Endpoints)

```bash
# Install
sudo apt install -y auditd audispd-plugins  # Pop!_OS
sudo pacman -S audit  # Arch Linux

# Edit rules
sudo vim /etc/audit/rules.d/audit.rules

# Load rules
sudo augenrules --load

# Restart
sudo systemctl restart auditd
```

### Configure Wazuh for Audit Logs

```bash
# Edit config
sudo vim /var/ossec/etc/ossec.conf

# Add:
# <localfile>
#   <log_format>audit</log_format>
#   <location>/var/log/audit/audit.log</location>
# </localfile>

# Restart
sudo systemctl restart wazuh-agent
```

---

## Phase 3: Attack Simulation

### Install Atomic Red Team (Windows Attack VM)

```powershell
# Install module
Set-ExecutionPolicy Bypass -Scope Process -Force
Install-Module -Name invoke-atomicredteam,powershell-yaml -Scope CurrentUser -Force

# Install framework
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
Install-AtomicRedTeam -getAtomics -Force

# Verify
Get-Command Invoke-AtomicTest
```

### Execute Atomic Tests

```powershell
# View test details
Invoke-AtomicTest T1059.001 -ShowDetails

# Run test
Invoke-AtomicTest T1059.001 -TestNumbers 1

# Cleanup
Invoke-AtomicTest T1059.001 -Cleanup
```

### Check Wazuh Dashboard for Alerts

```
Dashboard URL: https://192.168.1.10

Search queries:
- rule.groups:powershell
- rule.id:>=100000  (custom rules)
- agent.name:"WIN-CLIENT01"
- rule.level:>=10  (high severity)
```

---

## Phase 4: Custom Rules

### Edit Custom Rules

```bash
# On Wazuh Server
sudo vim /var/ossec/etc/rules/local_rules.xml

# Add rules (ID 100000-100999)
```

### Test Rule Syntax

```bash
# Interactive testing
sudo /var/ossec/bin/wazuh-logtest

# Paste log, check if rule matches
# Ctrl+C to exit
```

### Load New Rules

```bash
# Restart manager
sudo systemctl restart wazuh-manager

# Check for errors
sudo tail -f /var/ossec/logs/ossec.log | grep -i error
```

---

## Common Wazuh Dashboard Queries

```
# PowerShell events
rule.groups:powershell

# Sysmon process creation
data.win.eventdata.eventID:1

# Failed authentication
rule.groups:authentication_failed

# Custom rules
rule.id:>=100000

# High severity
rule.level:>=12

# Specific agent
agent.name:"WIN-CLIENT01"

# Last hour
timestamp:[now-1h TO now]

# Combine
rule.groups:powershell AND rule.level:>=10
```

---

## Useful Wazuh Server Commands

```bash
# Check agent status
/var/ossec/bin/agent_control -l

# View alerts
sudo tail -f /var/ossec/logs/alerts/alerts.log

# View archives (all events)
sudo tail -f /var/ossec/logs/archives/archives.log

# Restart manager
sudo systemctl restart wazuh-manager

# Check manager status
sudo systemctl status wazuh-manager

# View manager logs
sudo tail -f /var/ossec/logs/ossec.log

# Check Wazuh version
/var/ossec/bin/wazuh-control info
```

---

## Create Snapshots

```bash
# Power off VM
sudo shutdown -h now

# From host machine
vboxmanage snapshot "Wazuh-Server" take "Phase2-Complete" \
  --description "All log sources configured"

# List snapshots
vboxmanage snapshot "Wazuh-Server" list

# Restore snapshot
vboxmanage snapshot "Wazuh-Server" restore "Phase2-Complete"

# Start VM
vboxmanage startvm "Wazuh-Server" --type headless
```

---

## Troubleshooting

### Agent Not Connecting

```bash
# On agent
sudo systemctl status wazuh-agent
sudo tail -f /var/ossec/logs/ossec.log

# Check firewall
sudo ufw status
sudo ufw allow from 192.168.1.10 to any port 1514

# Restart agent
sudo systemctl restart wazuh-agent
```

### No Events in Dashboard

```bash
# Check indexer
sudo systemctl status wazuh-indexer

# Check dashboard
sudo systemctl status wazuh-dashboard

# Restart services
sudo systemctl restart wazuh-indexer
sudo systemctl restart wazuh-manager
sudo systemctl restart wazuh-dashboard
```

### Sysmon Not Logging

```powershell
# Check service
Get-Service Sysmon64

# Check event log
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 10

# Restart service
Restart-Service Sysmon64
```

### Rule Not Triggering

```bash
# Test in logtest
sudo /var/ossec/bin/wazuh-logtest

# Check field names in raw event
# Dashboard → Event → View JSON

# Verify parent rule exists
sudo grep -r "rule id=\"91816\"" /var/ossec/ruleset/rules/

# Check manager loaded rules
sudo systemctl restart wazuh-manager
```

---

## Quick Reference: IP Addresses

```
192.168.1.1   - Router/Gateway
192.168.1.10  - Wazuh Server (VM)
192.168.1.11  - 16GB Desktop Host (Linux agent)
192.168.1.20  - 4GB Windows PC (victim)
192.168.1.30  - Arch Laptop Host (Linux agent)
192.168.1.31  - Atomic Red Team VM (attacker)
```

---

## Phase Progression Checklist

```
Phase 0: ✅ Architecture Setup
Phase 1: ✅ Wazuh Installation
Phase 2: ⏳ Log Collection (Current)
  - [ ] Windows Event Logs configured
  - [ ] Sysmon installed
  - [ ] Linux auditd configured
  - [ ] FIM configured
  - [ ] Baseline established
  
Phase 3: ⬜ Attack Simulation
  - [ ] Atomic Red Team installed
  - [ ] 12+ techniques tested
  - [ ] Detection gaps identified
  
Phase 4: ⬜ Custom Rules
  - [ ] 15+ rules created
  - [ ] All rules tested
  - [ ] Documentation complete
  
Phase 5: ⬜ Playbooks
Phase 6: ⬜ Final Integration
Phase 7: ⬜ GitHub Portfolio
```

---

## Important Files Locations

### Windows
```
Wazuh Agent Config: C:\Program Files (x86)\ossec-agent\ossec.conf
Wazuh Agent Logs: C:\Program Files (x86)\ossec-agent\ossec.log
Sysmon Config: C:\Tools\Sysmon\sysmonconfig.xml
Attack Logs: C:\AttackLogs\
```

### Linux
```
Wazuh Agent Config: /var/ossec/etc/ossec.conf
Wazuh Agent Logs: /var/ossec/logs/ossec.log
Audit Rules: /etc/audit/rules.d/audit.rules
Audit Log: /var/log/audit/audit.log
Auth Log: /var/log/auth.log
```

### Wazuh Server
```
Manager Config: /var/ossec/etc/ossec.conf
Custom Rules: /var/ossec/etc/rules/local_rules.xml
Default Rules: /var/ossec/ruleset/rules/
Alerts: /var/ossec/logs/alerts/alerts.log
Archives: /var/ossec/logs/archives/archives.log
Manager Logs: /var/ossec/logs/ossec.log
```

---

## Critical MITRE ATT&CK Techniques to Test

```
T1059.001 - PowerShell Execution
T1003.001 - LSASS Memory Dumping
T1071.001 - C2 Communication
T1055 - Process Injection
T1027 - Obfuscation (Base64)
T1053.005 - Scheduled Task
T1547.001 - Registry Run Keys
T1105 - File Download
T1070.004 - File Deletion
T1082 - System Discovery
T1110 - Brute Force
T1548.003 - Sudo Abuse
```

---

## Emergency Procedures

### Restore to Last Known Good State

```bash
# Stop VM
vboxmanage controlvm "Wazuh-Server" poweroff

# Restore snapshot
vboxmanage snapshot "Wazuh-Server" restore "Phase2-Complete"

# Start VM
vboxmanage startvm "Wazuh-Server" --type headless
```

### Reset Wazuh Configuration

```bash
# Backup current
sudo cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.broken

# Restore from backup
sudo cp /var/ossec/etc/ossec.conf.phase2.backup /var/ossec/etc/ossec.conf

# Restart
sudo systemctl restart wazuh-manager
```

---

**Last Updated**: February 13, 2025
