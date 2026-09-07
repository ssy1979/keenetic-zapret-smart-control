#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
[ "${REQUEST_METHOD:-}" = POST ] || { echo '{"ok":false,"error":"method_not_allowed"}'; exit 0; }
umask 077
rand="$(od -An -N8 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')"
[ -n "$rand" ] || rand="$$-$(date +%s)"
rid="telegram-$(date +%s)-$$-$rand"
payload="/tmp/kzsc-telegram-payload.$rid"
tmp="/tmp/kzsc-telegram-payload.$rid.tmp"
req="/tmp/kzsc-telegram-req.$rid"
cat >"$tmp" || { rm -f "$tmp"; echo '{"ok":false,"error":"payload_write_failed"}'; exit 0; }
mv "$tmp" "$payload" || { rm -f "$tmp" "$payload"; echo '{"ok":false,"error":"payload_commit_failed"}'; exit 0; }
printf '%s\n' 'telegram_save' >"$req" || { rm -f "$payload" "$req"; echo '{"ok":false,"error":"queue_write_failed"}'; exit 0; }
printf '{"ok":true,"request_id":"%s"}\n' "$rid"
