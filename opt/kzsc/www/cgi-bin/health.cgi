#!/opt/bin/sh
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
QUEUE=/opt/kzsc/var/run/maintenance-queue
PROBE="$QUEUE/.cgi-health-$$"
if printf 'probe\n' >"$PROBE" 2>/dev/null; then
  rm -f "$PROBE"
  printf '{"ok":true,"cgi":"available","maintenance_queue":true}\n'
else
  rm -f "$PROBE" 2>/dev/null || true
  printf '{"ok":false,"cgi":"available","maintenance_queue":false,"error":"maintenance_queue_unavailable"}\n'
fi
