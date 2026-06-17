# Attacker VM (Arch) Setup + Phase 3 Kickoff

**What this is:** the as-built record of standing up the lab's **attacker** node (a minimal Arch
Linux VM) on the Pop!_OS laptop, every pitfall hit, and the "what to do now" once you are SSH'd in.
This is the gateway to **Phase 3 (threat simulation)** - attacker -> Pi sensor -> Wazuh.

**Built:** 2026-06-17. **Attacker:** Arch Linux VM `zeno`, user `ultron`, IP `192.168.1.106`.

---

## 1. Why Arch (not Kali)

Kali pre-bundles offensive tools but is heavy (~15-20 GB). For this lab we want a **lean, you-only-
install-what-you-need** attacker. Minimal Arch + 4-6 attack packages = ~4-5 GB, no bloat, smaller
attack surface. The attacker tooling that matters (`nmap`, `hydra`, `hping3`, `scapy`) installs on
any Linux; Kali gives no advantage for it. (Kali would be worth it only for the full MITRE/
metasploit bundle + snapshots - a later option.)

Runs on the **laptop** (16 GB host, give the VM ~2.6 GB + 2-3 cores). The Pi is the sensor, never
the attacker host.

---

## 2. VirtualBox VM settings (as built)

| Setting | Value | Note |
|---|---|---|
| OS type | Arch Linux (64-bit) | needs host VT-x/SVM enabled in BIOS for a 64-bit guest |
| Base memory | ~2638 MB | plenty for a CLI attacker |
| CPUs | 3 | fine |
| Disk | **16 GB, VDI, dynamically allocated** | only uses ~4-5 GB; 8 GB is too tight once you capture pcaps |
| Display | 131 MB, VMSVGA | no GUI needed; 3D accel pointless (can uncheck) |
| Boot ISO | `archlinux-2026.04.01-x86_64.iso` | the official install ISO |
| **Network -> Adapter 1** | **Bridged Adapter -> `enp6s0`** | THE critical setting - puts the VM on the real LAN. NAT will NOT work (see P-A2) |

Bridge to the host's **active** interface. Confirm with `ip -br a` on the laptop - here the wired
`enp6s0` carries `192.168.1.105`. If the laptop is on Wi-Fi, bridge to the `wlan` adapter instead.

---

## 3. Install steps (as built)

1. Boot the ISO -> Arch live shell (root, auto-login).
2. **Refresh keyring + installer first** (avoids signature errors mid-install):
   ```
   pacman -Sy archlinux-keyring archinstall
   ```
3. Run `archinstall` and choose:
   - **Profile: Minimal** (no desktop - leanest; skip Plasma/GNOME entirely)
   - **Network configuration: NetworkManager** (CRITICAL - the *installed* system needs this or it
     boots with no networking; the live ISO's internet does NOT carry over)
   - **Kernel:** `linux-zen` (or `linux`) - fine
   - **User account:** create one (here `ultron`) - you SSH in as this user, then `sudo`
   - **Hostname:** `zeno`
   - **Firewall:** `ufw` (simpler than firewalld; neither blocks *outbound* attacks)
   - **Additional packages:** `openssh sudo nano nmap hydra hping3 tcpdump python-scapy`
     (Minimal omits SSH/sudo/editor - add them here)
4. Finish, reboot, remove the ISO from the boot order if needed.

---

## 4. Make it SSH-reachable from the laptop

In the **VM console** (clipboard paste does NOT work there - see P-A1 - so type these by hand):
```
sudo systemctl enable --now sshd          # Minimal does not auto-start it
sudo ufw allow ssh                        # ufw blocks inbound 22 by default
ip -br a                                   # note the 192.168.1.x address
```
Then from the **laptop**:
```
ssh ultron@192.168.1.106
```
Now you drive the attacker from the laptop terminal (copy-paste works), exactly like the Pi.

---

## 5. What to do now (you are SSH'd in as `ultron@zeno`)

**Step 1 - confirm the weapons:**
```
which nmap hydra hping3 tcpdump
```

**Step 2 - take a clean snapshot** (so you can reset the attacker between experiments):
- VirtualBox -> select the VM -> Snapshots -> Take (name it "clean-base").

**Step 3 - first attack -> detect test (the Phase 3 payoff).**
Scan the **Pi sensor** (`.104`) - it must be the target, because on Wi-Fi the Pi only sees traffic
*to itself* (it cannot watch attacks between two other hosts):
```
sudo nmap -sV -A 192.168.1.104
```
(`-sV -A` = version + OS + script detection -> trips ET SCAN / nmap-fingerprint rules loudly. A
plain `-sS` may be too quiet.)

**Step 4 - watch the Pi catch it.** In a second terminal SSH'd into the **Pi**:
```
sudo tail -f /var/log/suricata/fast.log
```
You should see ET SCAN / nmap signatures appear as the scan runs.

**Step 5 - confirm it reached the SIEM.** Wazuh dashboard `https://192.168.1.50` -> Threat Hunting
-> filter `agent.name:rpi-sensor` (or `rule.groups:suricata`), Last 15 min -> the scan alerts show.
Screenshot -> `portfolio/screenshots/rpi_phase3/`.

**Step 6 - the rest of Phase 3** (then write `incidents/phase3_threat_sim_report.md`):
- `hydra` SSH brute force against a Linux target you control
- a few MITRE ATT&CK techniques, documented one by one
- each attack: note what fired, what did NOT (gaps -> Phase 4 detection engineering)

---

## 6. Pitfalls hit building this attacker (see also `docs/TROUBLESHOOTING_LOG.md`)

| ID | Pitfall | Fix |
|---|---|---|
| P-A1 | Clipboard paste dead in the VBox console | no Guest Additions + raw TTY (no GUI); use SSH from the laptop instead |
| P-A2 | VM got a NAT IP `10.0.2.15`, unreachable from the laptop | Adapter 1 was on NAT; set it to **Bridged -> enp6s0** -> got `192.168.1.106` |
| P-A3 | Minimal profile has no SSH | install `openssh` + `sudo systemctl enable --now sshd` (Server profile would include it; Minimal does not) |
| P-A4 | `sshd active` but port 22 closed from outside | `ufw` was blocking inbound 22 -> `sudo ufw allow ssh` |
| P-A5 | Bridged to the wrong NIC = no network | bridge to the host's ACTIVE interface (`ip -br a` -> the one with `192.168.1.x`) |
| P-A6 | 64-bit guest won't boot ("VT-x not available") | enable Virtualization / VT-x / SVM in the laptop BIOS |

---

## 7. Lab topology now

```
[ Attacker: Arch VM "zeno"  192.168.1.106 ]  <-- you SSH here from the laptop
            |
        (LAN 192.168.1.0/24, bridged)
            |
[ Pi sensor "rpi-sensor"  192.168.1.104 ]  --Suricata eve.json-->  [ Wazuh server 192.168.1.50 ]
[ popos-mainpc .105 ] [ zbook-arch .108 ]  --Wazuh agents (host logs)-->  (same SIEM)
```

Laptop = command center (SSH into attacker AND Pi). Attacker generates traffic; the Pi (network)
and the host agents (endpoint) both feed one Wazuh SIEM. That is the full attack -> detect loop.
