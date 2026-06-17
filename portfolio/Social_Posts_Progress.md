# Social / LinkedIn Posts - SOC Home Lab (in progress)

Ready-to-paste drafts for LinkedIn and similar sites. All ASCII so nothing breaks on paste.
No secrets, no real IPs. Honest framing: the project is IN PROGRESS, and the built-in tools
(Wazuh, Suricata) are credited. Add your own emoji/hashtags to taste.

---

## The phase roadmap (use this as the "project plan" graphic or list)

| Phase | Focus | Status |
|---|---|---|
| 0 | Environment setup (host, network) | Done |
| 1 | Wazuh deployment (SIEM server) | Done (rebuilt on Docker, 2026-06-17) |
| 2 | Log ingestion from agents | In progress (server live, agents next) |
| 3 | Threat simulation (nmap, brute force, MITRE ATT&CK) | Planned |
| 4 | Detection engineering (custom Wazuh rules) | Planned |
| 5 | Investigation playbooks / incident reports | Planned |
| 6 | Portfolio + public GitHub write-up | Planned |
| 7 | Raspberry Pi network sensor (Suricata NIDS) | Planned |

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

## Posting tips

- Pair Post 1 with a screenshot of the Wazuh dashboard login or overview (blur any IPs).
- Never screenshot anything showing a password or a real internal IP.
- The phase table makes a clean carousel slide or a simple graphic.
- When the public GitHub repo is ready (Phase 6), link it from the post.
