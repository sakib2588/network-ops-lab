# Incident Report — Phase 3: SSH Brute Force Against a Linux Target

**Report ID:** PH3-002
**Date:** _PENDING — fill on the day you run it_
**Analyst:** Nazmus Sakib
**Classification:** Lab exercise (authorized self-test) — credential access / brute force
**Status:** _DRAFT — structure ready; results sections marked `[RUN]` are filled after the live attack_

> This is a pre-built report skeleton. Everything tagged `[RUN]` is filled in from the actual
> attack output and dashboard — do NOT pre-fill numbers. Honest empty beats invented full.

---

## 1. Summary

A controlled SSH brute-force attack was launched from the lab's attacker VM against a Linux
target running an exposed SSH service (port 22). The objective: confirm Wazuh detects a sustained
authentication-failure burst, measure how fast, and validate custom rule **100017** (and **100018**
if a valid credential is included). `[RUN — one-line outcome: detected / missed]`

---

## 2. Environment

| Role | Host | IP | Notes |
|---|---|---|---|
| Attacker | Arch VM `zeno` (user `ultron`) | 192.168.1.106 | hydra |
| Target | `[RUN — rpi-sensor .104 / zbook-arch .108]` | | SSH (OpenSSH) exposed on 22 |
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

`[RUN — record: number of attempts, duration, whether any succeeded]`

---

## 4. Detection (defender's view)

Target host (`/var/log/auth.log` or `journalctl -u ssh`):
`[RUN — paste 2-3 representative "Failed password" lines]`

**Wazuh dashboard (Threat Hunting):**
- Built-in rules expected: 5710 / 5716 (per-attempt failures), 5712 (stock brute-force composite).
- Custom rule **100017** expected: Level 12, "SSH brute force — 6+ failed logins in 120s".
- Custom rule **100018** (only if a valid cred was used): Level 14, "login SUCCEEDED after brute-force burst".

`[RUN — paste rule ids that fired, their levels, the event count + timestamp; screenshot to
portfolio/screenshots/phase4/]`

---

## 5. Honest assessment — what worked, what did not

**Worked:** `[RUN]`

**Limitations / negative results (record honestly):** `[RUN — e.g. did the slow -t 1 rate stay
under the frequency threshold and evade 100017? did key-only SSH make password brute force moot?
that is a finding, not a failure]`

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
