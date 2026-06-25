# Phase 8 --- Windows Endpoint Detection (Sysmon + Wazuh + Atomic Red Team) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Windows endpoint (agent 007, 192.168.1.104) real process/registry/network visibility via Sysmon, ship it to Wazuh, then prove two MITRE techniques (T1059.001 PowerShell, T1003.001 LSASS credential dumping) are detected --- using detection-TDD (run the attack with NO rule first to prove the gap, then deploy and prove the catch).

**Architecture:** Sysmon (SwiftOnSecurity config) installs on the Windows box and writes to the `Microsoft-Windows-Sysmon/Operational` event channel. The Wazuh agent already enrolled to manager 192.168.1.50 is told to forward that channel. The manager's built-in Sysmon ruleset decodes the events; two custom rules (IDs 100022-100023, MITRE-tagged) sharpen the alerts for the two techniques. Atomic Red Team is the attack framework; a deterministic generator command backs each test so rule validation does not depend on the ART catalog drifting.

**Tech Stack:** Sysmon (Sysinternals), SwiftOnSecurity sysmon-config, Wazuh agent 4.14.5 (Windows), Wazuh manager 4.14.5 (192.168.1.50), Invoke-AtomicRedTeam (PowerShell), Wazuh local rules (PCRE2).

**Hosts and where each command runs:**
- **Windows .104** --- Sysmon install, agent config edit, Atomic Red Team. Commands run in an **Administrator PowerShell**.
- **Manager .50** --- rule edits, `wazuh-logtest`, restart. Commands run over **SSH with sudo**.
- **This repo** (`/media/filwel/All/Sakib/Cyber Security Project/`) --- the repo copy of rules + all documentation.

**Detection-TDD discipline (the spine of this plan):**
- **RED** --- run the attack BEFORE the collection/rule exists. Confirm NO alert. The gap is the finding.
- **GREEN** --- deploy collection + rule. Run the same attack. Confirm the alert fires with the right level and MITRE id.
- **Document** --- every RED/GREEN pair becomes an incident report + journal entry.

**Safety rails (do not skip):**
- Before editing the live `local_rules.xml`, ALWAYS back it up. A syntax error stops `wazuh-manager` from starting and takes the whole dashboard down (per `rules/README.md`).
- The T1003.001 test dumps LSASS --- Microsoft Defender will likely quarantine it. That is expected and is itself a detection signal. Handle Defender explicitly in Task 6, do not blanket-disable it.
- This is your own lab. All targets are owned hardware.

---

## File Structure

**Created in this repo:**
- `phases/phase8_windows_endpoint_detection/PLAN.md` --- this file
- `phases/phase8_windows_endpoint_detection/README.md` --- phase summary for the portfolio
- `phases/phase8_windows_endpoint_detection/sysmon_collection.xml` --- the `<localfile>` block added to the Windows agent
- `incidents/phase8_t1059_powershell_encodedcommand_report.md` --- RED/GREEN writeup, technique 1
- `incidents/phase8_t1003_lsass_dump_report.md` --- RED/GREEN writeup, technique 2
- `phases/phase5_playbooks/playbook_windows_credential_dumping.md` --- analyst playbook for T1003.001

**Modified in this repo:**
- `rules/local_rules.xml` --- add rules 100022-100023 (repo copy of what is deployed to the manager)
- `docs/Detection_Engineering_Journal_2026-06-19.md` --- new dated journal entry (create if absent)
- `PROJECT_STATUS.md` --- mark Phase 8 progress
- `portfolio/README.md` --- add the Windows endpoint detection chapter

**Modified on live hosts (NOT in repo):**
- Windows .104: `C:\Program Files (x86)\ossec-agent\ossec.conf`
- Manager .50: `/var/ossec/etc/rules/local_rules.xml`

---

## Task 0: Pre-flight baseline

**Files:** none (verification only)

- [ ] **Step 1: Confirm the Windows agent is active and on 4.14.5**

On the Wazuh dashboard (or manager .50): Agents -> 007 User-hp. Confirm Status = active, Version = v4.14.5.

Alternative from manager .50:
```bash
sudo /var/ossec/bin/agent_control -l | grep -i "User-hp"
```
Expected: `ID: 007, Name: User-hp, IP: 192.168.1.104, Active`

- [ ] **Step 2: Snapshot the current Windows channels being collected**

On Windows .104, Administrator PowerShell:
```powershell
Select-String -Path "C:\Program Files (x86)\ossec-agent\ossec.conf" -Pattern "location"
```
Expected: Security / Application / System channels only --- NO `Microsoft-Windows-Sysmon/Operational` line yet. This confirms the starting point.

- [ ] **Step 3: Create the phase directory and commit the empty scaffold**

```bash
cd "/media/filwel/All/Sakib/Cyber Security Project"
git checkout -b phase8-windows-endpoint-detection
git add phases/phase8_windows_endpoint_detection/PLAN.md
git commit -m "Phase 8: add Windows endpoint detection plan"
```

---

## Task 1: RED for T1059.001 --- prove PowerShell execution is invisible

**Files:** none yet (this is the RED baseline; Sysmon is deliberately not installed)

- [ ] **Step 1: Generate a deterministic PowerShell EncodedCommand event**

On Windows .104, Administrator PowerShell:
```powershell
$cmd = "Write-Host 'phase8-t1059-red'"
$enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
powershell.exe -NoProfile -EncodedCommand $enc
```
Expected: prints `phase8-t1059-red`. This is the exact telemetry shape Task 5 will detect.

- [ ] **Step 2: Look for the event in Wazuh**

On the dashboard: Threat Hunting / Discover, filter `agent.id:007` for the last 5 minutes, search `EncodedCommand` or `powershell`.
Expected: **nothing process-level.** Without Sysmon (and with Windows process-creation auditing off by default), Wazuh has no record the command ran. **This empty result is the gap --- screenshot it.**

- [ ] **Step 3: Record the RED result**

Create `incidents/phase8_t1059_powershell_encodedcommand_report.md` with a "RED (before)" section: the command run, the empty Wazuh search, the screenshot path. Leave the "GREEN (after)" section as a stub to fill in Task 5.

```bash
git add incidents/phase8_t1059_powershell_encodedcommand_report.md
git commit -m "Phase 8: RED baseline for T1059.001 (no process visibility)"
```

---

## Task 2: Install Sysmon on Windows .104

**Files:** none in repo (host change); config URL recorded in README later

- [ ] **Step 1: Download Sysmon and the SwiftOnSecurity config**

On Windows .104, Administrator PowerShell:
```powershell
$dir = "C:\Tools\Sysmon"; New-Item -ItemType Directory -Force -Path $dir | Out-Null
Invoke-WebRequest "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "$dir\Sysmon.zip"
Expand-Archive "$dir\Sysmon.zip" -DestinationPath $dir -Force
Invoke-WebRequest "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile "$dir\sysmonconfig.xml"
```
Expected: `Sysmon64.exe` and `sysmonconfig.xml` present in `C:\Tools\Sysmon`.

- [ ] **Step 2: Install Sysmon with the config**

```powershell
& "$dir\Sysmon64.exe" -accepteula -i "$dir\sysmonconfig.xml"
```
Expected: "Sysmon64 installed." and "Sysmon64 started."

- [ ] **Step 3: Verify Sysmon is logging**

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 3 | Format-Table TimeCreated, Id, Message -Wrap
```
Expected: recent events with Id 1 (ProcessCreate), 3 (NetworkConnect), etc. If this returns events, Sysmon works.

---

## Task 3: Forward the Sysmon channel to Wazuh

**Files:**
- Create: `phases/phase8_windows_endpoint_detection/sysmon_collection.xml` (repo copy of the block)
- Modify on host: `C:\Program Files (x86)\ossec-agent\ossec.conf`

- [ ] **Step 1: Save the collection block to the repo**

Create `phases/phase8_windows_endpoint_detection/sysmon_collection.xml`:
```xml
<!-- Add inside <ossec_config> on the Windows agent .104 -->
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

- [ ] **Step 2: Back up the live agent config, then add the block**

On Windows .104, Administrator PowerShell:
```powershell
$conf = "C:\Program Files (x86)\ossec-agent\ossec.conf"
Copy-Item $conf "$conf.bak"
```
Then edit `ossec.conf` (Notepad as Administrator) and paste the `<localfile>` block from Step 1 just before the closing `</ossec_config>`.

- [ ] **Step 3: Restart the agent**

```powershell
Restart-Service -Name WazuhSvc
Get-Service WazuhSvc
```
Expected: Status = Running.

- [ ] **Step 4: Commit the repo copy**

```bash
cd "/media/filwel/All/Sakib/Cyber Security Project"
git add phases/phase8_windows_endpoint_detection/sysmon_collection.xml
git commit -m "Phase 8: forward Sysmon Operational channel to Wazuh"
```

---

## Task 4: GREEN baseline --- confirm Sysmon process events reach Wazuh

**Files:** none (validation)

- [ ] **Step 1: Re-run the deterministic PowerShell event**

On Windows .104, Administrator PowerShell:
```powershell
$cmd = "Write-Host 'phase8-t1059-green-baseline'"
$enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
powershell.exe -NoProfile -EncodedCommand $enc
```

- [ ] **Step 2: Confirm Wazuh now ingests the Sysmon Event 1**

On the dashboard: filter `agent.id:007 AND data.win.system.providerName:"Microsoft-Windows-Sysmon"` for the last 5 minutes.
Expected: a process-creation event for `powershell.exe` with `data.win.eventdata.commandLine` containing `-EncodedCommand`. The built-in Wazuh Sysmon ruleset will tag it (rule in the 61600 range / group `sysmon_event1`).

- [ ] **Step 3: Capture one raw event for rule development**

On manager .50, grab the decoded event from the archives so Task 5 can iterate the rule offline:
```bash
sudo grep -m1 "EncodedCommand" /var/ossec/logs/archives/archives.json | sudo tee /tmp/sysmon_t1059_sample.json
```
Expected: one JSON line with `win.eventdata.commandLine`. (If archives is empty, enable `<logall_json>yes</logall_json>` in the manager `ossec.conf` `<global>`, restart, re-run Step 1, then disable it again.)

---

## Task 5: GREEN for T1059.001 --- custom rule 100022

**Files:**
- Modify on host: `/var/ossec/etc/rules/local_rules.xml` (manager .50)
- Modify in repo: `rules/local_rules.xml`

- [ ] **Step 1: Back up the live rules file (mandatory)**

On manager .50:
```bash
sudo cp /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml.backup
```

- [ ] **Step 2: Add rule 100022**

Append inside the appropriate `<group>` in `/var/ossec/etc/rules/local_rules.xml`:
```xml
<group name="sysmon,windows,attack,">
  <rule id="100022" level="12">
    <if_group>sysmon_event1</if_group>
    <field name="win.eventdata.commandLine" type="pcre2">(?i)\-e(nc|ncodedcommand)?\s+[A-Za-z0-9+/=]{20,}</field>
    <description>Sysmon: PowerShell EncodedCommand execution (possible obfuscated payload) [T1059.001]</description>
    <mitre>
      <id>T1059.001</id>
    </mitre>
    <group>powershell,encodedcommand,</group>
  </rule>
</group>
```

- [ ] **Step 3: Validate the rule against the captured event**

On manager .50:
```bash
sudo /var/ossec/bin/wazuh-logtest -v < /tmp/sysmon_t1059_sample.json
```
Expected: output shows `Rule id: '100022'` matched, `Level: 12`. If it does not match, adjust the PCRE2 in Step 2 to the real `commandLine` value seen in `/tmp/sysmon_t1059_sample.json` and re-run --- do NOT proceed until it matches.

- [ ] **Step 4: Restart the manager and re-run the attack**

On manager .50:
```bash
sudo systemctl restart wazuh-manager && sudo systemctl is-active wazuh-manager
```
Expected: `active`. Then re-run the Task 4 Step 1 PowerShell command on .104.

- [ ] **Step 5: Confirm the alert fires**

Dashboard filter: `rule.id:100022`.
Expected: an alert, level 12, MITRE T1059.001, agent 007. Screenshot it.

- [ ] **Step 6: Run the Atomic Red Team equivalent for portfolio credibility**

On Windows .104, Administrator PowerShell (install ART once):
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
Install-AtomicRedTeam -getAtomics -Force
Import-Module "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force
Invoke-AtomicTest T1059.001 -ShowDetailsBrief
```
Pick a test that uses `-EncodedCommand` and run it:
```powershell
Invoke-AtomicTest T1059.001 -TestNumbers 1
```
Expected: rule 100022 fires again, this time sourced from the named ATT&CK test. Screenshot the dashboard showing the MITRE technique.

- [ ] **Step 7: Mirror the rule into the repo and fill in the GREEN section**

```bash
cd "/media/filwel/All/Sakib/Cyber Security Project"
# paste rule 100022 into rules/local_rules.xml to match the live file
git add rules/local_rules.xml incidents/phase8_t1059_powershell_encodedcommand_report.md
git commit -m "Phase 8: detect T1059.001 PowerShell EncodedCommand (rule 100022)"
```

---

## Task 6: T1003.001 --- LSASS credential dumping (RED then GREEN), rule 100023

**Files:**
- Modify on host: `/var/ossec/etc/rules/local_rules.xml` (manager .50)
- Modify in repo: `rules/local_rules.xml`
- Create in repo: `incidents/phase8_t1003_lsass_dump_report.md`

- [ ] **Step 1: Decide the Defender posture and record it**

The LSASS dump is a known-malicious pattern; Defender will likely block it. Two valid lab paths --- pick one and write it in the incident report:
- **(a) Observe the block (recommended):** leave Defender on. The dump may be quarantined; you then detect via BOTH the Sysmon Event 1 command line AND the Defender event. More realistic.
- **(b) Narrow exclusion:** allow the dump to complete so the Sysmon path is unambiguous:
  ```powershell
  Add-MpPreference -ExclusionPath "C:\Windows\Temp"
  ```
  Re-enable after the test:
  ```powershell
  Remove-MpPreference -ExclusionPath "C:\Windows\Temp"
  ```

- [ ] **Step 2: RED --- run the dump and confirm no CUSTOM alert yet**

On Windows .104, Administrator PowerShell:
```powershell
$lsass = (Get-Process lsass).Id
rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump $lsass C:\Windows\Temp\lsass.dmp full
```
Dashboard filter: `rule.id:100023`.
Expected: **no hit** (rule does not exist yet). Note whether the built-in Sysmon rules caught anything generic --- record it in the incident report as the RED state.

- [ ] **Step 3: Capture the raw event**

On manager .50:
```bash
sudo grep -m1 "comsvcs" /var/ossec/logs/archives/archives.json | sudo tee /tmp/sysmon_t1003_sample.json
```
Expected: a JSON line with `win.eventdata.commandLine` containing `comsvcs.dll` and `MiniDump`.

- [ ] **Step 4: Back up, then add rule 100023**

On manager .50:
```bash
sudo cp /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml.backup
```
Append:
```xml
<group name="sysmon,windows,attack,">
  <rule id="100023" level="13">
    <if_group>sysmon_event1</if_group>
    <field name="win.eventdata.commandLine" type="pcre2">(?i)comsvcs\.dll.{0,40}MiniDump</field>
    <description>Sysmon: LSASS memory dump via comsvcs.dll MiniDump (credential dumping) [T1003.001]</description>
    <mitre>
      <id>T1003.001</id>
    </mitre>
    <group>credential_dumping,lsass,</group>
  </rule>
</group>
```

- [ ] **Step 5: Validate against the captured event**

```bash
sudo /var/ossec/bin/wazuh-logtest -v < /tmp/sysmon_t1003_sample.json
```
Expected: `Rule id: '100023'`, `Level: 13`. Adjust the PCRE2 to the real command line if it does not match before proceeding.

- [ ] **Step 6: Restart manager, re-run, confirm GREEN**

```bash
sudo systemctl restart wazuh-manager && sudo systemctl is-active wazuh-manager
```
Re-run the Step 2 dump on .104. Dashboard filter `rule.id:100023`.
Expected: alert level 13, MITRE T1003.001, agent 007. Screenshot.

- [ ] **Step 7: Run the ART equivalent**

```powershell
Invoke-AtomicTest T1003.001 -ShowDetailsBrief
Invoke-AtomicTest T1003.001 -TestNumbers 1
```
Expected: rule 100023 (and/or the built-in LSASS-access rules) fire. Clean up any dump file:
```powershell
Remove-Item C:\Windows\Temp\lsass.dmp -ErrorAction SilentlyContinue
Invoke-AtomicTest T1003.001 -Cleanup
```

- [ ] **Step 8: Mirror to repo and commit**

```bash
cd "/media/filwel/All/Sakib/Cyber Security Project"
git add rules/local_rules.xml incidents/phase8_t1003_lsass_dump_report.md
git commit -m "Phase 8: detect T1003.001 LSASS dump via comsvcs (rule 100023)"
```

---

## Task 7: Documentation --- journal, playbook, phase README, portfolio

**Files:**
- Create: `docs/Detection_Engineering_Journal_2026-06-19.md`
- Create: `phases/phase5_playbooks/playbook_windows_credential_dumping.md`
- Create: `phases/phase8_windows_endpoint_detection/README.md`
- Modify: `PROJECT_STATUS.md`, `portfolio/README.md`

- [ ] **Step 1: Write the detection engineering journal entry**

Create `docs/Detection_Engineering_Journal_2026-06-19.md` documenting both RED/GREEN cycles: hypothesis, the gap proven, the rule written, the PCRE2 reasoning, validation output, and the false-positive consideration (e.g. legitimate admin use of EncodedCommand). Follow the prose style of the existing `docs/Detection_Engineering_Journal_2026-06-17.md`.

- [ ] **Step 2: Write the T1003.001 analyst playbook**

Create `phases/phase5_playbooks/playbook_windows_credential_dumping.md` matching the structure of `playbook_bruteforce_compromise.md`: trigger (rule 100023), triage steps, containment (isolate .104, rotate creds), MITRE mapping, escalation.

- [ ] **Step 3: Write the phase README**

Create `phases/phase8_windows_endpoint_detection/README.md`: what the phase proves (Windows endpoint now has telemetry + two detections), the Sysmon config used, rule IDs 100022-100023, and links to the two incident reports.

- [ ] **Step 4: Update PROJECT_STATUS.md and portfolio README**

Add a Phase 8 row/section to `PROJECT_STATUS.md` (status, date 2026-06-19, rules added). Add a "Windows Endpoint Detection" chapter to `portfolio/README.md` with the MITRE techniques and screenshots.

- [ ] **Step 5: Commit the documentation**

```bash
cd "/media/filwel/All/Sakib/Cyber Security Project"
git add docs/Detection_Engineering_Journal_2026-06-19.md \
        phases/phase5_playbooks/playbook_windows_credential_dumping.md \
        phases/phase8_windows_endpoint_detection/README.md \
        PROJECT_STATUS.md portfolio/README.md
git commit -m "Phase 8: document Windows endpoint detection (journal, playbook, portfolio)"
```

---

## Task 8: Verify, push, open PR

**Files:** none (process)

- [ ] **Step 1: Verify both rules are live and repo matches manager**

On manager .50:
```bash
sudo grep -E "100022|100023" /var/ossec/etc/rules/local_rules.xml
```
In repo:
```bash
cd "/media/filwel/All/Sakib/Cyber Security Project"
grep -E "100022|100023" rules/local_rules.xml
```
Expected: both IDs present in both places, identical rule bodies.

- [ ] **Step 2: Confirm no banned glyphs in any new file**

```bash
cd "/media/filwel/All/Sakib/Cyber Security Project"
grep -rc $'\xc2\xa7' phases/phase8_windows_endpoint_detection/ incidents/phase8_*.md docs/Detection_Engineering_Journal_2026-06-19.md
grep -rc $'\xc2\xb6' phases/phase8_windows_endpoint_detection/ incidents/phase8_*.md docs/Detection_Engineering_Journal_2026-06-19.md
```
Expected: 0 for every file.

- [ ] **Step 3: Push the branch and open a PR**

```bash
git push -u origin phase8-windows-endpoint-detection
gh pr create --title "Phase 8: Windows endpoint detection (Sysmon + T1059.001 + T1003.001)" \
  --body "Adds Sysmon telemetry to the Windows agent and two MITRE-tagged detections (rules 100022-100023), each proven with a RED/GREEN detection-TDD cycle and an Atomic Red Team test."
```
Expected: PR URL returned. Per project convention, merge via PR (zero open PRs left behind).

---

## Self-Review (completed during authoring)

- **Spec coverage:** Sysmon install (Task 2), Wazuh ruleset/collection (Tasks 3-4), T1059.001 (Tasks 1,5), T1003.001 (Task 6), portfolio chapter (Task 7) --- all covered.
- **Detuning for reality:** ART catalog test numbers can drift, so each technique has a deterministic generator command (EncodedCommand base64; comsvcs MiniDump) that always produces the exact telemetry the rule keys on. ART is run additionally for portfolio credibility.
- **Safety:** rules file backed up before every edit (Tasks 5,6); Defender handled explicitly (Task 6 Step 1); LSASS dump cleaned up (Task 6 Step 7).
- **Field-name consistency:** all rules use `win.eventdata.commandLine` and group `sysmon_event1`, matching the Wazuh Windows-eventchannel decoder. Task 5 Step 3 / Task 6 Step 5 force validation against a real captured event before trusting either rule.
