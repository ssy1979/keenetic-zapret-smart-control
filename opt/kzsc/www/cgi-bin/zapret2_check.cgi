#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
out="$(/opt/kzsc/bin/kzsc-zapret2.sh check 2>/dev/null)"
[ -n "$out" ] && printf '%s\n' "$out" || printf '{"ok":false,"error":"Zapret2 release bilgisi alınamadı."}\n'
