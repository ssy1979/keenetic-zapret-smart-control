#!/opt/bin/sh
ACTION="kzsc_uninstall"
QUEUE="/opt/kzsc/var/run/maintenance-queue"
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
[ -d "$QUEUE" ] || { printf '{"ok":false,"error":"maintenance_queue_unavailable"}\n'; exit 0; }
TS="$(date +%s)"; RID="${ACTION}-${TS}-$$"; req="$QUEUE/req.$$"
if printf '%s|%s\n' "$RID" "$ACTION" >"$req"; then
  printf '{"ok":true,"queued":true,"action":"%s","request_id":"%s","message":"KZSC tamamen kaldırma işlemi kuyruğa alındı."}\n' "$ACTION" "$RID"
else
  printf '{"ok":false,"error":"queue_write_failed"}\n'
fi
