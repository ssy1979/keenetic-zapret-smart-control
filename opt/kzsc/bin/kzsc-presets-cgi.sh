#!/opt/bin/sh
. "${KZSC_LIB:-/opt/kzsc/bin/kzsc-lib.sh}"

CGI="$KZSC_HOME/www/cgi-bin"
QUEUE="$KZSC_HOME/var/run/maintenance-queue"
mkdir -p "$CGI" "$QUEUE"

safe_id(){
  printf '%s' "$1" | tr ' A-Z/:.' '_a-z___' | tr -cd 'a-z0-9_-'
}

rm -f "$CGI/profile_set.cgi" "$CGI"/profile_set_*_*.cgi 2>/dev/null || true

write_profile_ep(){
  local path="$1" ndmc="$2" preset="$3"
  cat >"$path" <<EOF
#!/opt/bin/sh
QUEUE="$QUEUE"
NDMC="$ndmc"
PRESET="$preset"
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'

[ -d "\$QUEUE" ] || {
  printf '{"ok":false,"error":"maintenance_queue_unavailable"}\n'
  exit 0
}

ACTION="profile_set:\$NDMC:\$PRESET"
TS="\$(date +%s)"; RID="profile_set-\${TS}-\$\$"
req="\$QUEUE/req.\${TS}.\$\$"
umask 022

if printf '%s|%s\n' "\$RID" "\$ACTION" >"\$req"; then
  printf '{"ok":true,"queued":true,"action":"profile_set","request_id":"%s","message":"Profil seçimi gönderildi."}\n' "\$RID"
else
  printf '{"ok":false,"error":"queue_write_failed"}\n'
fi
EOF
  chmod 755 "$path"
}

count=0
for nd in $(internet_wans); do
  [ -n "$nd" ] || continue
  id="$(safe_id "$nd")"
  [ -n "$id" ] || continue
  for preset in tt sol kablonet $(find "$KZSC_HOME/share/dpi-presets" -maxdepth 1 -type f -name 'kzm2-*.conf' 2>/dev/null | sed 's#.*/##;s/\.conf$//' | sort) "auto_$(safe_id "$nd")"; do
    case "$preset" in auto_*) [ -f "$KZSC_HOME/var/dpi/auto-presets/$preset.conf" ] || continue;; esac
    write_profile_ep "$CGI/profile_set_${id}_${preset}.cgi" "$nd" "$preset"
    count=$((count+1))
  done
done

printf '%s\n' "$count"
