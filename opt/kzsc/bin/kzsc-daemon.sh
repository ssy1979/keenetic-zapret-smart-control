#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

kzsc_prepare_maintenance_queue || {
  log "daemon start failed: maintenance queue permissions"
  exit 1
}
mkdir -p "$KZSC_HOME/var/log"

DAEMON_LOCK="$KZSC_HOME/var/run/daemon.lock"

# Atomic singleton lock. If a valid owner exists, do not start another daemon.
if ! mkdir "$DAEMON_LOCK" 2>/dev/null; then
  oldpid="$(cat "$DAEMON_LOCK/pid" 2>/dev/null || true)"
  if kzsc_pid_matches "$oldpid" '/opt/kzsc/bin/kzsc-daemon.sh'; then
    log "daemon start refused: already running pid=$oldpid"
    exit 0
  fi
  # stale lock
  rm -rf "$DAEMON_LOCK" 2>/dev/null || true
  mkdir "$DAEMON_LOCK" 2>/dev/null || {
    log "daemon start failed: cannot acquire singleton lock"
    exit 1
  }
fi

echo $$ > "$DAEMON_LOCK/pid"
echo $$ > "$KZSC_PID"

cleanup_daemon(){
  # Remove shared PID only if we still own it.
  cur="$(cat "$KZSC_PID" 2>/dev/null || true)"
  [ "$cur" = "$$" ] && rm -f "$KZSC_PID"
  owner="$(cat "$DAEMON_LOCK/pid" 2>/dev/null || true)"
  [ "$owner" = "$$" ] && rm -rf "$DAEMON_LOCK"
}
# Service stop uses TERM. Ignore terminal hangups so a daemon started by an
# interactive update/restart survives the parent SSH or updater shell exiting.
trap 'cleanup_daemon; exit 0' INT TERM
trap ':' HUP
trap 'cleanup_daemon' EXIT

log "daemon started pid=$$"
[ -x /opt/kzsc/bin/kzsc-telegram.sh ] && /opt/kzsc/bin/kzsc-telegram.sh notify-system "KZSC servisi başlatıldı. Router: $(router_model)" >/dev/null 2>&1 &
# Never resume a pre-reboot Blockcheck job.  The upstream process and its
# temporary firewall/isolation state are not valid after a router restart.
/opt/kzsc/bin/kzsc-blockcheck.sh boot-reconcile >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true

# Keep recovery responsive without continuously opening a full set of NDMC
# sessions.  WAN/DPI integrity is cheap enough to check often; inventory,
# diagnostics and CGI/JSON generation are deliberately batched below.  Earlier
# versions ran both groups every 15 seconds, which created rapid
# ndm.core.socket connect/disconnect bursts on KeeneticOS.
FAST_INTERVAL="${KZSC_FAST_INTERVAL:-${KZSC_INTERVAL:-15}}"
HEAVY_INTERVAL="${KZSC_HEAVY_REFRESH_INTERVAL:-60}"
case "$FAST_INTERVAL" in ''|*[!0-9]*) FAST_INTERVAL=15;; esac
case "$HEAVY_INTERVAL" in ''|*[!0-9]*) HEAVY_INTERVAL=60;; esac
[ "$FAST_INTERVAL" -ge 5 ] 2>/dev/null || FAST_INTERVAL=5
[ "$HEAVY_INTERVAL" -ge "$FAST_INTERVAL" ] 2>/dev/null || HEAVY_INTERVAL="$FAST_INTERVAL"
next_heavy=0

fast_cycle(){
  # Reconcile owns the live topology snapshot.  It runs before datapath
  # verification so a rebinding cannot leave an enabled engine on an old WAN.
  /opt/kzsc/bin/kzsc-reconcile.sh tick >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log"
  rc=$?
  [ "$rc" -eq 0 ] || log "wan reconcile failed rc=$rc"

  /opt/kzsc/bin/kzsc-isolation.sh recover-all >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true

  # Every enabled WAN remains independently attached.  This is intentionally
  # not tied to the current default route, so a client policy/WAN switch does
  # not need to wait for the 60-second housekeeping pass.
  /opt/kzsc/bin/kzsc-native-dpi.sh ensure-all >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log"
  rc=$?
  [ "$rc" -eq 0 ] || log "native dpi ensure failed rc=$rc"

  # UI operations use this queue; keeping it in the fast path prevents a
  # Start/Stop/Profile action from being delayed by background batching.
  /opt/kzsc/bin/kzsc-maintenance.sh process-queue >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log"
  rc=$?
  [ "$rc" -eq 0 ] || log "maintenance snapshot/queue failed rc=$rc"
}

heavy_cycle(){
  /opt/kzsc/bin/kzsc-discover.sh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log"
  rc=$?
  [ "$rc" -eq 0 ] || log "discover failed rc=$rc"

  /opt/kzsc/bin/kzsc-clients.sh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log"
  rc=$?
  [ "$rc" -eq 0 ] || log "clients failed rc=$rc"

  /opt/kzsc/bin/kzsc-dpi-policy.sh refresh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-engines.sh refresh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-wan.sh maybe >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-zapret2.sh refresh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-blockcheck-cgi.sh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-blockcheck.sh refresh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-presets.sh refresh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-presets-cgi.sh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-engine-cgi.sh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true

  /opt/kzsc/bin/kzsc-telegram.sh publish-status >/dev/null 2>&1 || true
  /opt/kzsc/bin/kzsc-telegram.sh poll-commands >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-keendns.sh sync >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-updater.sh tick >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
}

while :; do
  fast_cycle

  now="$(date +%s)"
  if [ "$now" -ge "$next_heavy" ]; then
    heavy_cycle
    next_heavy=$((now + HEAVY_INTERVAL))
  fi

  ts="$(date +%s)"
  tmp="$KZSC_STATE.tmp.$$.$ts"
  if cat > "$tmp" <<EOF
{"timestamp":$ts,"mode":"$(json_escape "${KZSC_MODE:-auto_safe}")","daemon_pid":$$}
EOF
  then
    mv "$tmp" "$KZSC_STATE"
  else
    log "state write failed"
    rm -f "$tmp"
  fi

  sleep "$FAST_INTERVAL"
done
