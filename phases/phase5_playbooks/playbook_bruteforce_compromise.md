# Investigation Playbook — SSH Brute Force and Compromise

**Playbook ID:** PB-002
**Rules covered:** 100017 (brute force burst), 100018 (brute force + success = compromise)
**MITRE:** T1110 (Brute Force), T1078 (Valid Accounts)
**Severity:** Level 12 (100017), Level 14 (100018)
**Author:** Nazmus Sakib
**Last updated:** 2026-06-18

---

## 1. When this playbook fires

| Rule | Meaning | Urgency |
|---|---|---|
| 100017 (Level 12) | Multiple SSH authentication failures from one source — brute force in progress | HIGH |
| 100018 (Level 14) | SSH success AFTER a failure burst from the same source — likely compromise | CRITICAL |

100018 is the most dangerous alert in this ruleset. It means an attacker found a valid credential.

---

## 2. Immediate triage — 100017 (brute force in progress)

**Step 1 — Identify source and scale:**
Wazuh → Threat Hunting → `rule.id:100017`
Note: `srcip`, target agent (`agent.name`), timestamp.

```bash
# On the target host — see live failure stream
sudo tail -f /var/log/auth.log | grep "Failed password"
```

**Step 2 — Is it still running?**
Check if failures are still arriving (refresh Wazuh every 30s). If yes, the attack is live.

**Step 3 — Block the source immediately (if unknown):**
```bash
# On rpi-sensor (blocks at network layer)
sudo iptables -A INPUT -s <attacker_ip> -j DROP
# Or on the target host directly
sudo ufw deny from <attacker_ip>
```

**Step 4 — Check if it succeeded (critical — did 100018 also fire?):**
Wazuh → Threat Hunting → `rule.id:100018`
If yes: jump to the Compromise section below.

---

## 3. Immediate triage — 100018 (compromise — CRITICAL)

**This is a P1 incident. Act within minutes.**

**Step 1 — Confirm the login happened:**
```bash
# On the target host
sudo grep "Accepted password" /var/log/auth.log | grep <attacker_ip>
sudo last | head -20   # see who logged in recently
```

**Step 2 — Is the session still active?**
```bash
sudo who
sudo ss -tnp | grep :22
```

**Step 3 — Kill the active session (if confirmed malicious):**
```bash
# Get the PID of the SSH session
sudo ss -tnp | grep <attacker_ip>
# Kill the sshd process for that connection
sudo kill -9 <pid>
```

**Step 4 — Lock the compromised account:**
```bash
sudo passwd -l <username>
# or
sudo usermod -L <username>
```

---

## 4. Investigation

**Reconstruct the timeline:**
```bash
# Full SSH event log for the attacker IP
sudo grep <attacker_ip> /var/log/auth.log | grep -E "Failed|Accepted|Invalid" | head -50

# Wazuh — all events from that source in last 24h
# Threat Hunting filter: srcip:<attacker_ip>
```

**Check what the attacker did after login:**
```bash
# Commands run in the session (if auditd is active)
sudo ausearch -ua <uid_of_compromised_user> -ts today | grep EXECVE

# Check bash history for the compromised user
sudo cat /home/<username>/.bash_history

# Check for new files, modified files
sudo find /home/<username> -newer /var/log/auth.log -ls 2>/dev/null
sudo find /tmp /var/tmp -newer /var/log/auth.log -ls 2>/dev/null
```

**Check for privilege escalation attempts:**
```bash
# Did the attacker try sudo?
sudo grep <username> /var/log/auth.log | grep sudo

# Any new cron jobs?
sudo crontab -l -u <username>
sudo ls -la /etc/cron* /var/spool/cron/

# New SSH keys planted?
sudo cat /home/<username>/.ssh/authorized_keys
```

**Check for lateral movement (did they scan from the Pi?):**
```bash
# Outbound connections from the compromised host
sudo ss -tnp
sudo netstat -tnp | grep ESTABLISHED
```

---

## 5. Known limitation — fast parallel brute force can bypass 100018

Confirmed during Phase 3 live-fire (2026-06-18):

- **hydra -t 1** (sequential): 100018 fires correctly — failures accumulate before success
- **hydra -t 4** (parallel): 100018 MISSED — with 4 simultaneous connections, the success event arrived before 5 valid-user failures had accumulated in the 120-second frequency window

**Implication:** a fast parallel brute force can succeed and NOT trigger 100018. Rule 100017 (brute force burst) will still fire, but without the Level-14 compromise escalation.

**Mitigation options:**
- Lower frequency threshold from 5 to 3 in rule 100018
- Add a rule that fires on `5715` (successful SSH login) from any IP that triggered `100017` in the last 10 minutes regardless of failure count
- Deploy `fail2ban` on SSH targets (blocks after N failures before success is possible)

---

## 6. Containment and recovery

| Action | Command |
|---|---|
| Block attacker IP on Pi | `sudo iptables -A INPUT -s <ip> -j DROP` |
| Lock compromised account | `sudo passwd -l <user>` |
| Kill active SSH session | `sudo kill -9 <sshd_pid>` |
| Rotate SSH host keys | `sudo ssh-keygen -f /etc/ssh/ssh_host_rsa_key` |
| Force password change | `sudo chage -d 0 <user>` |
| Review all SSH authorized_keys | `sudo find /home -name authorized_keys -exec cat {} \;` |

---

## 7. Evidence to collect

- Wazuh Threat Hunting screenshot: `rule.id:(100017 OR 100018)` — timestamps, srcip, agent
- `sudo grep <attacker_ip> /var/log/auth.log` output
- `sudo last` output showing login history
- `sudo ausearch -ua <uid> -ts today` output (if auditd active)
- `.bash_history` of compromised account

---

## 8. Escalation criteria

- 100018 fired — always escalate, always treat as confirmed compromise until proven otherwise
- Attacker ran `sudo`, `su`, `passwd`, or accessed `/etc/shadow` after login
- New SSH keys added to `authorized_keys`
- Outbound connections from the Pi to external IPs after the login
- Any new processes running as root under the compromised user's session

---

## 9. Lab-specific notes

- The throwaway account `labvictim` used in Phase 3 testing has been removed from `rpi-sensor` (confirmed 2026-06-18).
- In a real incident, the attacker's IP would likely be external (after traversing the router). In this lab, all attacker traffic originates from `zeno` (192.168.1.106) on the same LAN — an assumed-breach east-west model.
- Incident report from Phase 3 live-fire: `incidents/phase3_ssh_bruteforce_report.md`.
