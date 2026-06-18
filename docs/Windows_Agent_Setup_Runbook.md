# Windows Wazuh Agent — Setup Runbook (run ON the Windows 10 side)

**Goal:** enroll the Windows 10 install (the dual-boot side of `popos-mainpc`) as a Wazuh agent
named **`win10-mainpc`**, so the SOC lab has Windows endpoint coverage to match the 3 Linux agents.

**You run this entire file ON Windows**, after booting into the Windows 10 partition.
This file lives on the shared NTFS drive ("All"), so open it in Windows from something like
`D:\Sakib\Cyber Security Project\docs\Windows_Agent_Setup_Runbook.md` (drive letter may differ —
it's the big shared drive that also has the `Sakib` folder).

---

## 0. Facts you'll need

| Thing | Value |
|---|---|
| Wazuh manager IP | `192.168.1.50` |
| Manager version (agent must match or be lower) | `4.14.5` |
| Enrollment port (authd) | `1515` |
| Data port | `1514` |
| Agent name to use | `win10-mainpc` |
| Agent install dir (after install) | `C:\Program Files (x86)\ossec-agent\` |

**Before you start, confirm:**
- You booted into **Windows 10** (not Pop!_OS).
- You are on the **same LAN** (Wi-Fi/Ethernet) as the manager — test: open Command Prompt and run
  `ping 192.168.1.50` — you should get replies.
- You have **Administrator** rights (you'll right-click → "Run as administrator").

---

## 1. Download the agent (must be version 4.14.5)

Open a browser on Windows and download the MSI directly:

```
https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.5-1.msi
```

Save it to `Downloads`. **Do not** grab "latest" — it must be `4.14.5` (never newer than the
manager). If that exact link 404s, the version index is at `https://packages.wazuh.com/4.x/windows/`.

---

## 2. Install + auto-enroll (one command — recommended)

This silently installs AND registers the agent with the manager in one shot.

1. Press **Start**, type `cmd`, **right-click "Command Prompt" → "Run as administrator"**.
2. Go to your Downloads folder (adjust the username if needed):
   ```cmd
   cd %USERPROFILE%\Downloads
   ```
3. Run the installer with the deploy variables (all on **one line**):
   ```cmd
   msiexec.exe /i wazuh-agent-4.14.5-1.msi /q WAZUH_MANAGER="192.168.1.50" WAZUH_REGISTRATION_SERVER="192.168.1.50" WAZUH_AGENT_NAME="win10-mainpc"
   ```
   - `WAZUH_MANAGER` — where the agent reports (port 1514)
   - `WAZUH_REGISTRATION_SERVER` — where it auto-enrolls (port 1515)
   - `WAZUH_AGENT_NAME` — its name on the dashboard

   This returns to the prompt with no output when it succeeds (it's silent, `/q`).

> If your manager requires an enrollment password, add `WAZUH_REGISTRATION_PASSWORD="<pwd>"`.
> The lab's single-node default does NOT require one (the other 3 agents enrolled open on the LAN),
> so you can omit it. If enrollment is rejected in Section 5, that's the thing to revisit.

---

## 3. Start the agent service

```cmd
NET START Wazuh
```

Expected: `The Wazuh service was started successfully.`
(If it says "already started," that's fine.)

---

## 4. (Optional but recommended) Richer telemetry with Sysmon

The bare agent ships Windows Event logs. For real SOC visibility (process creation, network
connections, file hashes — the stuff detections key on), add **Sysmon**. Skip this if you just
want a basic "agent is alive" demo; do it if you want the Windows side to actually detect things.

1. Download Sysmon: `https://download.sysinternals.com/files/Sysmon.zip` — extract it.
2. Download a good config (SwiftOnSecurity's is the lab standard):
   `https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml`
   Save it next to `Sysmon64.exe` as `sysmonconfig.xml`.
3. In the **admin** Command Prompt, from the extracted folder:
   ```cmd
   Sysmon64.exe -accepteula -i sysmonconfig.xml
   ```
4. Tell the Wazuh agent to collect the Sysmon channel. Open this file in **Notepad (as admin)**:
   ```
   C:\Program Files (x86)\ossec-agent\ossec.conf
   ```
   Just **before** the closing `</ossec_config>` line, add:
   ```xml
   <localfile>
     <location>Microsoft-Windows-Sysmon/Operational</location>
     <log_format>eventchannel</log_format>
   </localfile>
   ```
   Save, then restart the agent:
   ```cmd
   NET STOP Wazuh && NET START Wazuh
   ```

---

## 5. Verify it worked

### On Windows
```cmd
sc query Wazuh
```
Look for `STATE: 4 RUNNING`.

Check the agent log for a successful connection:
```cmd
type "C:\Program Files (x86)\ossec-agent\ossec.log" | findstr /i "Connected Enrollment manager"
```
You want lines like `Connected to the server (192.168.1.50:1514)` and a successful enrollment.

### On the Wazuh dashboard (from any machine)
1. Browse to `https://192.168.1.50`, log in.
2. Go to **Agents** (or **Endpoints Summary**).
3. You should see **`win10-mainpc`** with status **Active** (green), OS = Windows.
4. Click it → confirm events are arriving (Security/System/Application event channels; plus
   Sysmon if you did Section 4).

---

## 6. Quick smoke test (prove a detection path)

From the Windows admin prompt, generate a noisy event:
```cmd
net user testsoc P@ssw0rd123 /add
net user testsoc /delete
```
On the dashboard, filter the agent `win10-mainpc` — you should see the account-creation /
deletion events. (This mirrors the identity-watch idea from the Linux 100019 rule.)

---

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| `ping 192.168.1.50` fails | Not on the lab LAN, or Windows firewall blocking ICMP. Check Wi-Fi/Ethernet, confirm you're on the same network as the manager. |
| Agent installs but stays "Never connected" / "Disconnected" | Enrollment didn't complete. Re-run enrollment manually (Section 7a). |
| Service won't start | Check `ossec.log` (Section 5) for the error. Usually a bad `ossec.conf` edit — recheck the XML you added in Section 4. |
| "Duplicate agent name" | A `win10-mainpc` already exists on the manager from a previous try. Remove it on the manager (`/var/ossec/bin/manage_agents`) or pick a new name. |
| Windows firewall blocks outbound | Allow outbound TCP 1514 and 1515 to 192.168.1.50. |

### 7a. Manual enrollment (if auto-enroll failed)
In the **admin** Command Prompt:
```cmd
cd "C:\Program Files (x86)\ossec-agent"
agent-auth.exe -m 192.168.1.50 -A win10-mainpc
NET STOP Wazuh && NET START Wazuh
```
`agent-auth.exe` should print `Valid key received`.

---

## 8. Done-when checklist

- [ ] `sc query Wazuh` shows RUNNING
- [ ] `ossec.log` shows `Connected to the server (192.168.1.50:1514)`
- [ ] `win10-mainpc` shows **Active** on the dashboard
- [ ] (optional) Sysmon installed + its channel shows events
- [ ] Smoke-test events (Section 6) visible under the agent
- [ ] Take a screenshot of the dashboard with `win10-mainpc` Active →
      save to `portfolio/screenshots/` (note: you're on Windows; copy it to the shared NTFS
      drive so it lands in the repo when you're back in Pop!_OS)

---

## 9. After you're back in Pop!_OS

Tell me it's done and I'll:
- Update `PROJECT_STATUS.md` (Windows agent ✅, 4 agents Active, lab → ~95%)
- Fold the screenshot into the portfolio
- Update the agent inventory + memory

This is the last big item before the SOC lab hits ~100% on the build side.
