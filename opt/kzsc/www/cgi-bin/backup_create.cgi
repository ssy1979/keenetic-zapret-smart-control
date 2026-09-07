#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin; export PATH
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
umask 077
rand="$(od -An -N8 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')"; [ -n "$rand" ] || rand="$$-$(date +%s)"
rid="backup-$(date +%s)-$$-$rand"
req="/tmp/kzsc-backup-req.$rid"
printf '%s\n' 'backup_create' >"$req" || { rm -f "$req"; echo '{"ok":false,"error":"queue_write_failed"}'; exit 0; }
printf '{"ok":true,"request_id":"%s"}\n' "$rid"
