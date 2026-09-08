#!/opt/bin/sh
. "${KZSC_LIB:-/opt/kzsc/bin/kzsc-lib.sh}"

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
registered="$KZSC_HOME/var/run/registered-clients.$runid.tsv"
seen="$KZSC_HOME/var/run/clients-seen.$runid.txt"

cleanup(){
  rm -f "$tmp" "$body" "$neigh" "$registered" "$seen" 2>/dev/null || true
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
: > "$seen"
# Keep Keenetic's registered-client view alongside the live neighbour table.
# It lets the panel manage an offline device by its stable MAC preference; the
# current/reserved IP is used only after the device is reachable again.
host_records_tsv > "$registered"
count=0
first=1

append_client(){
  name="$1"; ipx="$2"; mac="$3"; state="$4"; role="$5"; pol="$6"
  ifc="$7"; isp="$8"; conf="$9"; method="${10}"; dpi_mode="${11}"
  static_ip="${12}"; online="${13}"; is_registered="${14}"
  count=$((count+1))
  [ "$first" -eq 1 ] || printf ',\n' >> "$body"
  first=0
  printf '{"name":"%s","ipv4":"%s","mac":"%s","state":"%s","role":"%s","policy":"%s","wan_iface":"%s","isp":"%s","confidence":"%s","method":"%s","zapret_enabled":%s,"static_ip":"%s","online":%s,"registered":%s}' \
    "$(json_escape "$name")" "$(json_escape "$ipx")" "$(json_escape "$mac")" "$(json_escape "$state")" \
    "$(json_escape "$role")" "$(json_escape "$pol")" "$(json_escape "$ifc")" "$(json_escape "$isp")" \
    "$(json_escape "$conf")" "$(json_escape "$method")" "$([ "$dpi_mode" = disabled ] && echo false || echo true)" \
    "$(json_escape "$static_ip")" "$online" "$is_registered" >> "$body"
}

while read ipx mac state; do
  [ -n "$mac" ] || continue
  printf '%s\n' "$(printf '%s' "$mac" | tr '[:upper:]' '[:lower:]')" >> "$seen"

  name="$(resolve_client_name "$ipx" "$mac")"
  [ -n "$name" ] || name="$(client_name_from_leases "$ipx" "$mac")"
  smode="$(resolve_client_system_mode "$ipx" "$mac")"
  pol="$(resolve_client_policy "$ipx" "$mac")"
  dpi_mode="$(kzsc_dpi_device_mode "$mac")"
  static_ip="$(kzsc_dpi_static_ip "$mac")"

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

  if awk -F '\t' -v m="$mac" 'tolower($2)==tolower(m){found=1} END{exit !found}' "$registered"; then
    is_registered=true
  else
    is_registered=false
  fi
  append_client "$name" "$ipx" "$mac" "$state" "$role" "$pol" "$ifc" "$isp" "$conf" "$method" "$dpi_mode" "$static_ip" true "$is_registered"
done < "$neigh"

# Add every Keenetic-registered client that was not in the live ARP/neighbour
# table.  Do not synchronise a policy for an offline entry: a stale route must
# never change a device's effective WAN membership.
tab="$(printf '\t')"
# POSIX read treats a leading tab as whitespace and would otherwise shift every
# field left for a registered MAC-only device.  Prefix just that empty first
# field with a private sentinel before splitting, then restore the empty IP.
while IFS="$tab" read -r ipx mac host_name hostname pol active smode; do
  [ "$ipx" = "__KZSC_EMPTY_IP__" ] && ipx=""
  [ -n "$mac" ] || continue
  mac_key="$(printf '%s' "$mac" | tr '[:upper:]' '[:lower:]')"
  grep -Fqx "$mac_key" "$seen" && continue

  name="$host_name"
  [ -n "$name" ] || name="$hostname"
  [ -n "$name" ] || name="$ipx"
  [ -n "$name" ] || name="$mac"
  dpi_mode="$(kzsc_dpi_device_mode "$mac")"
  static_ip="$(kzsc_dpi_static_ip "$mac")"

  if [ "$smode" = "extender" ]; then
    role="extender"; ifc=""; isp=""; conf="high"; method="keenetic-extender"
  else
    role="client"
    det="$(detect_client_wan "$ipx" "$mac")"
    ifc="${det%%|*}"; rest="${det#*|}"; conf="${rest%%|*}"
    rest="${rest#*|}"; method="${rest%%|*}"; dpol="${rest#*|}"
    [ -n "$dpol" ] && pol="$dpol"
    isp=""
    [ -n "$ifc" ] && isp="$(isp_label "$ifc")"
  fi
  append_client "$name" "$ipx" "$mac" offline "$role" "$pol" "$ifc" "$isp" "$conf" "$method" "$dpi_mode" "$static_ip" false true
done <<EOF
$(sed 's/^\t/__KZSC_EMPTY_IP__\t/' "$registered")
EOF

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
