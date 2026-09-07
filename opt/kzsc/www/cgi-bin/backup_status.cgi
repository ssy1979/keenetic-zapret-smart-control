#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin; export PATH
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
PUB=/opt/kzsc/www/data/backups
mkdir -p "$PUB" 2>/dev/null || true
json_escape(){ printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g'; }
files="$(ls -1t "$PUB"/kzsc-backup-*.tar.gz 2>/dev/null | head -n 20)"
latest="$(printf '%s\n' "$files" | sed -n '1p')"
if [ ! -s "$latest" ]; then echo '{"available":false,"backups":[]}'; exit 0; fi
name="${latest##*/}"; size="$(wc -c < "$latest" 2>/dev/null | tr -d ' ')"; mtime="$(date -r "$latest" +%s 2>/dev/null)"
case "$size" in ''|*[!0-9]*) size=0;; esac; case "$mtime" in ''|*[!0-9]*) mtime=0;; esac
printf '{"available":true,"filename":"%s","url":"data/backups/%s","size":%s,"updated":%s,"backups":[' "$(json_escape "$name")" "$(json_escape "$name")" "$size" "$mtime"
first=1
printf '%s\n' "$files" | while IFS= read -r f; do
 [ -s "$f" ] || continue; b="${f##*/}"; sz="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"; mt="$(date -r "$f" +%s 2>/dev/null)"; case "$sz" in ''|*[!0-9]*) sz=0;; esac; case "$mt" in ''|*[!0-9]*) mt=0;; esac
 [ "$first" -eq 1 ] || printf ','; first=0
 printf '{"filename":"%s","size":%s,"updated":%s}' "$(json_escape "$b")" "$sz" "$mt"
done
printf ']}\n'
