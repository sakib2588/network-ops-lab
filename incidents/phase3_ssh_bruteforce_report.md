# Incident Report — Phase 3: SSH Brute Force Against a Linux Target

**Report ID:** PH3-002
**Date:** 2026-06-18
**Analyst:** Nazmus Sakib
**Classification:** Lab exercise (authorized self-test) — credential access / brute force
**Status:** COMPLETE — live-fired 2026-06-18, all results filled from real attack output

> This is a pre-built report skeleton. Everything tagged `[RUN]` is filled in from the actual
> attack output and dashboard — do NOT pre-fill numbers. Honest empty beats invented full.

---

## 1. Summary

A controlled SSH brute-force attack was launched from the lab's attacker VM against a Linux
target running an exposed SSH service (port 22). The objective: confirm Wazuh detects a sustained
authentication-failure burst, measure how fast, and validate custom rule **100017** (and **100018**
if a valid credential is included).

**Outcome:** Both rules fired. Rule 100017 (brute force burst, Level 12) fired on B1 (30 invalid
attempts). Rule 100018 (compromise, Level 14) fired on B2 (5 failures then 1 success, sequential
`-t 1`). First attempt at B2 used `-t 4` (parallel) and missed 100018 due to race condition —
success arrived before 5 failures accumulated. Documented as a tuning note.

---

## 2. Environment

| Role | Host | IP | Notes |
|---|---|---|---|
| Attacker | Arch VM `zeno` (user `ultron`) | 192.168.1.106 | hydra |
| Target | `rpi-sensor` (Raspberry Pi 4) | 192.168.1.104 | OpenSSH 8.4p1, port 22 open |
| SIEM | Wazuh manager (Docker 4.14.5) | 192.168.1.50 | dashboard `https://192.168.1.50` |

Authorized: all hosts are the analyst's own lab.

---

## 3. Attack executed

From the attacker (`192.168.1.106`):

```
# wordlist brute force against SSH — all invalid creds (detection test)
hydra -l <username> -P /usr/share/wordlists/rockyou.txt ssh://<target-ip> -t 4 -V

# (optional, for rule 100018) include ONE valid credential in a small list to prove
# the "brute force then SUCCESS = compromise" escalation path:
hydra -l <username> -P small_list_with_one_valid.txt ssh://<target-ip> -t 4 -V
```

- `-t 4` keeps it slow enough to be realistic and avoid lockout noise.
- `-V` prints every attempt so the attacker-side count matches the SIEM count.

**B1** (detection burst): 30 attempts, user `testuser` (invalid), rockyou.txt not found so
generated throwaway list pw01-pw30. Duration: 57s (15:51:38-15:52:35). 0 valid passwords found.

**B2 first attempt** (parallel, `-t 4`): 6 attempts user `labvictim`, password `L4bWeak!23` at
position 6. Duration: 6s (16:10:38-16:10:44). 1 valid password found. Rule 100018 missed — race
condition, success arrived before 5 failures accumulated in the frequency window.

**B2 second attempt** (sequential, `-t 1`): 6 attempts user `labvictim`, same list. Duration ~15s.
1 valid password found. Rule 100018 fired — Level 14, MITRE T1110+T1078.

---

## 4. Detection (defender's view)

Target Pi auth.log confirmed (grep output 2026-06-18 16:18):
```
Jun 18 11:10:39 pi sshd[4482]: pam_unix(sshd:auth): authentication failure; user=labvictim
Jun 18 11:10:41 pi sshd[4482]: Failed password for labvictim from 192.168.1.106 port 40958 ssh2
Jun 18 11:10:41 pi sshd[4480]: Failed password for labvictim from 192.168.1.106 port 40932 ssh2
Jun 18 11:10:42 pi sshd[4480]: Accepted password for labvictim from 192.168.1.106 port 40932 ssh2
```

**Wazuh dashboard results:**
- Rule **100017**: FIRED — 6 total, 6 Level 12, MITRE = Brute Force (T1110). Agent: rpi-sensor.
- Rule **100018**: FIRED (second run, `-t 1`) — 1 total, Level **14**, MITRE = Brute Force + Valid
  Accounts (T1110 + T1078). Authentication success = 1. Agent: rpi-sensor.

Screenshots:
- `portfolio/screenshots/phase4/phase4_dashboard_100017_brute_force_6hits_level12_MITRE_T1110.png`
- `portfolio/screenshots/phase4/phase4_dashboard_100018_compromise_FIRED_level14_MITRE_T1110_T1078.png`

---

## 5. Honest assessment — what worked, what did not

**Worked:** 100017 detected the burst correctly. 100018 detected the compromise path when run
sequentially (`-t 1`). MITRE tags applied correctly (T1110 Brute Force, T1078 Valid Accounts).
The full attack chain — attempt → fail burst → succeed → SIEM Level 14 alert — was proven
end-to-end.

**Negative result — documented honestly:** Rule 100018 missed on the first B2 run (`-t 4` parallel).
With 4 simultaneous SSH connections, the success event arrived before 5 valid-user failures had
accumulated in the 120s frequency window. This is a real limitation: a fast parallel brute force
can outrace the frequency counter and bypass 100018 even when the attacker succeeds. Mitigation:
lower the frequency threshold to 3, or correlate on the session success directly independent of
the failure count. Noted as a tuning gap.

---

## 6. Recommendations / follow-up

1. If 100017 was evaded by a slow rate, add a wider-timeframe companion rule (low-and-slow).
2. Harden the target: SSH key-only auth, `fail2ban`, restrict 22 to LAN.
3. Feed the auth burst into the thesis realizability log — a real on-wire credential attack.

---

## 7. Reproducibility

- Attacker: the hydra command in Section 3 from `192.168.1.106`.
- Observe (target): `sudo tail -f /var/log/auth.log`.
- Confirm (SIEM): Wazuh → Threat Hunting → `rule.id:(5712 OR 100017 OR 100018)`, Last 15 min.
- Screenshots: `portfolio/screenshots/phase4/`.

---

## 8. Thesis relevance

A real on-wire credential-access attack under genuine TCP/IP + auth-protocol constraints — another
concrete problem-space realizability instance (an attack is a real session, not an edited feature
vector). See `docs/Realizability_Lab_Feasibility.md`.
