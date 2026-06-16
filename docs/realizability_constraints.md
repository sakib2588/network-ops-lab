# Problem-Space Realizability Constraints — NetFlow v2 Feature Set

> **FROZEN SPECIFICATION — a priori.** This file defines, *before any adversarial example is
> crafted*, which of the 41 NetFlow features an attacker can control when emitting real traffic,
> and the algebraic invariants a feature vector must satisfy to correspond to a packet sequence
> that can actually exist on a wire. Writing or editing these constraints AFTER observing results
> is HARKing and voids the demonstration. Treat this file as version-locked once Gate 2 passes.

| Field | Value |
|---|---|
| Version | 0.1 (DRAFT — not yet frozen) |
| Created | 2026-06-17 |
| Frozen on | _pending Gate 2_ |
| Frozen-by hash | _record `sha256sum` of this file here at freeze_ |
| Feature schema source | `ids-compression-benchmark/configs/canonical_schema.yaml` (41 ml_features) |
| Target model | NetFlow v2 IDS (compression-project teacher/student) — used as **proxy** target |
| Extractor of record | nProbe / NetFlow v2 (MUST match dataset extractor — see Assumption A1) |

---

## 1. Scope and threat model

**What this document is.** A formal mutability specification for problem-space adversarial NIDS
evasion. It answers one question per feature: *can an attacker emitting valid traffic set this
value freely, partially, or not at all?* The set of freely-settable dimensions, intersected with
the realizability invariants in Section 4, defines the **realizable manifold** onto which any
feature-space adversarial example must be projected to count as a real attack.

**Threat model (aligned to thesis).** Gray-box. The attacker knows the feature set and can query
or estimate the model, but emits traffic through a real TCP/IP stack against a real victim. The
attacker controls only their own host and their own packets. They do **not** control the victim's
responses, the network's loss/retransmission behaviour, or the flow exporter's derivations.

**What this is NOT.** Not a feature-importance ranking (that is `src/visualization/feature_importance.py`).
Not a claim about any specific model's robustness. It is the realizability boundary, which is a
property of the protocol and the measurement pipeline, not of the model.

---

## 2. Literature anchor

- Pierazzi, Pendlebury, Cortellazzi, Cavallaro (2020). *Intriguing Properties of Adversarial ML
  Attacks in the Problem Space.* IEEE S&P. — defines the problem-space / feature-space distinction,
  and the four problem-space constraints adopted below (available transformations, preserved
  semantics, robustness to preprocessing, plausibility).
- Ennaji et al. (2025). — thesis key paper on NIDS realizability. _[confirm full citation in refs]_
- Apruzzese et al., on realizable NIDS evasion. _[verify cite before use in writeup]_
- Sheatsley et al., on constrained feature spaces for NIDS. _[verify cite before use in writeup]_

Any citation marked _[verify cite]_ must be resolved through citation-management before it appears
in the paper. Do not carry an unverified citation into submitted text.

---

## 3. Mutability taxonomy

Each feature is assigned exactly one class. The class fixes whether and how the feature may move
during problem-space perturbation.

| Class | Name | Attacker control | Allowed perturbation |
|---|---|---|---|
| **D** | Directly controllable | Attacker sets it on their own host | Within protocol-valid range; often one-sided |
| **C** | Coupled / derived-from-action | Moves only as a consequence of a primary action (padding, delay), bounded by invariants | Constrained by Section 4 |
| **R** | Reactive | Set by the victim's response or by network conditions | None (not attacker-settable in crafting) |
| **I** | Immutable-for-function | Changing it changes or destroys the attack's identity | None (fixed by attack definition) |
| **X** | Protocol-inapplicable | Belongs to a protocol not present in this flow; near-constant (0 / NA) | None unless attack protocol changes |

The realizable degrees of freedom are the **D** features plus the **C** features moved only along
directions Section 4 permits. **R**, **I**, and **X** features are fixed during crafting.

---

## 4. Per-feature classification (all 41 ML features)

Direction key: `↑` increase-only realistic, `↕` bidirectional within bounds, `=` fixed, `~`
quantized/discrete.

| # | Feature | Class | Dir | Justification |
|---|---|---|---|---|
| 1 | L4_SRC_PORT | D | ↕ | Attacker can bind an ephemeral source port; realistically drawn from the high range, OS-assigned by default |
| 2 | L4_DST_PORT | I | = | Defines the targeted service (SSH=22). Changing it changes the attack or requires the service to exist elsewhere |
| 3 | PROTOCOL | I | = | An SSH brute force IS TCP. Switching to UDP/ICMP ceases to be the attack |
| 4 | L7_PROTO | C | = | Inferred by nDPI from actual payload. Cannot be set directly; changes only if the real application protocol changes |
| 5 | IN_BYTES | C | ↑ | Can be padded upward; cannot drop below the payload the attack functionally requires |
| 6 | IN_PKTS | C | ↑ | Extra packets can be injected; cannot drop below functional minimum |
| 7 | OUT_BYTES | R | = | Victim's response volume. Attacker influences only indirectly |
| 8 | OUT_PKTS | R | = | Victim's response packet count |
| 9 | TCP_FLAGS | C | ↕ | Cumulative flags must form a valid TCP state-machine sequence; arbitrary combinations are dropped or non-functional |
| 10 | CLIENT_TCP_FLAGS | C | ↕ | Attacker's own flags, but still bound to valid TCP behaviour |
| 11 | SERVER_TCP_FLAGS | R | = | Set by the victim's stack |
| 12 | FLOW_DURATION_MILLISECONDS | D | ↑ | Attacker can slow/delay to lengthen a flow; cannot compress below physical transmission time |
| 13 | DURATION_IN | D | ↑ | Same one-sided control over inbound timing |
| 14 | DURATION_OUT | R | = | Bound to victim response timing |
| 15 | MIN_TTL | D | ~ | Attacker chooses initial TTL (typically {32,64,128,255}); observed value = initial − hop count, so discrete, not continuous |
| 16 | MAX_TTL | D | ~ | Same hop-decrement quantization |
| 17 | LONGEST_FLOW_PKT | C | ↕ | Bounded above by MTU (~1514B); coupled to packet-size buckets |
| 18 | SHORTEST_FLOW_PKT | C | ↕ | Bounded below by protocol minimum frame; must be ≤ LONGEST |
| 19 | MIN_IP_PKT_LEN | C | ↕ | Bounded by IP/protocol minimum |
| 20 | MAX_IP_PKT_LEN | C | ↕ | Bounded above by MTU |
| 21 | SRC_TO_DST_SECOND_BYTES | C-derived | = | ≈ IN_BYTES / (DURATION_IN/1000). NOT independently settable (Invariant I1) |
| 22 | DST_TO_SRC_SECOND_BYTES | R-derived | = | Derived from victim traffic |
| 23 | SRC_TO_DST_AVG_THROUGHPUT | C-derived | = | Algebraic function of bytes and duration (I1) |
| 24 | DST_TO_SRC_AVG_THROUGHPUT | R-derived | = | Derived from victim traffic |
| 25 | RETRANSMITTED_IN_BYTES | R | = | Function of network loss, not attacker-set |
| 26 | RETRANSMITTED_IN_PKTS | R | = | Network loss conditions |
| 27 | RETRANSMITTED_OUT_BYTES | R | = | Network loss conditions |
| 28 | RETRANSMITTED_OUT_PKTS | R | = | Network loss conditions |
| 29 | NUM_PKTS_UP_TO_128_BYTES | C | ↑ | Padding/splitting can add packets to this bucket; bucket sums are constrained (I3) |
| 30 | NUM_PKTS_128_TO_256_BYTES | C | ↑ | Same |
| 31 | NUM_PKTS_256_TO_512_BYTES | C | ↑ | Same |
| 32 | NUM_PKTS_512_TO_1024_BYTES | C | ↑ | Same |
| 33 | NUM_PKTS_1024_TO_1514_BYTES | C | ↑ | Same; upper bucket bounded by MTU |
| 34 | TCP_WIN_MAX_IN | C | ↕ | Settable only with a custom/tuned TCP stack; default is OS-fixed |
| 35 | TCP_WIN_MAX_OUT | R | = | Victim's advertised window |
| 36 | ICMP_TYPE | X | = | 0/NA for a TCP flow; non-realizable without an actual ICMP flow |
| 37 | ICMP_IPV4_TYPE | X | = | Same |
| 38 | DNS_QUERY_ID | X | = | NA for non-DNS flow |
| 39 | DNS_QUERY_TYPE | X | = | NA for non-DNS flow |
| 40 | DNS_TTL_ANSWER | X | = | NA for non-DNS flow |
| 41 | FTP_COMMAND_RET_CODE | X | = | NA for non-FTP flow |

**Realizable degrees of freedom (summary).** Of 41 model dimensions, an attacker emitting a valid
single-protocol attack flow can move roughly **6 to 8**: source port, inbound timing/duration
(↑), inbound bytes/packets (↑) and their size-bucket distribution, initial TTL (quantized), and
TCP window (with a custom stack). Everything else is reactive, derived, immutable, or
protocol-inapplicable. This contraction from 41 free dimensions to ~7 one-sided, coupled
dimensions IS the realizability gap, made concrete.

---

## 5. Realizability invariants

A feature vector is realizable only if ALL of the following hold. A feature-space adversarial
example that violates any invariant does not correspond to traffic that can exist, and is evidence
**for** the realizability gap (Case A in the feasibility plan).

- **I1 — Throughput coupling.** `SRC_TO_DST_SECOND_BYTES ≈ IN_BYTES / (DURATION_IN / 1000)` and
  `SRC_TO_DST_AVG_THROUGHPUT` is the same algebraic function, within a tolerance ε. Throughput,
  bytes, and duration cannot be perturbed independently.
- **I2 — Packet/byte bound.** `IN_PKTS × min_frame ≤ IN_BYTES ≤ IN_PKTS × MTU`, with
  `min_frame ≈ 64B` (Ethernet) and `MTU ≈ 1514B`. Bytes and packets move together.
- **I3 — Histogram closure.** `Σ NUM_PKTS_*_BYTES buckets ≤ IN_PKTS + OUT_PKTS`. The per-size
  bucket counts must be consistent with the total packet count.
- **I4 — Packet-size ordering.** `proto_min ≤ SHORTEST_FLOW_PKT ≤ LONGEST_FLOW_PKT ≤ MAX_IP_PKT_LEN ≤ MTU`,
  and `MIN_IP_PKT_LEN ≤ MAX_IP_PKT_LEN`.
- **I5 — One-sided timing/volume.** Durations and packet/byte counts may only increase relative to
  the functional baseline of the attack (you can pad and delay; you cannot send fewer packets than
  the attack needs or finish faster than physics allows).
- **I6 — TTL quantization.** `observed_TTL = initial_TTL − hop_count`, `initial_TTL ∈ {32,64,128,255}`,
  `hop_count` fixed by topology. Observed TTL is discrete, not a free continuous value.
- **I7 — Reactive features fixed.** All **R**-class features (victim response and retransmission
  features) are held at their measured baseline during crafting; the attacker cannot set them.
- **I8 — Protocol exclusivity.** If `PROTOCOL = TCP`, then all **X**-class features (ICMP_*, DNS_*,
  FTP_*) remain at their inapplicable value. Cross-protocol feature fabrication is non-realizable.

---

## 6. Realizability projection and the gap metric

**Projection operator Π.** Given a feature-space adversarial vector `x_adv` (output of
`src/adversarial_robustness.py`), define `Π(x_adv)` as the nearest vector that (a) holds all R/I/X
features at baseline, (b) moves D/C features only along their permitted directions, and (c)
satisfies invariants I1–I8. `Π(x_adv)` is the closest *realizable* counterpart of the adversarial
target.

**Realizability gap metric.** Report, per crafted example:

1. `d_proj = ‖x_adv − Π(x_adv)‖` — how far the adversarial target sits from any realizable vector.
   Large `d_proj` means the attack lived in non-realizable space (Case A).
2. `evade(x_adv)` vs `evade(Π(x_adv))` — does the model still predict benign after projection?
   Loss of evasion under projection is Case B.
3. `evade(x_realized)` — after actually launching the projected attack and re-extracting features
   from the captured pcap, does evasion survive on **observed** features? Survival is Case C
   (claim refuted for this case; report honestly).

The triple `(d_proj, evade(Π(x_adv)), evade(x_realized))` is the experiment's primary outcome and
must be written to `evasion_results.json`. Designate `evade(x_realized)` as the primary endpoint
before running (it is the only one measured on real traffic).

---

## 7. Per-attack instantiation (fill BEFORE crafting, one block per attack)

Constraints are partly attack-specific. Instantiate this block for each attack and freeze it with
Section 4.

### Attack 1: SSH brute force (CREDENTIAL family) — TEMPLATE

- Tool + exact invocation: _e.g._ `hydra -l … -P … ssh://VICTIM` _(record full command)_
- Fixed-by-function (I-class for this attack): `PROTOCOL=6 (TCP)`, `L4_DST_PORT=22`
- Realizable DOF for this attack: source port, inter-attempt timing (↑ via `-t`/delays),
  packets/bytes via connection count, TTL (initial choice), TCP window (if custom stack)
- Expected non-realizable directions the model might exploit: independent throughput change (I1),
  reduced duration below physical (I5), fabricated DNS/ICMP features (I8)
- Baseline (clean) model prediction on a real run of this attack: _record before crafting_

### Attack 2: nmap scan (RECONNAISSANCE family) — TEMPLATE

- Tool + exact invocation: _e.g._ `nmap -sS -T2 VICTIM` _(record full command)_
- Fixed-by-function: `PROTOCOL=6 (TCP)` for SYN scan; destination port set varies by scan
- Realizable DOF: scan timing (`-T` template, ↑ duration), packet sizes, source port, TTL
- Expected non-realizable directions: same as I1/I5/I8 above
- Baseline (clean) model prediction: _record before crafting_

---

## 8. Assumptions to verify before freeze (do not skip)

- **A1 — Extractor parity.** Confirm the lab can produce the **identical** NetFlow v2 schema the
  dataset used (nProbe, ntop). If only a near-equivalent (nfstream, Zeek) is available, the gap is
  confounded and must be reported as a limitation, not hidden. This is the binding feasibility risk.
- **A2 — Clean-traffic baseline.** Confirm the model classifies *clean* lab traffic acceptably
  before introducing attacks. Heavy benign misclassification indicates domain shift and would
  confound any evasion measurement.
- **A3 — Family retention.** Confirm RECONNAISSANCE and CREDENTIAL survived the edge-filter and are
  classes the proxy model actually outputs.
- **A4 — Tolerances.** Fix ε for I1 and `min_frame`, `MTU`, `proto_min` constants for the lab
  network; record them here at freeze.

---

## 9. Integrity sign-off (anti-HARKing)

- [ ] Section 4 classification written before any adversarial example was crafted
- [ ] Invariants I1–I8 fixed before crafting
- [ ] Per-attack blocks (Section 7) instantiated and dated before crafting
- [ ] Primary endpoint (`evade(x_realized)`) designated before running
- [ ] This file's `sha256sum` recorded in the header at freeze; later edits logged with reason

> Reminder: any of Case A / B / C is a complete, shippable result. A refuted case (C) narrows the
> claim honestly and is a finding, not a failure. The only true failures are an unverified
> extractor (A1) or constraints written after the fact (Section 9).
