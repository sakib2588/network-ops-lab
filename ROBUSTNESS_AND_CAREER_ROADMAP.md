# Project Robustness + Career Roadmap

**Owner:** Nazmus Sakib (AIUB 23-52638-2) | Target: SOC / Security / ML-Data Analyst internship in Bangladesh, positioned as "ML Security Researcher"
**Created:** 2026-06-18
**Basis:** Deep-research report (27 sources, 22 adversarially-verified claims) + current lab state (~70%: Wazuh 4.14.5 Docker SIEM, 3 agents, Suricata sensor on RPi, 6 MITRE-tagged rules deployed, Phase 3 in progress).

> **Core verdict (verified):** The lab already matches the Tier-1 SOC fresher profile BD employers screen for. The gap is **operational realism + packaging + credentials**, NOT capability. So: deepen and document — do not rebuild.

---

## 1. How to Make the Project More Robust (ranked by skill-signal-per-effort)

### Tier A — Do these first (highest return)

- [ ] **Finish Phase 3 as MITRE-mapped, reproducible attacks.** Complete the pending hydra SSH brute force (T1110) and stealth `-sS` scan gap test. For each: run attack -> confirm the matching custom rule fires in Wazuh -> validate with `wazuh-logtest` -> write a short incident report. This is the rehearsable core of every interview answer.
- [ ] **Add Atomic Red Team adversary emulation, mapped to MITRE ATT&CK.** Turn ad-hoc attacks into a detection-as-code validation loop: ATT&CK-mapped atomic test -> detection fires -> document technique ID + rule. Wazuh natively maps TTPs to events. *This is the single highest-ROI addition.*
- [ ] **Maintain an ATT&CK coverage matrix.** A simple table: technique ID | atomic test | does my rule detect it? (yes / partial / gap). Gaps are honest findings, not failures — they become your next detection-engineering work.

### Tier B — Strong differentiators (do after Tier A)

- [ ] **Threat-intel enrichment** (native to Wazuh, near-zero infra cost): integrate VirusTotal + AlienVault OTX + URLHaus + MISP to cross-reference hashes/IOCs from lab telemetry. **Caveat:** this is a standard documented feature — it only differentiates when paired with a *written triage workflow*, not merely "enabled."
- [ ] **OpenSearch Anomaly Detection (Random Cut Forest) layer.** Ships with Wazuh dashboard 4.8+ (compatible with your 4.14.5 stack); runs unsupervised RCF on Wazuh-indexed data in near-real-time. Adds an ML anomaly layer on top of signature detection — and is the bridge to the thesis (Section 2).
- [ ] **DFIR write-ups / investigation playbooks.** 2-4 quality, sanitized incident reports (no real IPs) beat a sprawling repo. Each: alert -> triage -> MITRE mapping -> root cause -> response -> lesson.

### Tier C — Realism polish (optional, after B)

- [ ] **Honeypot** (e.g. Cowrie) to capture real adversarial traffic — already noted in your thesis-connection log.
- [ ] **Basic SOAR / automation** (active response in Wazuh, or a small script) to show triage automation maturity.
- [ ] **Log-pipeline hygiene:** documented normalization, retention, and false-positive tuning notes.

> **Operational-realism gap to acknowledge honestly:** a home lab shows *analytical* activities but NOT live shift triage of 40-100 alerts/day or ticketing. Name this gap in interviews and frame the lab as proof you can do the analysis, not a claim of production SOC hours.

---

## 2. Weaponize the ML-Security Angle (your unfair advantage)

Few BD freshers can produce this. Build ONE continuous story: **build detections -> attack them -> harden them.**

- [ ] **Adversarial evasion demo against your own detections.** A peer-reviewed PLOS ONE study showed DCGAN-generated adversarial traffic on **CICIDS2017** (one of your thesis datasets) degraded a Decision Tree NIDS ~99% -> 94% and Logistic Regression -> 96%. Reproduce on *your own* data and show it evading a detection layer in the lab.
- [ ] **Frame with problem-space realizability** so it reads as research, not toy hacking. Most published adversarial-ML-on-NIDS work assumes unrealistic threat models (full detector knowledge); up to ~80% of feature-space adversarial examples are invalid under real constraints (Apruzzese et al., ACM DTRAP 2021). Your locked thesis framing (gray-box, problem-space realizability, adaptive co-evolution) is exactly the credible angle.

> **Honesty guardrail:** present GAN evasion as **accuracy degradation, not full bypass**. Reproduce numbers on your own datasets — do not cite the paper's figures as universal.

---

## 3. Certifications — Objective Status and Plan

**Current state: you hold NONE of the two BD-recognized security certs below.** You currently have the Google Cybersecurity Professional Certificate, EC-Council Network Defense Essentials, and Stanford Supervised ML Certificate — useful, but not the certs BD security-job postings explicitly name.

**Verified fact:** BD job postings (Sysnova, ABG, Grameenphone) actively list **CEH / CISSP / CompTIA Security+**. The claim "BD hiring prioritizes skills over certs" was **REFUTED** in research — in BD, the named certs matter for getting past the screen.

### CompTIA Security+ (do this FIRST)

- **What it is:** vendor-neutral, entry-level baseline security cert. The standard "you are screen-eligible" credential.
- **Objective cost:** exam voucher roughly USD 400+ (price changes — verify on CompTIA site before paying). Self-study is feasible with your background; no mandatory paid training.
- **Why first:** cheaper than CEH, broadly recognized, achievable by self-study before you graduate, directly answers the BD posting keyword "Security+".
- **Realistic timeline for you:** 4-8 weeks self-study given your existing networking + Linux + Google cert background.

### CEH (Certified Ethical Hacker) — second, when budget allows

- **What it is:** EC-Council offensive-security cert; heavily name-recognized in BD postings.
- **Objective cost:** materially more expensive than Security+ (exam voucher alone several hundred USD; with official training often USD 1,000-3,000+). Verify current EC-Council pricing.
- **Caution:** more red-team-flavored than your blue-team/SOC lab. Valuable for the BD keyword match, but Security+ is the higher-priority spend.

### Skip / defer

- **CISSP:** appears in BD cert lists but requires ~5 years experience — NOT a fresher target. Defer.
- **Free skill-builders (do in parallel, not as résumé centerpieces):** Splunk free self-paced eLearning (SOC Essentials, Intro to Threat Hunting, Intro to Detection Engineering, Defense Analyst, Intro to SOAR). *Note: free Splunk threat-hunting tier omits hands-on labs.* TryHackMe SOC Level 1 / BTL1 ROI in BD is **unverified** — treat as practice, not a headline credential.

> **Two refuted myths — do NOT plan around them:** (a) certs do NOT have a verified 15-20% salary premium in BD; (b) the "BDT 300k-450k/year" figure was unverified. Use the verified entry-level range: **~25,000-60,000 BDT/month.**

---

## 4. What Your Portfolio Looks Like AFTER You Get Security+

This is the concrete "before vs after" so you can see what the cert unlocks.

| Dimension | NOW (no Security+) | AFTER Security+ |
|---|---|---|
| Keyword screen (bdjobs / bank / MSSP HR filters) | Often filtered out — postings name "Security+/CEH" | Passes the automated/HR keyword screen |
| Credibility of the lab | "Self-taught hobby project" risk | Lab + cert = validated, screen-eligible fresher |
| Résumé headline | ML Security Researcher + lab + 2 papers | Same + **CompTIA Security+ Certified** (the line recruiters look for) |
| Interview positioning | Strong on substance, weak on the checkbox | Substance AND the checkbox — top-tier fresher profile |
| Cert stack shown | Google Cybersecurity, EC-Council NDE, Stanford ML | + Security+ (the one BD security postings actually ask for) |

**Portfolio one-liner after Security+:**
> "Final-Year CSE @ AIUB | ML Security Researcher | CompTIA Security+ | ICCIT 2026 + IEEE Access papers | Built a 3-node Wazuh+Suricata SOC lab with custom MITRE-mapped detections and an adversarial-ML evasion demo | Seeking SOC/Security/ML-Analyst internship"

**What still must accompany the cert (cert alone is not enough):**
- [ ] Public GitHub repo: architecture diagram, custom rules, sanitized incident reports, dashboard screenshots, attack-vs-detection results table.
- [ ] The adversarial-ML flagship demo (Section 2) with a short LinkedIn/blog write-up.
- [ ] 3-4 drilled STAR stories built around **log analysis** and **MITRE ATT&CK** — the two skills BD/global hiring managers test hardest.

---

## 5. NOTE — The Bank Hiring / Referral Reality (BD)

> You flagged: "someone I know told me banks only take an interview if you are recommended."

**Objective treatment:**

- **The signal is real, the absolute is overstated.** In Bangladesh, referrals/internal recommendations heavily influence hiring at banks and large institutions — this is widely reported. But "ONLY if recommended" is not literally true; structured intern programs, campus drives, and bdjobs postings do produce non-referred interviews. Treat referrals as a **major multiplier**, not the sole gate.
- **Strategic implication:** do NOT bet your internship solely on the bank track. The research-verified BD employer mix that hires freshers is broader: **MSSPs, telecom (Grameenphone/Robi/Banglalink), IT-services/software firms, and startups** — these are more merit/portfolio-driven and less referral-locked than banks.
- **How to build referral access objectively (not "knowing someone"):**
  - [ ] University channel: AIUB faculty + alumni in security/IT roles — a faculty intro is a legitimate referral. Your 2 papers make you a credible RA candidate too.
  - [ ] BD security community: BCSC (Bangladesh Cyber Security Community), BDSec, CTF communities, LinkedIn "open to hire" groups. Active participation -> people who can refer you.
  - [ ] LinkedIn: post your lab write-ups (Section 4); recruiters and practitioners who engage become warm referral paths.
  - [ ] Cold outreach with a portfolio link converts better than a blind bdjobs apply — most freshers never do it.
- **Bottom line:** target the merit-driven track (MSSP/telecom/software/startup) as the primary path where your lab + cert + papers win on substance; build referral access in parallel for the bank track rather than waiting on it.

---

## 6. Concrete Sequence to Sept 27, 2026 Deadline

1. **Now -> early July (before midterms Jul 19-25):** finish Phase 3 properly (hydra + stealth scan, MITRE-mapped, with incident reports). Add Atomic Red Team loop.
2. **In parallel:** start Security+ self-study (4-8 week target).
3. **Post-midterm (late July):** package the GitHub repo + build the adversarial-ML flagship demo + write 1-2 LinkedIn posts.
4. **August:** sit Security+ exam; drill STAR stories; begin applications through merit-driven channels with the finished repo link; build referral access via community + faculty.
5. **Throughout:** track every application; rotate Tier-1/Tier-2 targets from `planning/Internship/BD_Internship_Strategy.md`.

---

## Open Questions (research could not verify — your judgment needed)

- Exact BD intern intake calendars (bank/MSSP cycles) vs. your Sept 27 deadline.
- Whether BD employers value TryHackMe SOC L1 / BTL1 as strongly as CEH/Security+ (unverified).
- Whether the heavy "ML Security Researcher / 2 papers" framing risks reading as overqualified to an MSSP shift-hiring manager — consider TWO résumé variants (SOC-analyst-forward vs research-forward) and pick per target.
