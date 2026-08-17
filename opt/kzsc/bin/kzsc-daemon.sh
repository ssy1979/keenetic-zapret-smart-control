#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

mkdir -p "$KZSC_HOME/var/run" "$KZSC_HOME/var/log" "$KZSC_HOME/var/run/maintenance-queue"
chmod 733 "$KZSC_HOME/var/run/maintenance-queue" 2>/dev/null || true

DAEMON_LOCK="$KZSC_HOME/var/run/daemon.lock"

# Atomic singleton lock. If a valid owner exists, do not start another daemon.
if ! mkdir "$DAEMON_LOCK" 2>/dev/null; then
  oldpid="$(cat "$DAEMON_LOCK/pid" 2>/dev/null || true)"
  if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
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
trap 'cleanup_daemon; exit 0' INT TERM HUP
trap 'cleanup_daemon' EXIT

log "daemon started pid=$$"
[ -x /opt/kzsc/bin/kzsc-telegram.sh ] && /opt/kzsc/bin/kzsc-telegram.sh notify-system "KZSC servisi başlatıldı. Router: $(router_model)" >/dev/null 2>&1 &

while :; do
  /opt/kzsc/bin/kzsc-discover.sh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log"
  rc=$?
  [ "$rc" -eq 0 ] || log "discover failed rc=$rc"

  # Reconcile live Keenetic WAN identity/bindings before clients or DPI ensure.
  # This catches default-WAN changes, PPPoE renumbering and newly created WANs.
  /opt/kzsc/bin/kzsc-reconcile.sh tick >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log"
  rc=$?
  [ "$rc" -eq 0 ] || log "wan reconcile failed rc=$rc"

  /opt/kzsc/bin/kzsc-clients.sh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log"
  rc=$?
  [ "$rc" -eq 0 ] || log "clients failed rc=$rc"

  /opt/kzsc/bin/kzsc-isolation.sh recover-all >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true

  /opt/kzsc/bin/kzsc-wan-registry.sh refresh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-engines.sh refresh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true

  # KZSC-native DPI datapath reconciliation runs after topology reconciliation.
  /opt/kzsc/bin/kzsc-native-dpi.sh ensure-all >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log"
  rc=$?
  [ "$rc" -eq 0 ] || log "native dpi ensure failed rc=$rc"

  /opt/kzsc/bin/kzsc-wan.sh maybe >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log"
  rc=$?
  [ "$rc" -eq 0 ] || log "wan monitor failed rc=$rc"

  /opt/kzsc/bin/kzsc-zapret2.sh refresh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-blockcheck-cgi.sh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-blockcheck.sh refresh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-presets.sh refresh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-presets-cgi.sh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-engine-cgi.sh >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true

  /opt/kzsc/bin/kzsc-telegram.sh publish-status >/dev/null 2>&1 || true
  /opt/kzsc/bin/kzsc-telegram.sh poll-commands >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true
  /opt/kzsc/bin/kzsc-keendns.sh sync >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true

  /opt/kzsc/bin/kzsc-maintenance.sh process-queue >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log"
  rc=$?
  [ "$rc" -eq 0 ] || log "maintenance snapshot/queue failed rc=$rc"

  # GitHub Releases check is internally rate-limited to 30 minutes. Automatic
  # installation remains opt-in and is deferred while Blockcheck is running.
  /opt/kzsc/bin/kzsc-updater.sh tick >/dev/null 2>>"$KZSC_HOME/var/log/daemon.log" || true

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

  sleep "${KZSC_INTERVAL:-15}"
done
