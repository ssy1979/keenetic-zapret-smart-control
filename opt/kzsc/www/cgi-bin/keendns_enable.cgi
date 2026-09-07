#!/opt/bin/sh
ACTION="keendns_enable"
QUEUE="/opt/kzsc/var/run/maintenance-queue"
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
[ -d "$QUEUE" ] || { printf '{"ok":false,"error":"maintenance_queue_unavailable"}\n'; exit 0; }
TS="$(date +%s)"; RID="${ACTION}-${TS}-$$"; req="$QUEUE/req.${TS}.$$"
if printf '%s|%s\n' "$RID" "$ACTION" >"$req"; then printf '{"ok":true,"queued":true,"request_id":"%s"}\n' "$RID"; else printf '{"ok":false,"error":"queue_write_failed"}\n'; fi
