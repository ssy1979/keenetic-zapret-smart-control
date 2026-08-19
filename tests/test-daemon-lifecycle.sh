#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LIB="$ROOT/opt/kzsc/bin/kzsc-lib.sh"
INIT="$ROOT/opt/etc/init.d/S99kzsc"
DAEMON="$ROOT/opt/kzsc/bin/kzsc-daemon.sh"

fail(){ printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# Deterministic process table: PID 4242 is alive but its identity can be
# switched between an unrelated process and the real KZSC daemon marker.
TEST_PS_LINE='4242 root cron -f'
kill(){ [ "${1:-}" = '-0' ] && [ "${2:-}" = '4242' ]; }
ps(){ printf '%s\n' "$TEST_PS_LINE"; }

KZSC_HOME="${TMPDIR:-/tmp}/kzsc-daemon-lifecycle.$$"
export KZSC_HOME
mkdir -p "$KZSC_HOME/etc"
. "$LIB"

if kzsc_pid_matches 4242 '/opt/kzsc/bin/kzsc-daemon.sh'; then
  fail 'reused PID was accepted as the daemon owner'
fi

TEST_PS_LINE='4242 root /opt/bin/sh /opt/kzsc/bin/kzsc-daemon.sh'
kzsc_pid_matches 4242 '/opt/kzsc/bin/kzsc-daemon.sh' \
  || fail 'exact KZSC daemon owner was rejected'

if kzsc_pid_matches invalid '/opt/kzsc/bin/kzsc-daemon.sh'; then
  fail 'non-numeric PID was accepted'
fi

grep -Fq "kzsc_pid_matches \"\$p\" '/opt/kzsc/bin/kzsc-daemon.sh'" "$INIT" \
  || fail 'init script does not validate persisted daemon identity'
grep -Fq "kzsc_pid_matches \"\$oldpid\" '/opt/kzsc/bin/kzsc-daemon.sh'" "$DAEMON" \
  || fail 'daemon singleton lock does not validate persisted owner identity'
grep -Fq 'kzsc-daemon.sh </dev/null' "$INIT" \
  || fail 'daemon stdin is not detached from the calling shell'
grep -Fq "trap ':' HUP" "$DAEMON" \
  || fail 'daemon does not survive parent shell hangup'
grep -Fq 'kzsc_daemon_pids' "$INIT" \
  || fail 'init stop path does not enumerate exact daemon identities'
grep -Fq 'KZSC_FAST_INTERVAL' "$DAEMON" \
  || fail 'daemon does not provide a fast recovery interval'
grep -Fq 'KZSC_HEAVY_REFRESH_INTERVAL' "$DAEMON" \
  || fail 'daemon does not batch heavy refresh work'
grep -Fq 'heavy_cycle' "$DAEMON" \
  || fail 'daemon does not separate heavy background work'

rm -rf "$KZSC_HOME"
printf '%s\n' 'Daemon lifecycle regression suite: OK'
