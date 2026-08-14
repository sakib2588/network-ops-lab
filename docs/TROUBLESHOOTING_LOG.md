# Troubleshooting Log - Wazuh SOC Home Lab

**One place for every problem hit in this lab, its root cause, and the fix.** Grouped by phase.
This is the running record - each new phase appends its problems here as they happen, so the log
stays complete instead of being backfilled. Detailed write-ups live in the per-phase docs; this
file is the index + the lesson.

**Entry format:** Symptom -> Root cause -> Fix -> Lesson.

**Why this file exists:** a clean happy-path proves nothing; the *diagnosis* is the skill. This log
is the portfolio evidence of methodical debugging, and the first place to grep when something
recurs.

---

## Phase 0-1: Server rebuild (Wazuh Docker single-node on Arch)

Full write-up: `docs/Server_Rebuild_Journal_2026-06-17.md` (incidents T1-T7). Summary:

| # | Symptom | Root cause | Fix |
|---|---|---|---|
| S1 | First image pull timed out mid-download | transient drop on a ~7 GB pull | resumable retry loop (`docker compose pull` x N, then `up -d`); read real output, not just exit code |
| S2 | Dashboard HTTP 503 right after start | startup race - dashboard boots before the indexer is listening (`ECONNREFUSED :9200`) | wait for indexer health, then restart dashboard. "Up" != "ready" |
| S3 | `/` hit 100%, dashboard died `exit 128: no space left` | **Docker 29 containerd image store lives in `/var/lib/containerd`; `data-root` does NOT relocate it** - ~10 GB landed back on the small `/` | stop docker+containerd, move `/var/lib/containerd` to `/home`, symlink back. Relocate BOTH roots on Docker 29+ |
| S4 | Dashboard hung on index migration forever | a crash mid-migration left a stale `.kibana_1` lock | delete the empty `.kibana*` index, restart (fresh installs only) |
| S5 | Server IP changed mid-build | the address was a DHCP lease, not fixed | static IP on the host (NetworkManager); router DHCP reservation is even better |
| S6 | Browser "connection refused" on the IP | hit during a rebuild window, and dashboard is HTTPS-only (443) - a bare IP tries port 80 | always use `https://<ip>`; wait for the rebuild |
| S7 | Dashboard "No API available to connect" | API password lives in TWO places (manager env AND dashboard `wazuh.yml`); only one was rotated | set the new password in EVERY copy, then recreate |

**Cross-cutting lesson:** on constrained hardware, know exactly where every byte of container data
lands before you deploy, and when you rotate a credential change it in every place it is stored.

---

## Phase 2: Agent enrollment (zbook-arch, popos-mainpc, rpi-sensor)

Full field notes: `docs/Agent_Enrollment_Handover.md` (Section 13). Summary of what bit:

### zbook-arch (HP ZBook, Arch)
| Symptom | Root cause | Fix |
|---|---|---|
| `yay` AUR build aborted at EOF | interactive prompts (cleanBuild/diff/edit) through a non-interactive wrapper | pre-answer: `yay -S --noconfirm --answerclean None --answerdiff None --answeredit None wazuh-agent` |
| Long `sudo sh -c '...'` mangled on paste | terminal inserted newlines mid-command -> `sed` got an empty script | put steps in a script file, run `sudo sh script.sh`; one root shell = one fingerprint prompt |
| `gdb-add-index ... No debugging symbols` spam | optional `wazuh-agent-debug` failing to index | harmless - ignore; the agent installs fine |

### popos-mainpc (Pop!_OS 24.04 main PC)
| Symptom | Root cause | Fix |
|---|---|---|
| Agent connected to `.50`, then a restart flipped it to `192.168.1.10` and connect/close-looped | stale OLD-VM-lab server IP lurking in `ossec.conf` | `sudo sed -i 's#<address>[^<]*</address>#<address>192.168.1.50</address>#g' ossec.conf`; confirm `<address>` after install AND first restart (P3/P5) |
| Every `sudo` failed: "a terminal is required to read the password" | non-interactive shells, `!`-prefixed commands and `pkexec` have no TTY or polkit agent | run all `sudo` in a real terminal window (paste with Ctrl+Shift+V) |
| `printf ... \| sudo tee` wrote as normal user -> "Permission denied"; `apt-get` + `update` split | long chained one-liners line-wrap-mangle on paste | single unbroken lines, or a script file |
| `apt` refused every operation: "Conflicting values ... Signed-By" | MEGA repo declared twice (`mega.list` AND `megaio.sources`) with different keys | disable one: `sudo mv .../mega.list .../mega.list.disabled`; `apt-get update` clean |
| Agent "Active but quiet" | no log sources configured (P10) | install `auditd` + add an audit `<localfile>` for `/var/log/audit/audit.log`; verify via `ss -tin \| grep .50:1514` byte growth |

---

## Phase 7: Raspberry Pi network sensor (Suricata) - the long one

Full as-built runbook: `phases/phase7_raspberry_pi/Phase7_Suricata_LIVE_Runbook.md`. This phase had
the most problems - every one below was hit live and fixed.

### Access / OS / housekeeping

**P7-1 - SSH by hostname failed.**
- Symptom: `ssh pi@raspberrypi.local` did not resolve.
- Cause: mDNS name not resolving on this network; the Pi was reachable only by IP.
- Fix: find the IP by MAC (Raspberry Pi prefix `dc:a6:32`) via an ARP sweep from the laptop ->
  `192.168.1.104`; `ssh pi@192.168.1.104`.
- Lesson: don't rely on `.local`; an ARP sweep filtered to the Pi OUI finds it every time.

**P7-2 - `clear` errored: `'xterm-kitty': unknown terminal type`.**
- Symptom: terminfo commands failed on the Pi after SSH.
- Cause: the laptop terminal is **kitty**, which exports `TERM=xterm-kitty`; the Pi has no kitty
  terminfo entry.
- Fix (permanent): `sudo apt install -y kitty-terminfo`. (Quick: `export TERM=xterm`, or append it
  to `~/.bashrc`.)
- Lesson: SSH carries your local `TERM`; the remote needs that terminfo or you downgrade to xterm.

**P7-3 - A Bun-based CLI tool crashed with `Bus error` on the Pi.**
- Symptom: SIGBUS at startup on the Pi.
- Cause: Bun bug on this Pi's arm64/glibc, sometimes after an `apt upgrade` changed shared libs.
- Fix: do not run heavy tooling on the Pi - it is the sensor. Drive everything from the laptop over SSH.
- Lesson: keep the brain on the workstation; the Pi is an appliance.

**P7-4 - `apt upgrade` looked stuck on Brave at 2%.**
- Symptom: unpack progress sat at 2% for minutes.
- Cause: large package + slow SD card; unpacking is I/O-bound, not frozen.
- Fix: wait; **never Ctrl-C `apt`/`dpkg` mid-unpack** (corrupts the package DB).
- Lesson: on a Pi/SD card, "slow" reads as "stuck" - it isn't. Let it finish.

**P7-5 - Root filesystem at 79% (3 GB free) on a logging sensor.**
- Symptom: `df -h /` = 79% used.
- Cause: desktop Pi OS image + Brave + apt cache + journal logs.
- Fix: `sudo apt clean` (download cache), `sudo apt autoremove --purge -y`, `sudo journalctl
  --vacuum-size=200M` -> dropped to ~69%. Optional: purge Brave / strip the desktop.
- Lesson: a sensor writes constantly; reclaim space + set logrotate BEFORE it fills (a full SD card
  kills Suricata AND the Wazuh agent - they share the card).

### Network vantage point

**P7-6 - eth0 `DOWN`, then `NO-CARRIER`, even with the jack LEDs lit.**
- Symptom: `ip -br a` showed `eth0 DOWN`; `ip link show eth0` = `<NO-CARRIER>`.
- Cause: layer-1 - no link partner negotiated (cable not seated / dead port). LEDs can light from
  PHY power without a real link.
- Fix: it is NOT a software/config/DHCP problem - DHCP is layer 3, it cannot fix no-carrier.
  Reseat the cable / try a live port later. For now, capture on **`wlan0`**.
- Lesson: `NO-CARRIER` = physical. Don't chase config; a GUI Wi-Fi setup did not cause it.

**P7-7 - "Network is unreachable" SSHing to the Pi after plugging the cable in.**
- Symptom: the laptop briefly could not reach `.104`.
- Cause: a switch renegotiation flap when the cable was plugged; the laptop's own route was fine
  (verified `.1`/`.50` reachable).
- Fix: wait a few seconds; re-scan. The Pi kept `.104` on `wlan0`.
- Lesson: plugging/unplugging links causes brief flaps; confirm which host actually lost the route
  before assuming the worst.

### Suricata install + detection (the core fight)

**P7-8 - which interface to monitor (visibility).**
- Symptom: a 1-NIC Pi on a normal switch only sees its own + broadcast traffic.
- Cause: no port mirror / TAP / inline placement; Wi-Fi can't go promiscuous.
- Fix: **Option A** - monitor the Pi's own `wlan0`; Phase 3 attacks are generated FROM the Pi, so
  Suricata sees them. Passive full-LAN sniffing is a later wired SPAN/TAP/inline upgrade.
- Lesson: a sensor only alerts on packets it can see - choose the vantage point on purpose.

**P7-9 - installing Suricata.**
- Symptom: the old guide's `add-apt-repository ppa:oisf/suricata-stable` would fail.
- Cause: PPAs are Ubuntu-only; this Pi is Raspberry Pi OS / Debian.
- Fix: `sudo apt install -y suricata suricata-update` from the Debian repo (gives 6.0.1).
- Lesson: don't copy Ubuntu instructions onto Debian/Pi OS verbatim.

**P7-10 - THE BIG ONE: Suricata captured perfectly but fired ZERO alerts.**
- Symptom: `fast.log` empty, no alert in `eve.json`, even with a guaranteed `alert icmp any any ->
  any any` rule and `reload-rules` returning OK.
- Diagnosis path: `suricatasc -c "iface-stat wlan0"` -> pkts rising, **0 drops** (capture fine);
  then the stats event in `eve.json` showed `"detect":{...,"rules_loaded":0,...,"alert":0}` ->
  **0 rules loaded**.
- Root cause: **Debian rule-path mismatch.** `suricata-update` writes the ruleset to
  `/var/lib/suricata/rules/suricata.rules`, but the stock `suricata.yaml` has
  `default-rule-path: /etc/suricata/rules` (empty). They never met -> engine ran with no rules.
  (The local test rule had been appended to the file Suricata wasn't reading, too.)
- Fix: `sudo sed -i 's|^default-rule-path:.*|default-rule-path: /var/lib/suricata/rules|'
  /etc/suricata/suricata.yaml` then restart; confirm `... 50685 rules successfully loaded` (not 0)
  in `suricata.log`.
- Lesson: "running + capturing" != "detecting". Always check `rules_loaded` in the stats, not just
  that the service is up.

**P7-11 - the `testmynids` curl test never alerted (false negative).**
- Symptom: `curl http://testmynids.org/uid/index.html` returned the bait but no alert.
- Cause: its rule (sid 2100498) lives in `emerging-deleted.rules`, which `suricata-update` skips
  ("Ignoring file rules/emerging-deleted.rules").
- Fix: validate with a **local rule** instead: `alert icmp any any -> any any (msg:"LOCAL PING
  TEST"; sid:9000001; rev:1;)`, reload, `ping`. **Remove it after** - it alerts on every ping and
  spams the SIEM (`sudo sed -i '/LOCAL PING TEST/d' .../suricata.rules`).
- Lesson: the famous test depends on a rule that modern ET Open no longer ships - a green Suricata
  can still "fail" it. Use a rule you know is loaded.

**P7-12 - checksum-offload was a red herring.**
- Symptom: suspected the Pi's own outbound packets had bad checksums so Suricata skipped them.
- Cause: actually fine - `iface-stat` showed `invalid-checksums: 0`; the real cause was P7-10.
- Fix: none needed; fixing the rule path made alerts fire.
- Lesson: confirm with data (the checksum counter) before applying a checksum fix; don't change two
  things at once.

**P7-13 - `suricatasc -c iface-stat wlan0` -> "Unable to connect to socket wlan0".**
- Symptom: looked like a socket failure.
- Cause: wrong syntax - the command + interface must be one quoted argument.
- Fix: `sudo suricatasc -c "iface-stat wlan0"`.
- Lesson: read the error literally - it treated `wlan0` as a socket path, a quoting bug, not a
  Suricata fault.

**P7-14 - a long `jq` one-liner errored on paste.**
- Symptom: `jq: syntax error ... at <top-level>` with `detect` split into `dete ct`.
- Cause: the terminal line-wrapped the long quoted filter, inserting a space.
- Fix: use a short, paste-proof `grep -o '"alert":[0-9]*'` instead.
- Lesson: this terminal mangles long pasted lines repeatedly - keep commands short and single-line.

### Forwarding into Wazuh

**P7-15 - Suricata alerts not reaching the dashboard.**
- Symptom: `grep -n 'eve.json' /var/ossec/etc/ossec.conf` returned nothing.
- Cause: the eve.json `<localfile>` forward step had not been saved.
- Fix: append the block with a single-line `printf ... | sudo tee -a ossec.conf` (avoids
  paste-mangling), restart `wazuh-agent`, confirm `Analyzing file: '/var/log/suricata/eve.json'` in
  `ossec.log`.
- Lesson: verify config on disk (`grep`) before assuming a step took; the pipeline has many hops.

**P7-16 - confirming end-to-end on the dashboard.**
- Symptom: needed proof alerts arrive, not just that plumbing exists.
- Fix: Threat Hunting -> filter `data.alert.signature:"LOCAL PING TEST"` (or `rule.groups:suricata`
  / `agent.name:rpi-sensor`), Last 15 min; the count climbed live (8 -> 11) as new pings fired.
- Lesson: a rising count under a fresh filter is the real "it works", not a single static hit.

---

## Phase 3 prep: Attacker VM (minimal Arch on VirtualBox)

Full setup: `phases/phase3_threat_simulation/Attacker_VM_and_Phase3_Kickoff.md`. Built 2026-06-17
(Arch VM `zeno` / user `ultron` / `192.168.1.106`). Pitfalls hit:

**A1 - Clipboard paste dead in the VirtualBox console.**
- Symptom: cannot paste commands into the VM's text console.
- Cause: no Guest Additions + it is a raw TTY (no GUI); VBox clipboard sharing only works into a
  graphical session.
- Fix: do not fight it - get SSH up and drive the VM from the laptop terminal (paste works there).

**A2 - VM got a NAT IP `10.0.2.15`, unreachable from the laptop.**
- Symptom: `ip -br a` in the VM showed `10.0.2.15/24`; laptop SSH could not reach it.
- Cause: Adapter 1 was on NAT (10.0.2.x is VBox's NAT range), not Bridged.
- Fix: power off, Settings -> Network -> Adapter 1 -> **Bridged Adapter -> enp6s0** (the laptop's
  active interface) -> the VM got `192.168.1.106` on the real LAN.
- Lesson: an attacker needs to be a real LAN citizen - always Bridged, never NAT.

**A3 - Minimal Arch profile ships no SSH.**
- Symptom: `systemctl enable --now sshd` after install - service exists only if openssh is present.
- Cause: the Minimal profile omits openssh/sudo/editor (the Server profile would include sshd).
- Fix: `sudo pacman -S openssh` then `sudo systemctl enable --now sshd` (installing the package does
  not start the service).

**A4 - sshd `active` but port 22 still closed from outside.**
- Symptom: `systemctl is-active sshd` = active, sshd listening on `0.0.0.0:22`, yet the laptop's
  `ssh` was refused and a TCP probe showed 22 closed.
- Cause: **ufw** was enabled and blocking inbound 22 by default.
- Fix: `sudo ufw allow ssh` (then `ss -tlnp | grep :22` confirms the listener; external probe opens).
- Lesson: "service active + listening" still fails if a host firewall drops the port - check ufw.

**A5 - bridging to the wrong NIC = no network.**
- Cause: bridging to an interface that is not the host's active connection.
- Fix: `ip -br a` on the laptop -> bridge to whichever has the `192.168.1.x` IP (wired `enp6s0`
  here; use the `wlan` adapter if on Wi-Fi).

**A6 - 64-bit guest refuses to boot ("VT-x not available").**
- Fix: enable Virtualization / VT-x / SVM in the laptop BIOS/UEFI (needed for any 64-bit guest).

---

## Cross-cutting lessons (apply on every machine)

1. **Paste-mangling is real on this setup** - long/multi-line/chained commands break. Use single
   unbroken lines, `printf ... | sudo tee`, or a script file.
2. **`sudo` needs a real TTY** - run privileged steps in an actual terminal, not through any
   non-interactive wrapper.
3. **"Running" != "working"** - verify the layer that matters (server reachable, rules_loaded,
   bytes shipped, alert on dashboard), not just that a service is `active`.
4. **Disk is the silent killer on a Pi/SD card** - logrotate + capped pcaps + watch `df -h /`; a
   full card takes down the sensor AND the agent.
5. **Read the actual error string** - most of these (NO-CARRIER, socket-path, Signed-By, no-space)
   name their own layer if you read them literally.
6. **Confirm before fixing** - get one data point (counter, grep, df) before changing config, and
   change one thing at a time.
