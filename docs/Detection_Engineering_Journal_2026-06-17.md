# Build Journal: Phase 4 Rule Deploy + Validation (100015-100020)

**Date:** 2026-06-17
**Operator:** Nazmus Sakib
**Scope:** Deploying the six Phase 4 rules (committed in PR #9) to the live manager
(`single-node-wazuh.manager-1`, Wazuh 4.14.5) and validating each with `wazuh-logtest`.
This is the "validate -> trigger -> confirm" workflow from
`phases/phase4_detection_engineering/README.md`, server side. Live-fire on the dashboard
(real attacks) is Phase 3 and is NOT covered here.

> Redaction: manager address shown as `<SERVER_IP>` (private LAN, RFC1918).

---

## 1. Why this session existed

PR #9 added six rules to `rules/local_rules.xml`, each tracing to a measured Phase 3 gap.
They were written but never deployed or proven. The rule comments themselves flagged the risk:
*"the ids below are the Wazuh defaults but YOUR ruleset version is the source of truth -- confirm
with wazuh-logtest."* This session did exactly that, and the warning was justified: five of the
six rules needed a parent-id or field-name correction before they would fire.

The Phase 4 plan is explicit that detection engineering is **write -> validate -> trigger ->
confirm -> document**, and that field/parent names must be confirmed against the running ruleset
rather than trusted from a template. So correcting the drafts here is the plan working as intended,
not a deviation from it.

---

## 2. Method

For every rule: feed a realistic sample log to `wazuh-logtest`, read the parent rule id and the
decoded field names from the output, and reconcile the rule's `<if_sid>` / `<field>` against what
the engine actually produced. Deploy procedure followed the plan: back up the live file first,
`docker cp` the repo file in, parse-check, restart the manager.

---

## 3. Problems hit, and how each was fixed

### D1 - Suricata fields are root-level, not `data.*` (rules 100015, 100020 silent)
- **Symptom:** a realistic Suricata `eve.json` alert decoded fine and fired the built-in
  Suricata rule, but neither 100015 nor 100020 fired.
- **Cause:** the rules matched `data.alert.signature` / `data.dest_port` / `$(data.src_ip)`.
  `wazuh-logtest` showed the JSON decoder exposes those at the **root**: `alert.signature`,
  `dest_port`, `src_ip` -- no `data.` prefix. (`data.` is how fields appear in the final alert
  JSON sent to the indexer, not how the decoder names them for rule matching.)
- **Fix:** dropped the `data.` prefix in both the `<field>` names and the `$( )` description refs.
- **Lesson:** the field name you match on is the decoder's name (seen in logtest Phase 2), which
  is not always the dotted path you see in the dashboard alert document.

### D2 - A minimal JSON line fired no rule at all (test-data artifact)
- **Symptom:** an early stripped-down JSON test produced an empty Phase 3 -- not even the
  built-in Suricata rule fired -- which looked like a decoder failure.
- **Cause:** the test line omitted `timestamp`; the real `eve.json` always carries it. The engine
  did not treat the bare object as a full Suricata event.
- **Fix:** validate with realistic full `eve.json` lines (timestamp, flow_id, in_iface, full
  `alert` object), matching what the Pi sensor actually emits.
- **Lesson:** validate with logs shaped like production, not hand-trimmed minimal ones.

### D3 - Suricata correlation never matched (rule 100016)
- **Symptom:** 100016 (scan burst) would not fire even with a dozen scan alerts from one source.
- **Cause:** `<same_source_ip/>` keys on the decoded field `srcip`. Suricata events have `src_ip`
  (underscore) and no `srcip`, so the correlation key never matched.
- **Fix:** replaced `<same_source_ip/>` with `<same_field>src_ip</same_field>`. Fires on the 8th
  scan alert from the same source within 60s.
- **Lesson:** `same_source_ip` is sshd/firewall-shaped (`srcip`); for JSON/Suricata sources,
  correlate on the actual field name with `same_field`.

### D4 - SSH brute force would not escalate (rule 100017)
- **Symptom:** ten failed SSH logins from one source did not trip 100017.
- **Cause (two parts):** (a) the rule chained off `5716`, but a **valid-user** failed password
  decodes to **5760** (an **invalid** user is 5710); (b) the draft used
  `if_matched_group authentication_failed`, which did not accumulate a frequency count in this
  version. Meanwhile the built-in composites DID fire: a 5710 burst escalates to **5712**, a
  5760 burst to **5763**.
- **Fix:** rebuilt 100017 to chain off the built-in brute-force composites:
  `<if_sid>5712, 5763</if_sid>`. It now re-rates either built-in detection to Level 12 + MITRE
  T1110, regardless of valid/invalid user. (Honest framing: 100017 is **tuning** of a built-in,
  not a novel signature -- noted in the rule comment.)
- **Lesson:** chain severity-escalation rules off the engine's existing composite, not a hand-
  rolled frequency counter; and confirm the exact failure sid (5710 vs 5760) before keying on it.

### D5 - "Success after brute force" needed the right primitive (rule 100018)
- **Symptom:** the compromise rule did not fire on a success following a failure burst.
- **Cause:** correlating a one-shot composite is unreliable; the dependable primitive is the raw
  per-attempt failure. The only failures that can precede a **real** success are valid-user
  failures (5760) -- you cannot log in as a user that does not exist.
- **Fix:** `<if_sid>5715</if_sid>` + `<if_matched_sid>5760</if_matched_sid>` +
  `<same_source_ip/>` with `frequency="5" timeframe="120"`. Confirmed: 9 valid-user failures then
  a success from the same IP fires 100018 at Level 14.
- **Lesson:** for "success after brute," count the raw valid-user failures (5760), not the
  composite -- and that choice also makes the rule semantically correct (compromise needs a real
  account).

### D6 - auditd parent was wrong (rule 100019)
- **Symptom:** identity-file access did not escalate.
- **Cause:** the rule chained off `2902`; on this version a grouped SYSCALL+PATH auditd event
  decodes under **80700** ("Audit: Messages grouped"). The watch key is exposed as `audit.key`,
  and the accessed path as `audit.directory.name` (not `audit.file.name` for this event shape).
- **Fix:** parent `80700`, keep the `audit.key` pcre2 match (`identity|shadow|sudoers|passwd`),
  and point the description at the populated `audit.directory.name`.
- **Lesson:** auditd field/rule names are version- and event-shape-specific; confirm with a real
  SYSCALL+PATH pair that has a `-k` key set.

---

## 4. Verified end-state (logtest, 2026-06-17)

- All six rules (100015-100020) confirmed firing in `wazuh-logtest` with correct descriptions.
- Ruleset parses clean (`wazuh-logtest` loads with no errors); `xmllint` clean.
- Manager restarted; `wazuh-analysisd` and `wazuh-remoted` running.
- Live container `/var/ossec/etc/rules/local_rules.xml` is byte-identical to the repo copy.
- Previous live file backed up in-container (`.bak.prePR9`).

---

## 5. Phase 3 live-fire results (2026-06-18) — UPDATE

All rules proven firing end-to-end on the dashboard. Additional findings and fixes required:

### D7 - Rule 100020 (VNC) never fired — rule shadowing

- **Symptom:** nmap -p 5900 and nc VNC probe from `zeno` produced no 100020 alerts on the dashboard.
- **Root cause 1:** ET Open ruleset has no VNC signatures. A bare SYN/connection to port 5900
  with no application-layer content produces no Suricata alert, so the Wazuh chain never starts.
- **Fix 1:** Added custom Suricata rule `sid:9000020` to `/var/lib/suricata/rules/suricata.rules`
  on the Pi: `alert tcp any any -> $HOME_NET 5900 (msg:"ET SCAN VNC Connection Attempt on Port 5900";
  flow:to_server,established; content:"RFB "; depth:4; classtype:network-scan; sid:9000020; rev:1;)`
  Confirmed firing in `/var/log/suricata/fast.log`.
- **Root cause 2:** Rule 100020 uses `<if_sid>86601</if_sid>` — the same parent as 100015.
  When a scan hits port 5900, both 100015 and 100020 match, but Wazuh fires only one rule per
  event and 100015 wins (defined first). 100020 is permanently shadow-blocked for scan events.
- **Fix 2:** Added rule **100021** (`<if_sid>100015</if_sid>`, `dest_port:5900`) — chains off
  100015 so it fires on the second pass when a scan targets 5900 specifically.
  100020 is left in place for genuine non-scan VNC flows (it still fires for those).
- **Lesson:** when two rules share the same `<if_sid>`, the first defined always wins. Companion
  rules for sub-cases must chain off the winning rule, not off the shared parent.

### D8 - 100019 over-tuning (auditd passwd read flood)

- **Symptom:** 31,751 Level-12 alerts from rule 100019 during Phase 3 — effectively a self-DoS
  on the analyst's queue.
- **Cause:** `/etc/passwd` watch used `-p rwa`. Every `getpwnam()` call from sudo/login/PAM fires
  a read audit record. `/etc/passwd` is world-readable and read constantly by normal system activity.
- **Fix (2026-06-18):** Changed passwd watch to `-p wa` on `zbook-arch`
  (`/etc/audit/rules.d/identity.rules`). shadow/sudoers/gshadow remain `-p rwa` — reads of those
  ARE suspicious because those files are root-only.
- **Lesson:** do not add `-p r` to world-readable files. Only root-only credential files warrant
  read alerting.

---

## 6. Final proven end-state (2026-06-18)

| Rule | Description | Live-fire result |
|---|---|---|
| 100015 | Scan escalated Level 12 | FIRED — 25 alerts, MITRE T1046 |
| 100016 | Scan burst | FIRED (part of 100015 chain) |
| 100017 | SSH brute force | FIRED — 6 alerts Level 12, MITRE T1110 |
| 100018 | Brute force + success (compromise) | FIRED — Level 14, MITRE T1110+T1078 |
| 100019 | Identity file access | FIRED — 31,751 alerts (tuning fixed post-live) |
| 100020 | VNC exposed | SHADOW-BLOCKED — replaced by 100021 for scan events |
| 100021 | VNC targeted during scan | FIRED — Level 12, MITRE T1021.005 |

Negative results documented honestly in `incidents/` and `PROJECT_STATUS.md`.
