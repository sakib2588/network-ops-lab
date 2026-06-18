# Incident Report — Phase 3: Stealth Scan Gap Test (`nmap -sS`)

**Report ID:** PH3-003
**Date:** 2026-06-18
**Analyst:** Nazmus Sakib
**Classification:** Lab exercise (authorized self-test) — reconnaissance / detection-gap measurement
**Status:** COMPLETE — live-fired 2026-06-18, all results filled from real attack output

> This test deliberately tries to EVADE detection. A confirmed miss here is the most valuable
> result in the lab — it is the empirical gap that justifies custom rules 100015/100016 AND the
> thesis's problem-space realizability argument. Record the miss honestly if it happens.

---

## 1. Summary

The PH3-001 nmap scan was detected mainly via its HTTP user-agent during `-sV` version probing.
This test removes that tell: a SYN-only stealth scan (`-sS`, no version detection) against the same
target, to measure how much detection coverage is lost when the scan goes quiet — and whether the
custom burst rule **100016** recovers it.

**Outcome:** `-sS -T1` fully evaded Suricata and Wazuh. Zero alerts on the dashboard. Stealth scan
completed in 2196 seconds (36 min) and found all 5 open ports with no detection. This is the
headline gap finding.

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

Live run 2026-06-18: duration 2196.92s (36 min 36s), ports found: 22/tcp 53/tcp 80/tcp 443/tcp 5900/tcp, timing: -T1 paranoid.

---

## 4. Detection (defender's view) — the A/B comparison

| Scan | Suricata signatures fired | Wazuh rule.id(s) + level | Detected? |
|---|---|---|---|
| `-sV -A` (loud) | ET SCAN Nmap User-Agent (Pri 1) ×25 | 100015 (L12) + 100016 (L12) = 25 total | **YES** |
| `-sS -T1` (quietest) | **NONE** | **NONE** | **NO — full evasion** |

Did custom rule **100016** fire on the stealth scan? **NO.** Zero Suricata alerts, zero Wazuh alerts.
The burst rule never triggered because Suricata produced no input events for it to correlate.

Screenshots: `portfolio/screenshots/phase4/phase3_attack_A1_pi_fastlog_nmap_useragent_full.png` (loud),
`portfolio/screenshots/phase4/phase4_dashboard_100015_100016_fired_25hits_level12.png` (dashboard A/B).

---

## 5. Honest assessment — the gap, quantified

The loud scan (`-sV -A`) produced 25 Wazuh alerts at Level 12, MITRE T1046, from Suricata's
`ET SCAN Possible Nmap User-Agent Observed` signature firing on the HTTP probing in version
detection. The stealth scan (`-sS -T1`) produced **zero alerts** — a 100% detection drop.

Rule 100016 (scan burst) did NOT recover the gap. It requires Suricata to produce scan alerts first;
with no app-layer payload, Suricata had nothing to fire on.

Root cause confirmed: the Wi-Fi sensor relies entirely on signature matching of app-layer content.
A payload-free SYN scan has no HTTP user-agent, no version string, no banner — nothing for ET SCAN
to match. A flow/threshold detector (port sweep rate by source IP) is the correct countermeasure.

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
