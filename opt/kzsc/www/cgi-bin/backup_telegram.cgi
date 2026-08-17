#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin; export PATH
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'; umask 077
get_file(){ raw="$(printf '%s' "${QUERY_STRING:-}" | tr '&' '\n' | sed -n 's/^file=//p' | head -n1)"; printf '%b' "$(printf '%s' "$raw" | sed 's/+/ /g;s/%/\\x/g')"; }
safe_name(){ case "$1" in ''|*/*|*..*|*[!A-Za-z0-9._-]*) return 1;; kzsc-backup-*.tar.gz) return 0;; *) return 1;; esac; }
name="$(get_file)"; safe_name "$name" || { echo '{"ok":false,"error":"invalid_backup"}'; exit 0; }
rid="backup-telegram-$(date +%s)-$$"; req="/tmp/kzsc-backup-req.$rid"; printf '%s\n' "backup_telegram:$name" >"$req" || { rm -f "$req"; echo '{"ok":false,"error":"queue_write_failed"}'; exit 0; }; printf '{"ok":true,"request_id":"%s"}\n' "$rid"
