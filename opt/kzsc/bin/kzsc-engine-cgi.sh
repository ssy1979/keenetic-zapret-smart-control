#!/opt/bin/sh
. "${KZSC_LIB:-/opt/kzsc/bin/kzsc-lib.sh}"

CGI="$KZSC_HOME/www/cgi-bin"
QUEUE="$KZSC_HOME/var/run/maintenance-queue"
mkdir -p "$CGI" "$QUEUE"

safe_id(){
  printf '%s' "$1" | tr ' A-Z/:.' '_a-z___' | tr -cd 'a-z0-9_-'
}

# Remove previously generated engine action endpoints.
rm -f "$CGI"/engine_enable_*.cgi "$CGI"/engine_disable_*.cgi 2>/dev/null || true
# Remove obsolete header-based generic endpoints from earlier versions.
rm -f "$CGI/engine_enable.cgi" "$CGI/engine_disable.cgi" 2>/dev/null || true

write_ep(){
  local path="$1"
  local action="$2"
  local ndmc="$3"
  cat >"$path" <<EOF
#!/opt/bin/sh
QUEUE="$QUEUE"
ACTION="$action"
NDMC="$ndmc"
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
[ -d "\$QUEUE" ] || { printf '{"ok":false,"error":"maintenance_queue_unavailable"}\n'; exit 0; }
TS="\$(date +%s)"; RID="${action}-\${TS}-\$\$"
req="\$QUEUE/req.\${TS}.\$\$"
if printf '%s|%s:%s\n' "\$RID" "\$ACTION" "\$NDMC" >"\$req"; then
  printf '{"ok":true,"queued":true,"action":"%s","request_id":"%s"}\n' "\$ACTION" "\$RID"
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
  write_ep "$CGI/engine_enable_${id}.cgi" "engine_enable" "$nd"
  write_ep "$CGI/engine_disable_${id}.cgi" "engine_disable" "$nd"
  count=$((count+1))
done

printf '%s\n' "$count"
