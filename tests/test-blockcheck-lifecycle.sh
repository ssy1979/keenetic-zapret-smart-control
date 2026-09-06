#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BACKEND="$ROOT/opt/kzsc/bin/kzsc-blockcheck.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM HUP
fail(){ printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Load the actual ownership and cleanup functions, but replace procfs reads,
# process signals, sleeps, and firewall commands with deterministic fixtures.
sed -n '/^bc_process_argv(){/,/^reconcile_stale(){/p' "$BACKEND" | sed '$d' >"$TMP/identity.sh"
sed -n '/^kill_tree(){/,/^worker_restore(){/p' "$BACKEND" | sed '$d' >"$TMP/cleanup.sh"
. "$TMP/identity.sh"
. "$TMP/cleanup.sh"
KZSC_HOME="$TMP/kzsc"
job_dir(){ printf '%s/var/blockcheck/%s\n' "$KZSC_HOME" "$1"; }
bc_process_argv(){ cat "$TMP/proc/$1/argv" 2>/dev/null; }
bc_process_cwd(){ cat "$TMP/proc/$1/cwd" 2>/dev/null; }
bc_process_start(){ cat "$TMP/proc/$1/start" 2>/dev/null; }
bc_boot_id(){ printf '%s\n' "$TEST_BOOT"; }
sleep(){ :; }
kill(){
  if [ "${1:-}" = -0 ]; then [ -f "$TMP/proc/$2/alive" ]; return; fi
  printf '%s\n' "$*" >>"$TMP/signals"
}

TEST_BOOT=fixture-boot
pid=910001
nd=PPPoE0
job="$(job_dir "$nd")"
mkdir -p "$TMP/proc/$pid" "$job/run"
: >"$TMP/proc/$pid/alive"
: >"$TMP/signals"
printf '100\n' >"$TMP/proc/$pid/start"
printf '%s\n' "$pid" >"$job/pid"
printf '%s\n' /opt/bin/sh "$KZSC_HOME/bin/kzsc-blockcheck.sh" _worker "$nd" >"$TMP/proc/$pid/argv"
is_running "$nd" || fail 'exact worker was rejected'
if worker_pid_matches "$pid" PPPoE1; then fail 'another WAN worker was accepted'; fi
printf '%s\n' /opt/bin/grep "$KZSC_HOME/bin/kzsc-blockcheck.sh" _worker "$nd" >"$TMP/proc/$pid/argv"
if is_running "$nd"; then fail 'reused grep PID was accepted as a Blockcheck worker'; fi
printf '%s\n' /opt/bin/sh -c "$KZSC_HOME/bin/kzsc-blockcheck.sh _worker $nd" >"$TMP/proc/$pid/argv"
if is_running "$nd"; then fail 'shell command string was accepted as worker identity'; fi

printf '%s\n' /opt/bin/sh ./blockcheck2.sh >"$TMP/proc/$pid/argv"
printf '%s\n' "$job/run" >"$TMP/proc/$pid/cwd"
upstream_pid_matches "$pid" "$nd" || fail 'owned upstream process was rejected'
printf '/opt/unrelated\n' >"$TMP/proc/$pid/cwd"
if upstream_pid_matches "$pid" "$nd"; then fail 'foreign upstream working directory was accepted'; fi
printf '%s\n' /opt/bin/grep "$job/run/blockcheck2.sh" >"$TMP/proc/$pid/argv"
if run_tree_pid_matches "$pid" "$nd"; then fail 'arbitrary path argument was accepted as a run-tree process'; fi
printf '%s\n' "$pid" >"$job/upstream_pid"
cleanup_upstream "$nd"
[ ! -s "$TMP/signals" ] || fail 'cleanup signalled an unrelated reused PID'

mkdir -p "$TMP/bin"
cat >"$TMP/bin/iptables" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$KZSC_TEST_FIREWALL_LOG"
case "$*" in *' -D '*) exit 1;; esac
exit 0
EOF
cp "$TMP/bin/iptables" "$TMP/bin/ip6tables"
chmod +x "$TMP/bin/iptables" "$TMP/bin/ip6tables"
PATH="$TMP/bin:$PATH"
KZSC_TEST_FIREWALL_LOG="$TMP/firewall"
export PATH KZSC_TEST_FIREWALL_LOG
: >"$TMP/firewall"
printf '%s\n' /opt/bin/sh ./blockcheck2.sh >"$TMP/proc/$pid/argv"
printf '%s\n' "$job/run" >"$TMP/proc/$pid/cwd"
remember_upstream_owner "$nd" "$pid" || fail 'upstream ownership evidence was not recorded'
printf '200\n' >"$TMP/proc/$pid/start"
cleanup_temp_chains "$nd"
[ ! -s "$TMP/firewall" ] || fail 'reused PID birth time was ignored during chain cleanup'
printf '100\n' >"$TMP/proc/$pid/start"
TEST_BOOT=other-boot
cleanup_temp_chains "$nd"
[ ! -s "$TMP/firewall" ] || fail 'another boot ownership was accepted'
TEST_BOOT=fixture-boot
cleanup_temp_chains "$nd"
grep -q -- "-X blockcheck_input_$pid" "$TMP/firewall" || fail 'owned input chain not cleaned'
grep -q -- "-X blockcheck_output_$pid" "$TMP/firewall" || fail 'owned output chain not cleaned'
if grep -v "blockcheck_input_$pid\|blockcheck_output_$pid" "$TMP/firewall" | grep -q .; then
  fail 'cleanup targeted a chain outside the proven upstream process'
fi
[ ! -f "$job/upstream.owner" ] || fail 'completed chain ownership was not released'

: >"$TMP/firewall"
cleanup_temp_chains "$nd"
[ ! -s "$TMP/firewall" ] || fail 'unproven chain ownership accepted'
printf '%s\n' "$pid" >"$job/upstream_pid"
cleanup_upstream "$nd"
grep -qx "$pid" "$TMP/signals" || fail 'owned upstream process was not stopped'
grep -Fq 'worker_pid_matches "$p" "$nd" && kill "$p"' "$BACKEND" || fail 'stop/reboot cleanup lacks worker identity gate'
grep -Fq 'worker_pid_matches "$p" "$nd" && kill -9 "$p"' "$BACKEND" || fail 'force-stop lacks repeated worker identity gate'

# A WAN may reset plain HTTP while normal browser HTTPS works. The preset gate
# must keep that working profile, but must still reject a failed HTTPS path.
sed -n '/^probe_url(){/,/^probe_profile(){/p' "$BACKEND" | sed '$d' >"$TMP/probe.sh"
. "$TMP/probe.sh"
WORKER_DEADLINE=0
curl(){
  case "$*" in
    *https://*) printf '200'; return 0 ;;
    *) printf '000'; return 56 ;;
  esac
}
probe_profile_targets ppp1 'pastebin.com' || fail 'HTTPS success was rejected because plain HTTP failed'
[ "$PROBE_HTTP_STATUS" = failed ] || fail 'plain HTTP failure was not recorded'
[ "$PROBE_HTTPS_STATUS" = ok ] || fail 'HTTPS success was not recorded'
curl(){ printf '000'; return 35; }
if probe_profile_targets ppp0 'pastebin.com'; then fail 'failed HTTPS path was accepted'; fi
[ "$PROBE_HTTPS_STATUS" = failed ] || fail 'HTTPS failure was not recorded'

printf '%s\n' 'Blockcheck lifecycle identity / chain ownership regression suite: OK'
