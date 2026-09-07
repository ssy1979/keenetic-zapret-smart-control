#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
status(){ /opt/kzsc/bin/kzsc-native-dpi.sh ipv6-status 2>/dev/null; }
if [ "${REQUEST_METHOD:-GET}" = GET ]; then
  [ "$(status)" = enabled ] && printf '{"ok":true,"enabled":true}\n' || printf '{"ok":true,"enabled":false}\n'
  exit 0
fi
action="${QUERY_STRING#*=}"
case "$action" in on|enable) /opt/kzsc/bin/kzsc-native-dpi.sh ipv6 on >/dev/null 2>&1;; off|disable) /opt/kzsc/bin/kzsc-native-dpi.sh ipv6 off >/dev/null 2>&1;; *) printf '{"ok":false,"error":"invalid_action"}\n'; exit 0;; esac
rc=$?
[ "$rc" -eq 0 ] && { [ "$(status)" = enabled ] && printf '{"ok":true,"enabled":true}\n' || printf '{"ok":true,"enabled":false}\n'; } || printf '{"ok":false,"error":"ipv6_apply_failed"}\n'
