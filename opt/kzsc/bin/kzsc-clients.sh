#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

mkdir -p "$KZSC_HOME/var" "$KZSC_HOME/var/run"
if ! kzsc_lock_acquire clients; then
  log "clients: lock timeout"
  [ -f "$KZSC_CLIENTS" ] && cat "$KZSC_CLIENTS"
  exit 1
fi
trap 'kzsc_lock_release clients' EXIT INT TERM

runid="$$.$(date +%s)"
tmp="$KZSC_HOME/var/clients.json.tmp.$runid"
body="$KZSC_HOME/var/run/clients.body.$runid"
neigh="$KZSC_HOME/var/run/neigh4.$runid.txt"

cleanup(){
  rm -f "$tmp" "$body" "$neigh" 2>/dev/null || true
}
trap 'cleanup; kzsc_lock_release clients' EXIT INT TERM

lanip="$(detect_lan_ip | head -n 1 | tr -d '\r\n')"
prefix=""
[ -n "$lanip" ] && prefix="$(printf '%s' "$lanip" | awk -F. 'NF==4{print $1"."$2"."$3"."}')"

if [ -n "$prefix" ]; then
  ip -4 neigh show 2>/dev/null | awk -v p="$prefix" '
   $1 ~ /^[0-9]+\./ && index($1,p)==1 && $0 ~ /lladdr/ && $NF !~ /FAILED/ {
     for(i=1;i<=NF;i++) if($i=="lladdr"){print $1,$(i+1),$NF}
   }' | awk '!seen[tolower($2)]++' > "$neigh"
else
  : > "$neigh"
fi

: > "$body"
count=0
first=1

while read ipx mac state; do
  [ -n "$mac" ] || continue

  name="$(resolve_client_name "$ipx" "$mac")"
  [ -n "$name" ] || name="$(client_name_from_leases "$ipx" "$mac")"
  smode="$(resolve_client_system_mode "$ipx" "$mac")"
  pol="$(resolve_client_policy "$ipx" "$mac")"

  if [ "$smode" = "extender" ]; then
    role="extender"
    ifc=""
    isp=""
    conf="high"
    method="keenetic-extender"
  else
    role="client"
    det="$(detect_client_wan "$ipx" "$mac")"
    ifc="${det%%|*}"
    rest="${det#*|}"
    conf="${rest%%|*}"
    rest="${rest#*|}"
    method="${rest%%|*}"
    dpol="${rest#*|}"
    [ -n "$dpol" ] && pol="$dpol"
    isp=""
    [ -n "$ifc" ] && isp="$(isp_label "$ifc")"
    policy_sync_client "$mac" "$ipx" "$ifc" "$conf"
  fi

  count=$((count+1))
  [ "$first" -eq 1 ] || printf ',\n' >> "$body"
  first=0

  printf '{"name":"%s","ipv4":"%s","mac":"%s","state":"%s","role":"%s","policy":"%s","wan_iface":"%s","isp":"%s","confidence":"%s","method":"%s"}' \
    "$(json_escape "$name")" "$(json_escape "$ipx")" "$(json_escape "$mac")" "$(json_escape "$state")" \
    "$(json_escape "$role")" "$(json_escape "$pol")" "$(json_escape "$ifc")" "$(json_escape "$isp")" \
    "$(json_escape "$conf")" "$(json_escape "$method")" >> "$body"
done < "$neigh"

{
  printf '{"count":%s,"clients":[\n' "$count"
  cat "$body"
  printf '\n]}\n'
} > "$tmp"

# Validate minimal JSON shape before publish
if ! grep -q '"clients":\[' "$tmp"; then
  log "clients: generated JSON validation failed"
  exit 1
fi

mv "$tmp" "$KZSC_CLIENTS"
policy_export_ipsets
cat "$KZSC_CLIENTS"
