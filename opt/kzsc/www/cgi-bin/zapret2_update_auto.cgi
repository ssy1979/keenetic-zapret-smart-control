#!/opt/bin/sh
KZSC_LIB="${KZSC_LIB:-/opt/kzsc/bin/kzsc-lib.sh}"
KZSC_ZAPRET2_BIN="${KZSC_ZAPRET2_BIN:-/opt/kzsc/bin/kzsc-zapret2.sh}"
KZSC_SH="${KZSC_SH:-/opt/bin/sh}"
. "$KZSC_LIB"
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
query="${QUERY_STRING:-}"
action="$(printf '%s' "$query" | tr '&' '\n' | sed -n 's/^action=//p' | head -n1)"
case "$action" in
  on) queued_action="zapret2_update_auto_on" ;;
  off) queued_action="zapret2_update_auto_off" ;;
  status|'') queued_action='' ;;
  *) printf '{"ok":false,"error":"invalid_action"}\n'; exit 0 ;;
esac
if [ -n "$queued_action" ]; then
  queue="/opt/kzsc/var/run/maintenance-queue"; [ -d "$queue" ] || { printf '{"ok":false,"error":"maintenance_queue_unavailable"}\n'; exit 0; }
  rid="${queued_action}-$(date +%s)-$$"; req="$queue/req.$$"
  printf '%s|%s\n' "$rid" "$queued_action" >"$req" || { printf '{"ok":false,"error":"queue_write_failed"}\n'; exit 0; }
  printf '{"ok":true,"queued":true,"request_id":"%s"}\n' "$rid"; exit 0
fi
status="$("$KZSC_SH" "$KZSC_ZAPRET2_BIN" status 2>/dev/null | tail -n1)"
[ -n "$status" ] || { printf '{"ok":false,"error":"status_unavailable"}\n'; exit 0; }
printf '{"ok":true,"status":%s}\n' "$status"
