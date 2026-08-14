# Social / LinkedIn Posts - SOC Home Lab (in progress)

Ready-to-paste drafts for LinkedIn and similar sites. All ASCII so nothing breaks on paste.
No secrets, no real IPs. Honest framing: the project is IN PROGRESS, and the built-in tools
(Wazuh, Suricata) are credited. Add your own emoji/hashtags to taste.

---

## The phase roadmap (use this as the "project plan" graphic or list)

> **Updated 2026-08-14.** The table below was written in June and had gone stale; corrected
> against PROJECT_STATUS.md. POST 1 and POST 2 now undersell the lab badly -- POST 1 is a
> Docker disk-space story, which was the strongest material in June and is not any more.
> Prefer POST 3.

| Phase | Focus | Status |
|---|---|---|
| 0 | Environment setup (host, network) | Done |
| 1 | Wazuh deployment (SIEM server) | Done (rebuilt on Docker, 2026-06-17) |
| 2 | Log ingestion from agents | Done -- 4 agents across 4 OS (Pop!_OS, Arch, Debian/Pi, Windows) |
| 3 | Threat simulation (nmap, brute force, MITRE ATT&CK) | **Done 2026-06-18** -- full attack chain live-fired |
| 4 | Detection engineering (custom Wazuh rules) | **Done** -- 7 rules (100015-100021), all proven on dashboard |
| 5 | Investigation playbooks / incident reports | Done -- playbooks written, reports filled |
| 6 | Portfolio + public GitHub write-up | In progress -- 21 screenshots indexed |
| 7 | Raspberry Pi network sensor (Suricata NIDS) | Done 2026-06-17 |
| 8 | Windows endpoint detection (Sysmon + Atomic Red Team) | Planned |

Overall: ~90%.

Architecture in one line: host agents (Linux + Windows) report endpoint logs to a Wazuh
server, and a Raspberry Pi running Suricata adds network-layer visibility - two vantage
points, host and network.

---

## POST 1 - short progress update (LinkedIn)

Building a Security Operations Center (SOC) home lab from scratch on my own hardware, and
sharing the journey as I go.

Milestone this week: stood up the SIEM. I deployed Wazuh (Manager + Indexer + Dashboard) as a
Docker single-node stack on an always-on Linux laptop. Indexer healthy, dashboard live, and
the stack is set to survive reboots.

The interesting part was not the happy path - it was the troubleshooting. On a machine with a
nearly full system partition, Docker's image store quietly filled the disk and took the
dashboard down. Root cause: Docker's containerd image store does not follow the data-root
setting, so the images landed on the wrong partition. Fix: relocate the containerd store to a
roomy partition and symlink it back, no re-download needed.

Lesson I am taking forward: on constrained hardware, know exactly where every byte of your
container data lands before you deploy.

Next up: enrolling endpoint agents and starting threat simulation.

Tools used (credit where due): Wazuh, Docker, OpenSearch.

#cybersecurity #blueteam #SOC #SIEM #wazuh #homelab #learninginpublic

---

## POST 2 - longer "what I learned" version (LinkedIn / blog)

SOC home lab, progress log.

Goal: build a working SOC lab end to end - SIEM, endpoint agents, a network sensor, threat
simulation, custom detections, and incident reports - entirely on personal hardware, so I can
show the work, not just talk about it.

This week I rebuilt the SIEM. Here is the honest version.

What I deployed:
- Wazuh 4.x as a Docker single-node stack (Manager, Indexer, Dashboard) on an always-on Linux
  laptop that acts as the server.
- All container storage routed onto a dedicated partition with real free space.
- Indexer JVM heap pinned so OpenSearch would not starve the rest of the stack on a 12 GB box.
- The stack configured to restart automatically after a reboot.

Three problems I had to work through:
1. The system partition was nearly full. Cleared gigabytes of stale package cache to make room.
2. The dashboard kept crashing with "no space left on device" even though I had pointed Docker
   at a large partition. Root cause: Docker's containerd image store is separate from the
   data-root setting, so the images were still landing on the small partition. I moved the
   containerd store to the large partition and symlinked it.
3. Repeated crashes left a stale index migration lock, so the dashboard hung on startup.
   Cleared the empty index and let it rebuild.

What this milestone is, and what it is not: this is a deployment and hardening milestone. The
detection work (custom rules, attack simulation, incident reports) is the next chapters, and I
will credit Wazuh's and Suricata's built-in rulesets when I get there - my contribution will be
the tuning and the analysis, not the engines.

Next steps: enroll the endpoint agents, bring up a Raspberry Pi with Suricata for network-layer
detection, then start simulating attacks and writing detections for the gaps I find.

Following along is welcome. I will keep posting the rough edges, not just the wins.

#cybersecurity #blueteam #SOC #SIEM #wazuh #suricata #homelab #detectionengineering

---

## POST 3 - the detection-engineering post (RECOMMENDED, added 2026-08-14)

Why this one: "I built a SIEM lab" is a post hundreds of people make, and most are three VMs
on one laptop with no authored rules. The differentiator is the six documented failures in
`docs/Detection_Engineering_Journal_2026-06-17.md`. Almost nobody publishes the part where
their rules did not work.

Pair it with `portfolio/screenshots/phase4/phase4_dashboard_100015_100016_fired_25hits_level12.png`.

---

I wrote seven custom detection rules for my Wazuh SOC lab.

Every single one of them was wrong the first time.

Here is what the rule engine actually taught me, which no tutorial mentioned.

1. The field name you match on is not the field name you see.

My Suricata rules matched data.alert.signature and data.src_ip, copied from what the
dashboard displays. They fired nothing. wazuh-logtest showed the decoder exposes those at the
root: alert.signature, src_ip, no data prefix. The dotted path is how a field appears in the
final alert document, not how the decoder names it for matching. Two rules were silently dead
over one prefix.

2. A built-in correlation helper silently did nothing.

My scan-burst rule used same_source_ip and never fired, even with a dozen scan alerts from one
address. same_source_ip keys on a decoded field called srcip. Suricata emits src_ip, with an
underscore. No match, no error, no alert. same_field src_ip fixed it. A correlation that never
matches looks exactly like an attack that never happened.

3. I was watching for the wrong login failure.

My SSH brute-force rule chained off event 5716 and would not escalate after ten failed logins.
A failed password for a VALID user decodes to 5760; an invalid user is 5710. I had keyed on
neither. My hand-rolled frequency counter was also redundant - the engine already escalates a
5710 burst to 5712 and a 5760 burst to 5763. I rebuilt the rule to chain off those.

Being honest: that rule is tuning of a built-in detection, not a novel signature. That is in
the rule comment too.

4. One rule was shadowing another.

My VNC rule stopped a later rule from ever evaluating, because Wazuh stops at the first match.
Fixing it needed a seventh rule to handle the overlap. Rule order is not cosmetic.

Then I ran the whole attack chain live - loud nmap, stealth scan, SSH brute force, and the
follow-on techniques - and all seven fired on the dashboard, each with a RED/GREEN cycle:
confirm the rule does NOT fire before the attack, then confirm it does. Same discipline as
test-driven development, applied to detections.

Credit where due: Wazuh and Suricata provide the engines and the built-in rulesets. My
contribution is the tuning, the correlation logic and the analysis.

Lab: Wazuh SIEM across four operating systems on real hardware, plus a Raspberry Pi running
Suricata as a network sensor - host and network vantage points.

If you are building detections, keep a build journal of what did not work. Mine turned out to
be more useful than the rules.

#cybersecurity #blueteam #SOC #SIEM #wazuh #suricata #detectionengineering #homelab

---

## Posting tips

- Pair Post 1 with a screenshot of the Wazuh dashboard login or overview (blur any IPs).
- Never screenshot anything showing a password or a real internal IP.
- The phase table makes a clean carousel slide or a simple graphic.
- When the public GitHub repo is ready (Phase 6), link it from the post.
