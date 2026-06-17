# Phase 7 - Suricata Network Sensor on `rpi-sensor` (LIVE runbook)

**Authoritative, top-to-bottom runbook for the ACTUAL Pi in this lab.** Supersedes
`RPi_Suricata_Setup.md` for the install specifics (that file assumed Ubuntu Server + netplan +
the OISF PPA + an agent not yet installed - none of which match this Pi). Follow THIS file.

**This Pi, as it really is (verified 2026-06-17):**
- Raspberry Pi 4B, `aarch64`, **Raspberry Pi OS / Debian 11 (bullseye)**, kernel 6.1.21-v8+.
- IP `192.168.1.104`, SSH `pi@192.168.1.104`.
- **Wazuh agent 4.14.5 already installed, enrolled, Active** (`rpi-sensor`), shipping to the
  manager at `192.168.1.50:1514`. So Steps 1/2/4 of the old guide are DONE - skip them.
- Goal of this phase: add **Suricata** (network IDS) and forward its alerts into Wazuh, then
  prove an attack is detected at the network layer.

> **AS-BUILT (completed 2026-06-17):** this phase is DONE. Suricata 6.0.1 runs on **`wlan0`**
> (not eth0 - eth0 was `NO-CARRIER`, see Section 0 Option A), 50,685 ET Open rules loaded,
> `eve.json` forwarded into Wazuh, confirmed end-to-end on the dashboard. **The bug that cost the
> most time:** the Debian rule-path mismatch - `suricata-update` writes to
> `/var/lib/suricata/rules` but the stock `default-rule-path` is `/etc/suricata/rules`, so the
> engine loaded **0 rules** and never alerted despite perfect capture. Fix = point
> `default-rule-path` at `/var/lib/suricata/rules` and restart. Also: ignore the `testmynids`
> curl test (its rule is in `emerging-deleted.rules`, never loaded) - validate with a local rule.

---

## Section 0 - The ONE decision that decides if this sensor is real: vantage point

A network sensor can only alert on packets it can actually see. A Pi with **one** NIC plugged
into a normal (unmanaged) switch sees only: **its own traffic + broadcast/multicast**. It will
NOT see unicast traffic flowing between two *other* hosts (e.g. PC1 <-> PC2). This is the single
biggest reason a home Pi sensor "runs but never alerts." Pick a vantage point on purpose:

| Option | What it sees | Cost | Verdict for this lab |
|---|---|---|---|
| **A. Own-interface (default)** | traffic to/from the Pi itself | free, zero hardware | **Start here.** Phase 3 already runs nmap/hydra **from** the Pi - Suricata on `eth0` sees every scan it sends and every response. Fully demonstrates network detection end-to-end. |
| **B. Inline transparent bridge** | ALL traffic of whatever sits behind the Pi | +1 USB-Ethernet dongle (~few $) | Best realistic full-visibility upgrade: put the Pi between the router and one target, bridge the two NICs, Suricata on the bridge. Matches the architecture diagram in the old guide. Do this as the "v2" upgrade. |
| **C. Switch port mirror (SPAN)** | ALL LAN traffic, passively | needs a **managed** switch | Ideal passive SOC setup; only if you buy/own a managed switch. |
| **D. Network TAP** | one physical link, passively | TAP hardware (~$30-100) | Pro option, overkill for now. |

**Recommendation:** do **Option A now** (it needs nothing, and it proves the concept and feeds
Phase 3), and plan **Option B** later with a USB-Ethernet dongle when you want to watch a real
target's full traffic. Document honestly in the paper/portfolio that the headline demo uses A
(attacker-on-sensor) and that B/C/D are the passive-visibility upgrades - do NOT claim full
passive LAN visibility you do not have. (This honesty is itself a thesis-grade point: real
deployments are constrained by where you can physically place a sensor.)

---

## Section 1 - Pre-flight (run on the Pi, one short line at a time)

> Paste **one line at a time**. Long multi-line blocks get mangled on paste (learned the hard
> way on this lab). Each command below is a single line.

```
export TERM=xterm
```
```
ip -br a
```
Note the **wired** interface name (almost always `eth0`) and confirm the Pi's IP is on it. If the
Pi is on **Wi-Fi (`wlan0`)** instead, prefer moving it to wired Ethernet: Wi-Fi NICs often refuse
promiscuous/monitor mode and AF_PACKET capture is unreliable on them (Pitfall P3).

```
sudo systemctl is-active wazuh-agent
```
(should print `active` - the agent is already enrolled; we only add Suricata now.)

```
sudo apt update
```

---

## Section 2 - Install Suricata the **Debian** way (NOT the PPA)

The OISF `ppa:oisf/suricata-stable` is **Ubuntu-only** and will fail on Raspberry Pi OS (Pitfall
P1). Install from the Debian repo - Debian 11 ships Suricata 6.0.x, which is fine for this lab.

```
sudo apt install -y suricata suricata-update jq
```
```
suricata --version
```
(`jq` is for reading `eve.json` later. Expect Suricata 6.0.x.)

Stop the auto-started service while we configure it:
```
sudo systemctl stop suricata
```

---

## Section 3 - Configure Suricata

Two files matter: the main config and the Debian service default.

**3a. Main config** `/etc/suricata/suricata.yaml` - set HOME_NET, the capture interface, and turn
on `community-id` (lets Wazuh/Zeek/NetFlow records be correlated by a shared flow hash). Edit with
`sudo nano /etc/suricata/suricata.yaml` and set:

```yaml
vars:
  address-groups:
    HOME_NET: "[192.168.1.0/24]"     # this lab's LAN
    EXTERNAL_NET: "!$HOME_NET"

af-packet:
  - interface: eth0                  # the wired NIC from `ip -br a` (Section 1)
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes

outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      community-id: true             # <- add/enable this line
      types:
        - alert
        - flow
        - dns
        - http
        - tls
```

**3b. Service default** `/etc/default/suricata` - make the systemd service capture on the right
interface in AF_PACKET mode. Edit with `sudo nano /etc/default/suricata`:

```
LISTENMODE=af-packet
IFACE=eth0
```

(If your wired NIC was not `eth0`, use that name in BOTH 3a and 3b. Mismatch here = Suricata
listens on the wrong interface and never alerts - Pitfall P4.)

---

## Section 4 - Pull threat rules

```
sudo suricata-update
```
This downloads the **ET Open** ruleset (needs internet). It writes
`/var/lib/suricata/rules/suricata.rules`. If it errors on a source, list/enable sources with
`sudo suricata-update list-sources` (ET Open is the default and is enough here).

---

## Section 5 - Test config, then start

**Always test before starting** - a YAML typo otherwise crash-loops the service (Pitfall P5):
```
sudo suricata -T -c /etc/suricata/suricata.yaml -v
```
Look for `Configuration provided was successfully loaded. Exiting.` Then:
```
sudo systemctl enable --now suricata
```
```
sudo systemctl status suricata --no-pager
```
(should be `active (running)`; `enable` makes it survive reboot.)

---

## Section 6 - Validate Suricata actually detects (before wiring Wazuh)

Trigger a **known** alert with the standard OISF test (safe; fetches a harmless string that
matches a built-in rule):
```
curl -s http://testmynids.org/uid/index.html
```
Then check Suricata saw it:
```
sudo tail -n 5 /var/log/suricata/fast.log
```
Expect a line like `GPL ATTACK_RESPONSE id check returned root`. Also confirm structured output:
```
sudo tail -n 2 /var/log/suricata/eve.json | jq '.alert.signature // .event_type'
```
If `fast.log` stays empty: wrong interface (Section 3b), or own-interface vantage point with no
matching traffic (Section 0) - the `curl` test fixes the latter because the Pi itself makes the
request.

---

## Section 7 - Forward Suricata into Wazuh

Add the eve.json reader to the agent config. Use `sudo nano /var/ossec/etc/ossec.conf` and add,
inside an `<ossec_config>` block:

```xml
<ossec_config>
  <localfile>
    <log_format>json</log_format>
    <location>/var/log/suricata/eve.json</location>
  </localfile>
</ossec_config>
```
```
sudo systemctl restart wazuh-agent
```
Wazuh ships built-in Suricata decoders + rules (rule group 86600+), so alerts appear with no
extra server config. Verify on the dashboard: `https://192.168.1.50` -> Threat Hunting / Security
Events, filter `agent.name: rpi-sensor`. Re-run the `curl` test from Section 6 and watch the
alert land in Wazuh within a few seconds.

> Pitfall P6 (SD-card killer): `eve.json` grows fast. The Debian package installs a logrotate
> rule for `/var/log/suricata/` - confirm it exists (`ls /etc/logrotate.d/suricata`) and keep an
> eye on `df -h /`. A full SD card takes down BOTH Suricata and the Wazuh agent.

---

## Section 8 - Close the loop: attack -> detect (the Phase 3 deliverable)

This is the demo that proves the sensor works and produces portfolio screenshots.

From the Pi (Option A vantage point), scan another host and watch both layers fire:
```
sudo apt install -y nmap
```
```
sudo nmap -sS 192.168.1.50
```
(Use a real target IP on the LAN - the server `.50`, or a PC.) Then:
```
sudo tail -n 10 /var/log/suricata/fast.log
```
Expect ET SCAN / port-scan signatures. On the dashboard, filter `agent.name: rpi-sensor` and
screenshot the alert. Save screenshots to `portfolio/screenshots/rpi_phase7/`.

For the full Phase 3 set later: hydra SSH brute force, a few MITRE ATT&CK techniques, each
documented in `incidents/phase3_threat_sim_report.md`.

---

## Section 9 - Capture for the thesis / journal (do this while traffic is live)

The lab's research payoff is the **realizability bridge**: real packets -> NetFlow features ->
the compression NIDS model (the journal models reused as the proxy classifier). To feed that
later, capture raw packets now while you generate attack traffic:
```
sudo mkdir -p /var/log/lab_pcaps
```
```
sudo tcpdump -i eth0 -w /var/log/lab_pcaps/phase3_$(date +%H%M).pcap -G 300 -W 1
```
(300-second capture; run it, then generate the attacks in Section 8 in another SSH window.) These
PCAPs are the input to nProbe / NFStream NetFlow-v2 extraction -> the model-in-loop demo. Keep
the PCAP + the matching `eve.json` slice together; that pairing is your evidence that the same
real flow is seen by both Suricata (signatures) and the ML model (features).

**Thesis honesty notes to record:**
- Headline demo uses Option A (attacker-on-sensor); passive full-LAN visibility (B/C/D) is a
  hardware upgrade, not done yet - state this plainly.
- The ML measurement on these captures must stay **in-domain** per the project's OOD findings
  (live lab traffic is a further-out domain; do not feed raw lab flows to the model and quote
  headline numbers - see the realizability-bridge decision record).

---

## Section 10 - Edge cases & pitfalls (checklist)

| ID | Pitfall | Why it bites | Guardrail |
|---|---|---|---|
| P1 | Using the OISF **PPA** on Raspberry Pi OS | PPAs are Ubuntu-only; `add-apt-repository` fails on Debian | install from the Debian repo: `sudo apt install suricata` |
| P2 | **No visibility** - Suricata runs but never alerts | single-NIC Pi on an unmanaged switch sees only its own + broadcast traffic | choose a vantage point on purpose (Section 0); start with Option A |
| P3 | Capturing on **Wi-Fi** (`wlan0`) | Wi-Fi NICs often refuse promiscuous mode; AF_PACKET flaky | use wired `eth0` for the sensor |
| P4 | Interface name mismatch between `suricata.yaml` and `/etc/default/suricata` | service listens on the wrong NIC -> silent, no alerts | set the SAME interface in both files |
| P5 | Starting Suricata without `-T` test after editing YAML | one indentation typo crash-loops the service | always `sudo suricata -T -c ...` first |
| P6 | `eve.json` fills the SD card | high-volume JSON logging; SD cards are small | keep the logrotate rule; watch `df -h /` |
| P7 | Pi 4 CPU/RAM saturation under heavy rules | full ET ruleset + 4 GB Pi can drop packets | AF_PACKET cluster_flow (set); trim rule categories if `stats.log` shows drops |
| P8 | Undervoltage throttling | weak PSU under load throttles the CPU | `vcgencmd get_throttled` should return `0x0`; use the official PSU |
| P9 | Forwarding eve.json but seeing nothing in Wazuh | agent not restarted, or wrong path | restart `wazuh-agent`; confirm `/var/log/suricata/eve.json` exists and grows |
| P10 | Claiming full passive LAN detection | you only have Option A right now | document the vantage point honestly in the paper/portfolio |
| P11 | Time skew Pi vs manager | events misordered, correlation breaks | `timedatectl` - enable NTP (`sudo timedatectl set-ntp true`) |
| P12 | Reboot loses the sensor | service not enabled | `systemctl enable` both `suricata` and `wazuh-agent` (done above) |

---

## Section 11 - Completion checklist

- [ ] Vantage point chosen + recorded (Option A now)
- [ ] Suricata 6.x installed from Debian repo, `-T` config test passes
- [ ] HOME_NET + interface set in BOTH `suricata.yaml` and `/etc/default/suricata`
- [ ] ET Open rules pulled (`suricata-update`)
- [ ] `testmynids` alert seen in `fast.log` + `eve.json`
- [ ] eve.json forwarded; alert visible in Wazuh under `agent.name: rpi-sensor`
- [ ] nmap-from-Pi attack detected at network layer; screenshot saved
- [ ] PCAP captured for the NetFlow/model-in-loop bridge
- [ ] `suricata` + `wazuh-agent` both `enable`d (survive reboot)
- [ ] NTP on; `vcgencmd get_throttled` == `0x0`
- [ ] PROJECT_STATUS.md Phase 7 marked + screenshots in `portfolio/screenshots/rpi_phase7/`

---

## Section 12 - What this proves (and what it does not) - thesis/project tie-in

**Proves:** real TCP/IP packets, captured under genuine protocol constraints, drive both a
signature IDS (Suricata) and - via NetFlow extraction - the ML NIDS model. That is the
problem-space **realizability** crossing the thesis is built on: an attack must be a real packet
on the wire, not a feature vector edited in isolation. The host agents (auditd on the PCs) plus
this network sensor give the two-vantage (host + network) picture a real SOC has.

**Does not prove (be explicit):** full passive LAN visibility (only Option A so far); and it does
NOT license quoting ML evasion numbers from live lab captures - those stay in-domain per the
project's OOD-collapse findings. Keep the lab as the *qualitative live demonstration* of
realizability; keep the headline ML numbers on the datasets' own in-domain PCAPs.
