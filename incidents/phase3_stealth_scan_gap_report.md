# Incident Report — Phase 3: Stealth Scan Gap Test (`nmap -sS`)

**Report ID:** PH3-003
**Date:** _PENDING — fill on the day you run it_
**Analyst:** Nazmus Sakib
**Classification:** Lab exercise (authorized self-test) — reconnaissance / detection-gap measurement
**Status:** _DRAFT — structure ready; results sections marked `[RUN]` filled after the live attack_

> This test deliberately tries to EVADE detection. A confirmed miss here is the most valuable
> result in the lab — it is the empirical gap that justifies custom rules 100015/100016 AND the
> thesis's problem-space realizability argument. Record the miss honestly if it happens.

---

## 1. Summary

The PH3-001 nmap scan was detected mainly via its HTTP user-agent during `-sV` version probing.
This test removes that tell: a SYN-only stealth scan (`-sS`, no version detection) against the same
target, to measure how much detection coverage is lost when the scan goes quiet — and whether the
custom burst rule **100016** recovers it. `[RUN — one-line outcome: still detected / now missed]`

---

## 2. Environment

| Role | Host | IP | Notes |
|---|---|---|---|
| Attacker | Arch VM `zeno` | 192.168.1.106 | nmap |
| Target / Sensor | `rpi-sensor` (Raspberry Pi 4) | 192.168.1.104 | Suricata 6.0.1 on `wlan0` |
| SIEM | Wazuh manager (Docker 4.14.5) | 192.168.1.50 | `https://192.168.1.50` |

Same target as PH3-001 so the two are directly comparable.

---

## 3. Attack executed

From the attacker (`192.168.1.106`):

```
# Loud baseline (already done in PH3-001, re-run for a same-day A/B):
sudo nmap -sV -A 192.168.1.104

# Stealth variant — SYN scan, NO version/script probing (the gap test):
sudo nmap -sS -T2 192.168.1.104

# Even quieter (optional): slow timing + top ports only
sudo nmap -sS -T1 --top-ports 100 192.168.1.104
```

- `-sS` half-open SYN scan — never completes the handshake, no app-layer payload, so no HTTP
  user-agent for Suricata to match.
- `-T2`/`-T1` slow timing spreads packets out to stay under volume thresholds.

`[RUN — record: duration, ports found, timing template used]`

---

## 4. Detection (defender's view) — the A/B comparison

| Scan | Suricata signatures fired | Wazuh rule.id(s) + level | Detected? |
|---|---|---|---|
| `-sV -A` (loud) | ET SCAN Nmap UA (Pri 1) + anomalies | `[RUN]` | yes (PH3-001) |
| `-sS -T2` (stealth) | `[RUN]` | `[RUN]` | `[RUN — yes/partial/no]` |
| `-sS -T1` (quietest) | `[RUN]` | `[RUN]` | `[RUN]` |

Did custom rule **100016** (scan-burst composite) fire on the stealth scan? `[RUN — yes/no + why]`

`[RUN — paste fast.log lines for each variant; screenshot the dashboard delta to
portfolio/screenshots/phase4/]`

---

## 5. Honest assessment — the gap, quantified

`[RUN — state plainly: how many fewer alerts the stealth scan produced, whether it dropped below
Level 12, whether the burst rule recovered it. If -sS -T1 produced ZERO alerts, say so — that is
the headline finding.]`

Root cause (expected, confirm): host-local Wi-Fi sensor + signature reliance on app-layer tells →
a payload-free SYN scan has little for a signature engine to grab. A flow/threshold detector
(distinct-ports-per-source rate) is the right countermeasure, not another signature.

---

## 6. Recommendations / follow-up

1. If `-sS` evaded everything, tune rule **100016** thresholds (lower frequency / wider timeframe)
   and re-test — document the new floor.
2. Consider a Suricata flow/threshold rule (`threshold: type both, track by_src`) for port-sweep
   counting independent of app-layer.
3. Wired SPAN/TAP upgrade for passive multi-host visibility (Option B/C, Phase 7 runbook).

---

## 7. Reproducibility

- Attacker: the nmap commands in Section 3 from `192.168.1.106`.
- Observe (Pi): `sudo tail -f /var/log/suricata/fast.log`.
- Confirm (SIEM): Wazuh → Threat Hunting → `rule.groups:suricata`, Last 15 min, compare event counts.
- Screenshots: `portfolio/screenshots/phase4/`.

---

## 8. Thesis relevance

This is the realizability argument made concrete and measurable: the loud feature-rich scan is
trivially caught, the constrained on-wire stealth scan is not — exactly the feature-space vs
problem-space detection gap the thesis formalizes. The quantified miss is citable evidence. See
`docs/Realizability_Lab_Feasibility.md` and `docs/Signature_Project_Detection_Gap.md`.
