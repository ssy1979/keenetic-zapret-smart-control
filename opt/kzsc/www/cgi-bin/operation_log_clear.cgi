#!/opt/bin/sh
QUEUE=/opt/kzsc/var/run/maintenance-queue
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'

[ -d "$QUEUE" ] || { printf '{"ok":false,"error":"maintenance_queue_unavailable"}\n'; exit 0; }
ts="$(date +%s)"; rid="operation-log-clear-$ts-$$"; req="$QUEUE/req.$ts.$$"
if printf '%s|operation_log_clear\n' "$rid" >"$req"; then
  printf '{"ok":true,"queued":true,"request_id":"%s"}\n' "$rid"
else
  rm -f "$req" 2>/dev/null || true
  printf '{"ok":false,"error":"queue_write_failed"}\n'
fi
