#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
QUEUE=/opt/kzsc/var/run/maintenance-queue

qs="${QUERY_STRING:-}"
getq(){
  key="$1"
  printf '%s' "$qs" | tr '&' '\n' | sed -n "s/^${key}=//p" | head -n1
}
event="$(getq event | tr -cd 'A-Za-z0-9_.-')"
okraw="$(getq ok | tr -cd '01')"
[ "$okraw" = 0 ] && ok=false || ok=true

case "$event" in
  keendns_copy|keendns_open) : ;;
  *)
    printf '{"ok":false,"error":"unsupported_ui_event"}\n'
    exit 0
    ;;
esac

rid="ui-${event}-$(date +%s)-$$"
req="$QUEUE/req.$(date +%s).$$"
[ -d "$QUEUE" ] || { printf '{"ok":false,"error":"maintenance_queue_unavailable"}\n'; exit 0; }
if printf '%s|ui_event:%s:%s\n' "$rid" "$event" "$ok" >"$req"; then
  printf '{"ok":true,"queued":true,"request_id":"%s"}\n' "$rid"
else
  rm -f "$req" 2>/dev/null || true
  printf '{"ok":false,"error":"queue_write_failed"}\n'
fi
