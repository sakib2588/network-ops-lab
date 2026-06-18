# Custom Suricata Rules — SOC Lab

**Maintainer:** Nazmus Sakib
**Sensor:** `rpi-sensor` (Raspberry Pi 4, 192.168.1.104)
**Rules file:** `/var/lib/suricata/rules/suricata.rules` (appended after ET Open ruleset)
**Last updated:** 2026-06-18

> These rules exist because ET Open gaps were discovered during Phase 3 live-fire testing.
> Each entry below documents why ET Open was insufficient and what the custom rule does.

---

## Why custom rules are needed

`suricata-update` pulls the ET Open ruleset (~50,000 signatures) but ET Open has **no VNC
signatures** — there is no built-in detection for connections to port 5900 (RFB protocol).
A bare TCP connection or a scan targeting VNC produces zero Suricata alerts by default.

This gap was discovered during Phase 3 live-fire on 2026-06-18 when `nmap -Pn -p 5900` from
the attacker VM produced no Suricata output and therefore no Wazuh alerts, even though Wazuh
rule 100020 was correctly deployed.

---

## Rules

### sid:9000020 — VNC connection attempt (RFB protocol)

```
alert tcp any any -> $HOME_NET 5900 (msg:"ET SCAN VNC Connection Attempt on Port 5900"; flow:to_server,established; content:"RFB "; depth:4; classtype:network-scan; sid:9000020; rev:1;)
```

**Why:** ET Open has no VNC signatures. Any TCP connection to port 5900 that completes the
handshake and sends the RFB protocol banner will match this rule. Without it, VNC access
attempts are completely invisible to Suricata.

**Detection logic:** matches the 4-byte `RFB ` banner that VNC servers send immediately on
connection (e.g. `RFB 003.008\n`). `flow:to_server,established` ensures it fires on
established connections in the client→server direction, not on SYN packets.

**Limitation:** a pure SYN scan (`nmap -sS -p 5900`) that never completes the handshake
will NOT match this rule (no `flow:established`). This is intentional — a half-open SYN
packet cannot carry the RFB banner. Rule 100021 in Wazuh handles that case by chaining off
the scan detection.

**Deployed:** 2026-06-18. Confirmed firing in `/var/log/suricata/fast.log`:
```
[1:9000020:1] ET SCAN VNC Connection Attempt on Port 5900 [Classification: Network Activity] [Priority: 3] ...
```

**Wazuh chain:** sid:9000020 → Suricata `eve.json` → Wazuh `86601` (generic Suricata alert)
→ Wazuh `100015` (ET SCAN escalation) → Wazuh `100021` (VNC on port 5900 during scan).

---

## Deployment procedure

The ET Open ruleset is managed by `suricata-update` and regenerated on update. Custom rules
must be appended AFTER the managed block or placed in a separate file that is included.

**Current approach (fixed 2026-06-18):** custom rules live in a dedicated file
`/var/lib/suricata/rules/local.rules`, referenced in `/etc/suricata/suricata.yaml` under
`rule-files:`. `suricata-update` only manages `suricata.rules` — it cannot touch `local.rules`.
The old append to `suricata.rules` was removed (was at line 66613, deleted via sed).

To reload rules without restarting Suricata:
```bash
sudo suricatasc -c reload-rules
```

To verify a rule is loaded:
```bash
sudo suricatasc -c ruleset-stats | grep 9000020
# or check fast.log after a test connection
```

---

## SID range

Custom lab rules use the range **9000000–9000099** to avoid collision with ET Open (1–3999999)
and Emerging Threats Pro (2000000+).
