#!/opt/bin/sh
ACTION="kzsc_update_auto_on"
QUEUE="/opt/kzsc/var/run/maintenance-queue"
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
[ -d "$QUEUE" ] || { printf '{"ok":false,"error":"maintenance_queue_unavailable"}\n'; exit 0; }
TS="$(date +%s)"; RID="${ACTION}-${TS}-$$"
printf '%s|%s\n' "$RID" "$ACTION" >"$QUEUE/req.${TS}.$$" || { printf '{"ok":false,"error":"queue_write_failed"}\n'; exit 0; }
printf '{"ok":true,"request_id":"%s"}\n' "$RID"
