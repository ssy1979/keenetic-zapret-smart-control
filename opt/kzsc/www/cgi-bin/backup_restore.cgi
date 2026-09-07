#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin; export PATH
printf 'Content-Type: application/json
Cache-Control: no-store

'
[ "${REQUEST_METHOD:-}" = POST ] || { echo '{"ok":false,"error":"method_not_allowed"}'; exit 0; }
umask 077
max=5242880; len="${CONTENT_LENGTH:-}"
case "$len" in ''|*[!0-9]*) echo '{"ok":false,"error":"invalid_content_length"}'; exit 0;; esac
[ "$len" -le "$max" ] || { echo '{"ok":false,"error":"backup_too_large"}'; exit 0; }
rand="$(od -An -N8 -tx1 /dev/urandom 2>/dev/null | tr -d ' 
')"; [ -n "$rand" ] || rand="$$-$(date +%s)"
rid="backup-restore-$(date +%s)-$$-$rand"; up="/tmp/kzsc-backup-upload.$rid"; req="/tmp/kzsc-backup-req.$rid"
cat >"$up" || { rm -f "$up"; echo '{"ok":false,"error":"upload_write_failed"}'; exit 0; }
[ -s "$up" ] || { rm -f "$up"; echo '{"ok":false,"error":"empty_backup"}'; exit 0; }
size="$(wc -c <"$up" 2>/dev/null | tr -d ' ')"; case "$size" in ''|*[!0-9]*) size=0;; esac
[ "$size" -le "$max" ] || { rm -f "$up"; echo '{"ok":false,"error":"backup_too_large"}'; exit 0; }
printf '%s
' 'backup_restore' >"$req" || { rm -f "$up" "$req"; echo '{"ok":false,"error":"queue_write_failed"}'; exit 0; }
printf '{"ok":true,"request_id":"%s"}
' "$rid"
