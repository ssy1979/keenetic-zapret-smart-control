#!/opt/bin/sh
ACTION="refresh"
QUEUE="/opt/kzsc/var/run/maintenance-queue"

printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'

[ -d "$QUEUE" ] || {
  printf '{"ok":false,"error":"maintenance_queue_unavailable"}\n'
  exit 0
}

# PID is reliable in this CGI environment; do not depend on date(1).
RID="${ACTION}-$$"
umask 022
req="$QUEUE/req.$$"

if printf '%s|%s\n' "$RID" "$ACTION" > "$req"; then
  printf '{"ok":true,"queued":true,"action":"%s","request_id":"%s","message":"İşlem başlatıldı; tamamlanması bekleniyor."}\n' \
    "$ACTION" "$RID"
else
  printf '{"ok":false,"error":"queue_write_failed"}\n'
fi
