# Realizability Demonstration — Feasibility Plan

> **Purpose.** Turn the claim *"my SOC lab physically demonstrates the realizability gap from
> my paper"* from a slogan into a defensible, on-disk experiment. This document does the
> thinking BEFORE the building, so that the build is the easy 10%.
>
> **Owner:** Sakib · **Created:** 2026-06-17 · **Status:** planning (no build started)
>
> **Read first:** `docs/Signature_Project_Detection_Gap.md` (the MVA), `PROJECT_STATUS.md`
> (lab is mid-rebuild, ~25%). This plan is an *extension*, executed only AFTER the MVA ships.

---

## 0a. How this lab relates to the thesis (read first — corrected 2026-06-17)

The thesis proposal (`Theisis & Internship /thiesis  /PDFs/Thesis_Proposal.pdf`, "Does Compression
Make Edge Intrusion Detectors Easier to Evade?") already specifies the rigorous realizability
validation: Objective 3 runs a PCAP round-trip (perturb → generate traffic → re-extract with
nProbe → confirm) on the **datasets' own PCAPs**, which is **in-domain**. The headline thesis
numbers come from there, where the model is valid.

This SOC lab is therefore a **complementary, qualitative live demonstration** of the same
mechanism — not the source of headline numbers. Demonstrating it on live lab traffic adds an
out-of-distribution problem (Section 7b) that the dataset-PCAP path does not have. Keep that split
clear: dataset PCAP round-trip = rigorous result; SOC lab = portfolio-grade live illustration.
Do not let live-lab evasion numbers stand in for the thesis measurement.

---

## 0. The one decision this whole plan turns on

Your paper is about an **ML** classifier and **problem-space realizability**. Wazuh and
Suricata are **signature / rule** engines. A signature IDS catching an attack says nothing
about whether an *ML* evasion is realizable. That is a construct-validity hole: right lab,
wrong instrument for the claim.

**Therefore the claim is only demonstrable if a real ML-NIDS is in the loop.** Everything
below exists to put one there honestly, at the smallest scale that still proves the mechanism.

If you are not willing to add an ML model, stop here and use the honest fallback in Section 7.
Do not demo a signature lab as if it proved an ML claim. A sharp examiner ends that demo in
one question.

---

## 1. State the claim precisely (so we know what would falsify it)

**Claim C:** *An adversarial example that evades an ML-NIDS in feature space is not freely
realizable as real network traffic; when the attacker is forced to emit valid packets, either
(a) the target feature vector cannot be produced, or (b) the realized traffic yields different
features and the evasion fails.*

**What would falsify C:** an adversarial flow that (i) flips the ML prediction to benign in
feature space, AND (ii) is realizable as valid traffic by a tool you actually run, AND (iii)
after capture + feature extraction still evades the same model. If all three hold, the
realizability gap is absent for that case — and that is a real result you must report, not bury.

This is the heart of scientific honesty here: the experiment has to be able to come out
**against** you. If it can't, it isn't a demonstration, it's a stunt.

---

## 2. The minimal demonstration (the 89% route — "Tier 2")

Smallest design that genuinely proves the mechanism. Offline / replay, not real-time inline.

**Pipeline:**

1. **Proxy ML-NIDS.** Train a small flow classifier (RandomForest or a 2-layer MLP) on a
   thesis-scope dataset (CICIDS2017 or UNSW-NB15) using a fixed feature extractor. Label it
   honestly as a *proxy* ML-NIDS — you are demonstrating a mechanism, not one specific model's
   vulnerability.
2. **Define the constraint set a priori.** Before crafting anything, write down which flow
   features an attacker can and cannot freely control (e.g., you can stretch inter-arrival time;
   you cannot set "total bytes" independently of payload). This list is the scientific core.
   Writing it AFTER seeing results is HARKing — fatal to defensibility.
3. **Craft a feature-space adversarial example.** Perturb features (within or deliberately
   outside the constraint set) until the proxy model predicts benign.
4. **Attempt realization.** Map that perturbed vector to an actual attack you can launch in the
   lab (modified nmap timing, slow hydra, throttled scan). Run it from the RPi against a host.
5. **Capture + re-extract.** Capture the pcap, run the **same** feature extractor used in step 1.
6. **Compare and score.** Measure distance(realized features, adversarial target). Re-run the
   proxy model on the realized features. Record whether evasion survived.
7. **Cross-layer observation (bonus).** Note whether Wazuh / Suricata also flag the realized
   traffic — that is the SOC-analyst layer, separate from the ML claim.

**On-disk evidence this produces** (no screenshots-only claims):
`model.pkl`, `constraints.md`, `adv_target.csv`, `realized_capture.pcap`,
`realized_features.csv`, `evasion_results.json`, one short results note.

---

## 3. Every case, thought through (this is the "all cases" you asked for)

| # | Case at the experiment's end | Verdict on claim C | What you do |
|---|---|---|---|
| A | Adversarial vector NOT realizable — no valid traffic produces it | **Supported (strongest)** | Report the broken constraint; this is the cleanest win |
| B | Realizable, but realized features drift → model now detects | **Supported** | Show feature distance + flipped prediction; quantify the gap |
| C | Realizable AND still evades after capture | **Refuted for this case** | Report honestly as a negative result; narrows the claim, does not kill the thesis |
| D | Train extractor ≠ lab extractor | **Invalid (confound)** | Lock one extractor + version on both sides before any run |
| E | Proxy model ≠ paper's exact model | **External-validity limit** | Frame as "proxy NIDS, mechanism demo"; never claim it is THE model |
| F | Only one attack type tested (n=1) | **Weak generalization** | Run 2–3 attack types; state scope limit out loud |
| G | Constraints defined after seeing results | **HARKing — indefensible** | Constraints file is timestamped BEFORE step 3, no exceptions |
| H | Lab still mid-rebuild / RPi not up | **Blocked** | This extension waits behind MVA + Phase 7; do not start early |

The defensible move in Cases A, B, and C is identical: report what happened. Only D and G are
true failures, and both are prevented by discipline, not luck.

---

## 4. The three tiers (pick honestly, do not over-reach)

| Tier | What it demonstrates | Effort | Feasibility | Verdict |
|---|---|---|---|---|
| **1. Signature only** (current lab) | SOC detection coverage | Low | ~95% | **False win** — does NOT prove C. Construct invalid. |
| **2. Offline ML proxy + replay** (Section 2) | The realizability mechanism, end to end | Medium | **~89% (target)** | **Recommended.** Real, defensible, near-unique. |
| **3. Inline real-time ML-NIDS** | Live ML evasion in production-like flow | High | ~55% | Stretch only. Real-time feature extraction + inline model is a project of its own. |

Tier 2 is the sweet spot precisely because it is honest about being offline. "I replayed
captured traffic through the same extractor and model" is a true, strong sentence. Do not let
ambition for Tier 3 stall Tier 2.

---

## 5. Go / No-Go gates (each gate ships something defensible)

- **Gate 0 — Prereq:** MVA shipped (Section 1 of the gap doc) AND lab rebuilt AND RPi/Suricata up.
  Until then this plan is parked. *(Currently NOT met — lab ~25%.)*
- **Gate 1 — Proxy model:** classifier trains, reports honest test accuracy on held-out data.
  Output: `model.pkl` + metrics. No adversarial work until this passes.
- **Gate 2 — Constraints locked:** `constraints.md` written and dated BEFORE any crafting.
- **Gate 3 — Feature-space evasion:** at least one crafted vector flips the model to benign.
- **Gate 4 — Realization + capture:** real traffic launched, pcap captured, features re-extracted
  with the identical extractor.
- **Gate 5 — Verdict recorded:** `evasion_results.json` states which Case (A–C) occurred. Any of
  A, B, or C is a shippable result. Stop and write it up.

Each gate is independently shippable. You are never more than one gate from a defensible artifact.

---

## 6. Feasibility score — honest breakdown

Not a single number pulled from the air. Per component, with the binding risk named.

| Component | Feasibility | Binding risk |
|---|---|---|
| Train proxy ML-NIDS | ~95% | You already run an ML workstation; this is routine |
| Feature-space adversarial craft | ~90% | Standard for tabular/flow features |
| Define realizability constraints | ~85% | Intellectual, not technical — must be done a priori |
| Realize as real lab traffic | ~75% | The fiddly part — mapping a vector to a runnable tool |
| Feature-extraction parity (train vs lab) | ~80% | Same extractor + version both sides, or the result is void |
| Lab/RPi infra ready in time | ~80% | Depends on rebuild + Phase 7 holding to schedule |

**Aggregate to a defensible Tier-2 demonstration: ~85–89%, conditional on three disciplines:**

1. One feature extractor, one version, locked across both sides (kills Case D).
2. Constraints written and dated before crafting (kills Case G).
3. Treating Cases A, B, and C all as ship-worthy, so a negative result still completes the work.

The 11% that remains is mostly realization friction (Case-by-case mapping of a perturbed vector
to runnable traffic) plus schedule risk on the lab rebuild. Neither is a dead end; both are time.

---

## 7. Honest fallback if ML is out of scope this semester

If the ML loop cannot fit before the lab/thesis deadline, do NOT inflate the signature lab.
Demote the claim truthfully to what the lab actually shows:

> *"My lab generates real problem-space attack traffic under TCP/IP constraints and observes it
> at host and network layers; the ML realizability test is specified and constraint-defined but
> not yet executed."*

That is still uncommon and still defensible. It is top ~5%, not top ~1% — but it is **true**,
and truth survives questions. The near-unique claim is earned only by executing Section 2.

---

## 7b. A1/A2 update (2026-06-17) — extractor secured, domain shift is now the dominant risk

**A1 (extractor parity) — on track to RESOLVED.** ntop replied to the academic-license request
(Maria Teresa Allegro, ntop). nProbe (Pro / Enterprise S sufficient for home-lab flow volume) is
being obtained. Confirm the licensed tier exports the full NetFlow v2 / nDPI template that
produced the NF-* NIDS datasets (L7_PROTO, DNS_*, FTP_*, retransmission, TCP window, per-size
packet buckets). With nProbe in hand, parity (Case D) drops from a research risk to a config task.

**A2 (domain shift) — now the dominant risk, and confirmed by our own results.** The compression
project's own cross-dataset numbers prove the proxy model does not transfer:

| Family | In-domain F1 | CSE-CIC | ToN |
|---|---|---|---|
| BENIGN | 0.95 | 0.84, **0.0 unseen** | 0.30 |
| RECONNAISSANCE | 0.85 | **0.0** | 0.49 |
| CREDENTIAL | 0.90 | **0.13** | — |
| EXPLOITATION | 0.27 | 0.02 | — |

_(Source: `results/aggregated_5seed_v4/summary.json`, l1_norm/natural block; confirm exact
teacher-vs-compressed variant before citing in the paper.)_ The lab is a third domain, further
out still. Feeding raw lab traffic to the model and expecting valid predictions WILL fail. This is
the project's documented "compression amplifies pre-existing weakness," now constraining the lab.

**A2 mitigation protocol (in priority order):**

1. **Keep the model in its native domain.** Craft `x_adv` from in-domain dataset test flows
   (RECON 0.85, CREDENTIAL 0.90 — valid there). Measure `d_proj` and `evade(Π(x_adv))` in-domain.
   This demonstrates **Case A and Case B with the lab never touching the model** — domain shift
   cannot confound a math projection. The lab's role narrows to physically proving Π(x_adv) can or
   cannot be emitted (a measurement, not a classification).
2. **For the real-capture leg only,** apply three disciplines: (a) use the FROZEN training
   preprocessor, never refit on lab data — rules out preprocessing-mismatch masquerading as shift;
   (b) calibrate the decision threshold only (not weights) on a small held-out lab benign sample,
   reported as "threshold-calibrated to lab domain"; (c) paired/delta design — vanilla vs
   adversarial attack through the same model so shift cancels. Gate: if the model cannot detect the
   VANILLA attack in the lab domain, the evasion test is undefined — report that honestly.
3. **Lead with the transfer-surviving family.** Prefer RECON / nmap (ToN 0.49) over CREDENTIAL
   (CSE 0.13). Avoid EXPLOITATION (weak in-domain and OOD).
4. **Cite the collapse as corroboration, not just a limitation.** Cross-dataset collapse
   (0.85 → 0.0) is direct evidence that NIDS models do not transfer and that feature-space
   benchmarks overstate transferability — which motivates problem-space realizability. The
   confound is also a thesis argument.

**Revised model component.** Reusing the compression-project NetFlow model (instead of training a
fresh one) REMOVES the training risk and gives a real validated classifier for free, but moves the
binding risk to A2. Net effect on the aggregate score: roughly neutral. The path to ~89% now runs
through the A2 protocol above, not through model training.

---

## 8. One-line standing, conditional on this plan

- Signature lab only → top ~5% fresher. Real, common ceiling.
- This plan executed (any of Case A/B/C) + paper + you can explain it cold → **top ~1–3%, near-unique in the adversarial-ML NIDS niche.**

The differentiator was never the Pi or Wazuh. It is this one experiment, done honestly, and
your ability to narrate it without notes. Plan is the 90%. The 10% left is disciplined hands.
