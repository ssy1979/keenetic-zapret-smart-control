#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin; export PATH
PUB=/opt/kzsc/www/data/backups
get_file(){ raw="$(printf '%s' "${QUERY_STRING:-}" | tr '&' '\n' | sed -n 's/^file=//p' | head -n1)"; printf '%b' "$(printf '%s' "$raw" | sed 's/+/ /g;s/%/\\x/g')"; }
safe_name(){ case "$1" in ''|*/*|*..*|*[!A-Za-z0-9._-]*) return 1;; kzsc-backup-*.tar.gz) return 0;; *) return 1;; esac; }
name="$(get_file)"
[ -z "$name" ] || safe_name "$name" || { printf 'Status: 400 Bad Request\r\nContent-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\n\r\nGeçersiz yedek adı.\n'; exit 0; }
[ -n "$name" ] && target="$PUB/$name" || target="$(ls -1t "$PUB"/kzsc-backup-*.tar.gz 2>/dev/null | head -n1)"
if [ ! -s "$target" ]; then printf 'Status: 404 Not Found\r\nContent-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\n\r\nYedek bulunamadı.\n'; exit 0; fi
name="${target##*/}"; umask 077; rid="backup-download-$(date +%s)-$$"; req="/tmp/kzsc-backup-req.$rid"; printf '%s\n' "backup_download:$name" >"$req" 2>/dev/null || true
size="$(wc -c < "$target" 2>/dev/null | tr -d ' ')"; printf 'Content-Type: application/gzip\r\nContent-Disposition: attachment; filename="%s"\r\nContent-Length: %s\r\nCache-Control: no-store\r\n\r\n' "$name" "${size:-0}"; cat "$target"
