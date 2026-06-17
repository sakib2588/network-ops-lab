# Next-Session Runbook — drive Phase 3 + Phase 4 to done (55% to 90%)

**For:** Nazmus Sakib, at the keyboard. Everything here is the part Claude can't do — the live
attacks on your physical lab. The rules, reports, and README are already written; this runbook
deploys and PROVES them. Work top to bottom. Each block ends with a screenshot to capture.

**Hosts:** attacker `zeno` .106 · sensor/target `rpi-sensor` .104 · agent `zbook-arch` .108 ·
SIEM `https://192.168.1.50`.

---

## 0. Housekeeping (2 min) — do first

Remove the noisy test rule on the Pi (it spams the SIEM):
```
# on the Pi (rpi-sensor)
sudo sed -i '/LOCAL PING TEST/d' /var/lib/suricata/rules/suricata.rules
sudo suricatasc -c reload-rules
```
Capture the PH3-001 nmap dashboard spike if you haven't → `portfolio/screenshots/rpi_phase3/`.

---

## 1. Deploy the custom rules (15 min) — Phase 4 core

On the **manager** (the Docker host laptop):
```
# back up FIRST — a syntax error stops the manager and kills the dashboard
docker exec -it single-node-wazuh.manager-1 \
  cp /var/ossec/etc/rules/local_rules.xml /var/ossec/etc/rules/local_rules.xml.bak

# copy the repo rules into the container (adjust path to where you cloned the repo)
docker cp rules/local_rules.xml single-node-wazuh.manager-1:/var/ossec/etc/rules/local_rules.xml
```

Validate parent ids + field names against REAL logs (do NOT trust the defaults blindly):
```
docker exec -it single-node-wazuh.manager-1 /var/ossec/bin/wazuh-logtest
# paste a real Suricata eve alert line, then a real sshd "Failed password" line.
# Read back the rule id it matched + the decoded field names. If they differ from the
# comments in local_rules.xml, fix <if_sid> / <field name> to match, re-copy, re-test.
```

Restart + confirm rules loaded:
```
docker exec -it single-node-wazuh.manager-1 /var/ossec/bin/wazuh-control restart
# wait ~30s, then check the manager log for "rules" errors:
docker exec -it single-node-wazuh.manager-1 tail -50 /var/ossec/logs/ossec.log | grep -i "error\|rule"
```
✅ Checkpoint: no rule-load errors. If errors → restore the .bak and re-check syntax.

---

## 2. Attack A — stealth scan gap test (20 min) → fills PH3-003

From **zeno** (.106):
```
# loud baseline for same-day A/B (already proven in PH3-001):
sudo nmap -sV -A 192.168.1.104

# the gap test — SYN-only, no version probing, slow timing:
sudo nmap -sS -T2 192.168.1.104
sudo nmap -sS -T1 --top-ports 100 192.168.1.104
```
Watch on the **Pi**: `sudo tail -f /var/log/suricata/fast.log`

Confirm on the **dashboard** → Threat Hunting → `rule.groups:suricata`, Last 15 min.
- Did custom rule `100015` (escalated scan, Level 12) fire on the loud scan? → it should.
- Did `100016` (burst) fire on the stealth scan? Did ANYTHING fire on `-sS -T1`?
- 📸 Screenshot the A/B delta → `portfolio/screenshots/phase4/`.
- 📝 Fill the `[RUN]` blanks in `incidents/phase3_stealth_scan_gap_report.md`.
  **A confirmed miss on `-sS -T1` is the headline finding — record it honestly.**

---

## 3. Attack B — SSH brute force (25 min) → fills PH3-002

Pick a target with SSH open (the Pi .104, or `zbook-arch` .108). From **zeno**:
```
# all-invalid run (detection test) — keep -t low so it's realistic:
hydra -l testuser -P /usr/share/wordlists/rockyou.txt ssh://192.168.1.104 -t 4 -V
# stop it with Ctrl-C after ~30-60 attempts; you only need the burst.

# OPTIONAL (proves rule 100018 = compromise path):
# make a tiny list where ONE line is a real local password, then:
hydra -l <realuser> -P small_list.txt ssh://192.168.1.104 -t 4 -V
```
Watch on the **target**: `sudo tail -f /var/log/auth.log`

Confirm on the **dashboard** → `rule.id:(5712 OR 100017 OR 100018)`, Last 15 min.
- `100017` (brute force, Level 12) should fire after 6 fails in 120s.
- `100018` (Level 14) fires ONLY if the optional run logged a success after the burst.
- 📸 Screenshot → `portfolio/screenshots/phase4/`.
- 📝 Fill the `[RUN]` blanks in `incidents/phase3_ssh_bruteforce_report.md`.

---

## 4. Attack C — sensitive-file access (5 min) → proves rule 100019

On any agent (`zbook-arch` or `popos-mainpc`), trip the auditd watch:
```
sudo cat /etc/shadow >/dev/null
sudo cat /etc/sudoers >/dev/null
```
Confirm → `rule.id:100019`, Level 12. 📸 Screenshot.
(If it doesn't fire: check the auditd watch has `-k identity` set so `audit.key` is decoded —
see the rule comment. Fix the key, re-run.)

---

## 5. Close out (15 min) — Phase 4 + 5 to done

- [ ] Fill the results table in `phases/phase4_detection_engineering/README.md` (which rules fired).
- [ ] Confirm all three incident reports have real numbers, no `[RUN]` left.
- [ ] Update `PROJECT_STATUS.md`: Phase 3 done, Phase 4 done, overall ~85-90%.
- [ ] Glyph audit before commit: `grep -rc $'\xc2\xa7' . ; grep -rc $'\xc2\xb6' .` → all 0.
- [ ] Commit (identity: sakib2588), push, open PR (main is branch-protected).

---

## What "90%" looks like after this runbook

| Lever | Before | After this runbook |
|---|---|---|
| Phase 3 attack chain | nmap only | nmap + stealth + brute force + file-access |
| Phase 4 custom rules | template | 6 rules deployed, validated, **proven firing** |
| Phase 5 reports | 1 | 3 (all with real evidence) |
| Phase 6 portfolio | stale README | current README + diagram + screenshots |

Remaining 10% = a reusable playbook or two, the public-repo final pass, and optional Cowrie
honeypot / Windows agent. Stretch, not blocker.
