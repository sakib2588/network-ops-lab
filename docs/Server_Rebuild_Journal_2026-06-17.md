# Build Journal: Wazuh Server Rebuild (Docker single-node on Arch)

**Date:** 2026-06-17
**Operator:** Nazmus Sakib
**Scope:** Step 0 of the SOC lab plan, server side only (this laptop). Agent enrollment
on the other machines is a separate, later step.

> Note on redaction: this journal uses `<SERVER_IP>` and `<ADMIN_PASS>` in place of the real
> values. The lab currently runs on the Wazuh default credentials (LAN only). Change the
> defaults and keep all real IPs / passwords out before making any copy of this file public.

---

## 1. Starting point

The original Wazuh server lived on a VirtualBox VM that was decommissioned. The decision was
to rebuild fresh as a Docker single-node stack on the always-home 12 GB Arch laptop. This same
laptop used to be a monitored node; it is now being turned into the server.

Target end-state: Wazuh Manager + Indexer + Dashboard running as containers, reachable on the
LAN, set to come back automatically after a reboot.

---

## 2. Pre-flight findings (the constraints that shaped the build)

| Check | Result | Consequence |
|---|---|---|
| RAM | 11 GB total, ~9 GB free | Enough for a single-node stack with a pinned heap |
| `vm.max_map_count` | already high | Indexer (OpenSearch) requirement satisfied |
| Root filesystem `/` | 32 GB, 96% full (1.4 GB free) | Too small to hold container images |
| `/media` drives (incl. the HDD) | all NTFS | Cannot host Docker storage (needs ext4/xfs) |
| `/home` | separate ext4 partition, ~143 GB free | The correct home for all Docker data |
| Docker | not installed | Install needed |

Key early decision: put all Docker data on `/home` (ext4, roomy), never on the cramped `/`,
and never on the NTFS HDD (Docker's storage driver cannot use NTFS).

---

## 3. Steps executed

1. **Reclaimed space on `/`.** The pacman package cache held 6.8 GB of old downloads. Clearing
   it took `/` from 1.4 GB free to 8.7 GB free.
2. **Installed Docker + Compose** (Docker 29.5.2, Compose 5.1.4). No dependency conflicts.
3. **Pointed Docker `data-root` at `/home`** via `/etc/docker/daemon.json`, then enabled the
   service and persisted `vm.max_map_count=262144`. Confirmed `docker info` reported the new
   root and `hello-world` ran.
4. **Cloned the official `wazuh-docker` repo**, checked out the latest stable tag (4.14.5).
5. **Pinned the indexer JVM heap to 2 GB** (`OPENSEARCH_JAVA_OPTS=-Xms2g -Xmx2g`) so OpenSearch
   would not grab half the host RAM and starve the manager and dashboard.
6. **Generated the indexer TLS certificates**, then brought the stack up. The first image pull
   timed out mid-transfer (flaky connection); a retry loop resumed the already-downloaded
   layers and completed the pull, then started all three containers.

---

## 4. Problems hit, and how each was fixed

This is the honest part. The build worked, but two disk-routing problems surfaced after start.

### Problem 1 - Dashboard returned HTTP 503 on first start
**Cause:** startup race. The dashboard booted faster than the indexer and could not reach
OpenSearch yet (`ECONNREFUSED` on port 9200).
**Fix:** restart the dashboard after the indexer is up. (This alone was not enough because of
Problem 2 below, which was the real blocker.)

### Problem 2 - Root filesystem hit 100% and the dashboard died (`exit 128: no space left on device`)
**Cause (the important lesson):** Docker 29 uses the containerd image store, which keeps image
layers under `/var/lib/containerd`. The `data-root` setting only relocates Docker's own
directory (`/var/lib/docker`); it does NOT move the containerd image store. So roughly 10 GB of
Wazuh images landed back on the small `/` and filled it. The indexer and manager kept running
because their container tasks already existed; the dashboard could not create a new task.
**Fix:** stop Docker and containerd, move `/var/lib/containerd` (10 GB) onto `/home`, and
symlink it back. No image re-download was needed. `/` recovered to ~8.4 GB free.

### Problem 3 - Dashboard stuck on a stale index migration lock
**Cause:** the earlier crashes (while `/` was full) left the `.kibana_1` index half-migrated,
so the dashboard waited forever for a migration that no live process was running.
**Fix:** delete the empty `.kibana` index (a brand-new install with nothing to lose) and
restart the dashboard. It recreated the index cleanly and came up.

---

## 5. Network: static IP

DHCP reassigned the laptop's address during the session (it drifted from one address to
another). A server must keep a fixed address or agents lose it. Set a static IP on the Arch
host via NetworkManager (`<SERVER_IP>`), verified gateway, internet, and DNS still worked.
A router DHCP reservation is still recommended as the more robust long-term option.

---

## 6. Verified end-state

- All three containers `Up`; `restart: always` set and `docker.service` enabled, so the stack
  returns after a reboot.
- Indexer cluster health: green (single node).
- Wazuh Manager API: up (returns 401 without credentials, i.e. auth is enforced).
- Dashboard: reachable at `https://<SERVER_IP>` (HTTP 302 to the login page).
- Storage: Docker images, volumes, and the containerd store all on `/home`; `/` healthy.

---

## 7. What is built in vs what was done here (honesty split)

- **Built in / credited:** Wazuh and its default ruleset, the official `wazuh-docker` images,
  OpenSearch. These do the heavy lifting.
- **Done here:** the deployment and its hardening on constrained hardware - routing all Docker
  storage onto the correct partition, pinning the indexer heap for a low-RAM host, diagnosing
  and fixing the containerd-store disk issue, clearing the migration lock, and pinning the IP.

This is an operations / deployment milestone, not a detection-engineering result. No detections
were written or claimed here.

---

## 8. Next steps (not done in this session)

- Re-enroll the agents (Ubuntu PC, Windows PC, Pop!_OS box, Raspberry Pi) - separate machines.
- Add a router DHCP reservation for the server.
- Let the server run 2-3 days collecting before declaring Phase 2 complete.

---

## 9. Troubleshooting log (what actually went wrong, and how it was found)

Each entry below is written so you can reproduce the *diagnosis*, not just the fix. The pattern
is always the same: read the real error, find the layer it came from, change one thing, verify.

### T1 - First image pull timed out mid-download
- **Symptom:** `docker compose up` ended with `failed to copy: ... read: connection timed out`
  while pulling the indexer image; no containers were created.
- **How it was found:** read the tail of the command output; the last lines showed the partial
  layer download stopping at a fixed size.
- **Cause:** a transient drop on the home connection during a ~7 GB pull.
- **Fix:** a retry loop (`docker compose pull` up to N times, then `up -d`). Docker keeps the
  layers it already fetched, so each retry resumes instead of restarting.
- **Verify:** `docker compose ps` shows all three containers `Up`.
- **Lesson:** large pulls over flaky links need a resumable retry, not a single shot. Exit code
  alone can mislead - a piped command can report the exit of the last pipe stage (`tee`), not the
  real failure, so always read the actual output.

### T2 - Dashboard returned HTTP 503 right after start
- **Symptom:** dashboard answered 503; indexer and manager looked fine.
- **How it was found:** `docker logs <dashboard>` showed `ECONNREFUSED ...:9200` timestamps from
  the first seconds of boot.
- **Cause:** startup race - the dashboard boots faster than the indexer and tries to connect
  before OpenSearch is listening.
- **Fix:** wait for the indexer, then restart the dashboard.
- **Verify:** `curl -k -o /dev/null -w '%{http_code}' https://localhost` returns 302.
- **Lesson:** in multi-container stacks, "Up" is not "ready". Order and readiness matter.

### T3 - Root filesystem hit 100%, dashboard died with `exit 128: no space left on device` (the big one)
- **Symptom:** `docker restart` of the dashboard failed:
  `mkdir /var/lib/containerd/...: no space left on device`. `df -h /` showed `/` at 100%.
- **How it was found:** `docker inspect` of the dead container exposed the exact error string,
  which named `/var/lib/containerd` - on `/`, not on the partition I had configured.
- **Cause:** Docker 29 uses the containerd image store. Image layers live under
  `/var/lib/containerd`, and the `data-root` setting in `daemon.json` only relocates Docker's own
  `/var/lib/docker` - it does NOT move the containerd store. So ~10 GB of images filled `/`.
- **Fix:** stop docker + containerd, `mv /var/lib/containerd` to the big partition, symlink it
  back, restart. No image re-download.
- **Verify:** `df -h /` recovered; `ls -ld /var/lib/containerd` shows the symlink;
  `docker compose up -d` brings all three containers up.
- **Lesson:** on Docker 29+, relocating storage means BOTH the Docker data-root AND the containerd
  root. Confirm with `docker info | grep -i 'root dir'` and by watching `df` during the first pull.

### T4 - Dashboard hung forever on index migration
- **Symptom:** after the crashes, the dashboard logged "Another OpenSearch Dashboards instance
  appears to be migrating the index. Waiting for that migration to complete."
- **Cause:** an earlier instance died mid-migration (because `/` was full) and left the
  `.kibana_1` index with a stale lock.
- **Fix:** delete the empty `.kibana*` index (fresh install, nothing to lose) and restart.
- **Verify:** dashboard log shows `http server running at https://0.0.0.0:5601`; HTTP 302.
- **Lesson:** a process killed mid-write can leave a lock that outlives it. On a fresh system the
  safe reset is to delete the half-built index and let it rebuild.

### T5 - DHCP reassigned the server IP mid-build
- **Symptom:** the laptop's address silently changed from one value to another.
- **Cause:** the address was a DHCP lease, not fixed.
- **Fix:** set a static IP on the host (NetworkManager), verified gateway + internet + DNS.
- **Verify:** `ip -4 addr` shows the fixed address; `ping` gateway and a public IP succeed.
- **Lesson:** a server needs a stable address or agents lose it on every lease change. Host static
  IP works; a router DHCP reservation is even more robust.

### T6 - "Site can't be reached" (ERR_CONNECTION_REFUSED) in the browser
- **Symptom:** `192.168.1.50` in the browser returned connection refused.
- **Cause (two parts):** (a) it was hit during a container rebuild window when nothing was
  listening; (b) the dashboard listens only on port 443 (HTTPS) - typing the bare IP makes the
  browser try `http://...:80`, where nothing is listening.
- **Fix / how to avoid:** always use the `https://` prefix; wait for the rebuild to finish.
- **Verify:** `ss -tlnp | grep ':443'` shows the listener; only 443 is open, not 80.
- **Lesson:** "refused" (nothing on that port) is a different failure from a TLS warning (wrong
  scheme reaches a live HTTPS port). The error text tells you which.

### T7 - Dashboard up, but "[API connection] No API available to connect"
- **Symptom:** login worked, but the dashboard could not reach the Wazuh Manager API.
- **How it was found:** tested the manager API directly with `curl -u wazuh-wui:<newpass> -X POST
  .../security/user/authenticate` (got 200, so the manager was fine), then read
  `config/wazuh_dashboard/wazuh.yml` and saw it still held the OLD default API password.
- **Cause:** the API password lives in TWO places - the manager (set from the `API_PASSWORD` env)
  and the dashboard's `wazuh.yml` file. The env change updated the manager, but `wazuh.yml` is a
  static mounted file that is NOT templated from the env, so it kept the old password and the two
  no longer matched.
- **Fix:** set the password in `config/wazuh_dashboard/wazuh.yml` to match the manager's API
  password, then recreate.
- **Verify:** manager API returns 200 for the new creds and 401 for the old; the dashboard's
  "Check API connection" turns green on reload.
- **Lesson:** when you rotate a credential, change it in EVERY place it is stored. Env vars and
  on-disk config files do not always sync automatically.

---

## 10. Edge cases and pitfalls (checklist for next time)

| # | Pitfall | Why it bites | Guardrail |
|---|---|---|---|
| 1 | Putting Docker data on an NTFS drive | Docker's storage driver needs a Linux fs (ext4/xfs); NTFS is rejected | Use an ext4/xfs partition; this lab uses `/home` |
| 2 | Assuming `data-root` moves all Docker data | On Docker 29 the containerd image store (`/var/lib/containerd`) is separate | Relocate both; verify with `docker info` and `df` |
| 3 | Small `/` partition | SIEM indices + images grow fast and fill `/`, crashing containers | Keep all container data off `/`; watch `df -h /` |
| 4 | Indexer grabs half the RAM | OpenSearch default heap is ~50% of host RAM; starves manager + dashboard on a small box | Pin `OPENSEARCH_JAVA_OPTS=-Xms2g -Xmx2g` before first start |
| 5 | `vm.max_map_count` too low | The indexer silently fails or crash-loops | Set `>=262144` and persist in `/etc/sysctl.d/` |
| 6 | Treating "Up" as "ready" | Dashboard races ahead of the indexer -> 503 | Wait for indexer health, then the dashboard |
| 7 | Stale `.kibana` migration lock | A crash mid-migration blocks every later start | Delete the empty `.kibana*` index, restart (fresh installs only) |
| 8 | DHCP address drift | Agents lose the server when the lease changes | Static IP or router DHCP reservation |
| 9 | Bare IP in the browser | Dashboard is HTTPS-only (port 443); bare IP tries port 80 | Always use `https://<ip>` |
| 10 | Rotating a password in only one place | API password lives in manager env AND dashboard `wazuh.yml` | Change every copy, then recreate; test both old (should fail) and new (should pass) |
| 11 | Default credentials left in place | `wazuh-docker` ships public default passwords | Change them before any exposure; never commit real passwords |
| 12 | Trusting a piped command's exit code | `cmd | tee` reports tee's exit, hiding the real failure | Read the actual output, not just the exit code |
| 13 | Editing the live security config and expecting it to apply | The security config loads into an index on first init only | Re-run `securityadmin.sh`, or (fresh lab only) recreate with clean volumes |
| 14 | `docker compose down -v` on a lab with real data | `-v` deletes named volumes (all collected events) | Only use `-v` when there is nothing to lose; otherwise omit it |
| 15 | Committing secrets / real IPs / personal paths to a public repo | Leaks credentials and infra detail | Redact before publishing; ASCII-only to avoid mojibake on GitHub |

---

## 11. Diagnostic cheat-sheet (commands used here)

```bash
# container state and why one died
docker compose ps
docker inspect <container> --format 'ExitCode={{.State.ExitCode}} OOM={{.State.OOMKilled}} Error="{{.State.Error}}"'
docker logs --tail 30 <container>

# disk: where is the space going
df -h /            # is root full?
du -xhd1 /var/lib  # which dir is the culprit (containerd vs docker)
docker info | grep -i 'root dir'

# indexer health (single node "yellow"/"green" both fine)
curl -k -u admin:<pass> https://localhost:9200/_cluster/health

# manager API reachable + credentials valid
curl -k -u wazuh-wui:<api_pass> -X POST 'https://localhost:55000/security/user/authenticate?raw=true'

# dashboard reachable (302 = login page = good; 503 = not ready; 000 = not listening)
curl -k -o /dev/null -w '%{http_code}' https://localhost:443

# what is actually listening (explains "connection refused")
ss -tlnp | grep -E ':443|:9200|:55000'
```
