#!/opt/bin/sh
. "${KZSC_LIB:-/opt/kzsc/bin/kzsc-lib.sh}"
mkdir -p "$KZSC_HOME/var" "$KZSC_HOME/var/run"
if ! kzsc_lock_acquire discover; then
  log "discover: lock timeout"
  [ -f "$KZSC_TOPOLOGY" ] && cat "$KZSC_TOPOLOGY"
  exit 1
fi
trap 'kzsc_lock_release discover' EXIT INT TERM
model="$(router_model)"
ver="$(keenetic_version)"
arch="$(uname -m)"
lan_iface="$(detect_lan_iface)"
lan="$(detect_lan_ip)"
wc="$(internet_wans | awk 'NF{n++}END{print n+0}')"
pppoec=0; ipoec=0; wispc=0; mappedc=0
for ifc in $(internet_wans); do
  case "$(internet_wan_kind "$ifc")" in
    pppoe) pppoec=$((pppoec+1)) ;;
    ipoe) ipoec=$((ipoec+1)) ;;
    wisp) wispc=$((wispc+1)) ;;
  esac
  [ -n "$(linux_if_for_ndmc "$ifc" 2>/dev/null)" ] && mappedc=$((mappedc+1))
done

version_out="$(ndmc_cmd 'show version')"
has_component(){
  printf '%s\n' "$version_out" | grep -Eq "(^|[,:[:space:]])$1([,[:space:]]|$)"
}

opkg=0; have opkg && opkg=1
ipsetc=0; have ipset && ipsetc=1
ndmcc=0; have ndmc && ndmcc=1
ipv6=0; [ -s /proc/net/if_inet6 ] && ipv6=1
dnstls=0; has_component dns-tls && dnstls=1
dnshttps=0; has_component dns-https && dnshttps=1
lighttpdc=0; have lighttpd && lighttpdc=1
modcgic=0; { [ -f /opt/lib/lighttpd/mod_cgi.so ] || [ -f /opt/lib/lighttpd/mod_cgi.so.0 ]; } && modcgic=1
manglec=0; iptables -t mangle -S >/dev/null 2>&1 && manglec=1
filterc=0; iptables -t filter -S >/dev/null 2>&1 && filterc=1
nfqueuec=0; iptables -j NFQUEUE -h >/dev/null 2>&1 && nfqueuec=1
queuebypassc=0; iptables -j NFQUEUE -h 2>&1 | grep -q -- '--queue-bypass' && queuebypassc=1
queue_base="${KZSC_QUEUE_BASE:-320}"; queue_max="${KZSC_QUEUE_MAX:-399}"
case "$queue_base:$queue_max" in *[!0-9:]*) queue_base=320; queue_max=399;; esac
[ "$queue_base" -le "$queue_max" ] 2>/dev/null || { queue_base=320; queue_max=399; }
queue_capacity=$((queue_max-queue_base+1))
adaptive_ok=0
[ "$wc" -gt 0 ] && [ "$wc" -eq "$mappedc" ] && [ "$wc" -le "$queue_capacity" ] && \
  [ "$opkg" -eq 1 ] && [ "$dnstls" -eq 1 ] && [ "$dnshttps" -eq 1 ] && \
  [ "$lighttpdc" -eq 1 ] && [ "$modcgic" -eq 1 ] && [ "$manglec" -eq 1 ] && \
  [ "$filterc" -eq 1 ] && [ "$nfqueuec" -eq 1 ] && [ "$queuebypassc" -eq 1 ] && adaptive_ok=1

tmp="$KZSC_TOPOLOGY.tmp.$$.$(date +%s)"
{
  printf '{\n'
  printf ' "router":{"model":"%s","keeneticos":"%s","arch":"%s","lan_iface":"%s","lan_ip":"%s"},\n' \
    "$(json_escape "$model")" "$(json_escape "$ver")" "$(json_escape "$arch")" \
    "$(json_escape "$lan_iface")" "$(json_escape "$lan")"
  printf ' "capabilities":{"adaptive_ready":%s,"opkg":%s,"ipset":%s,"ndmc":%s,"ipv6":%s,"dns_tls":%s,"dns_https":%s,"lighttpd":%s,"mod_cgi":%s,"iptables_mangle":%s,"iptables_filter":%s,"nfqueue":%s,"queue_bypass":%s,"queue_base":%s,"queue_max":%s,"queue_capacity":%s,"wan_count":%s,"wan_mapped":%s,"pppoe_count":%s,"ipoe_count":%s,"wisp_count":%s,"multi_wan":%s},\n' \
    "$adaptive_ok" "$opkg" "$ipsetc" "$ndmcc" "$ipv6" "$dnstls" "$dnshttps" \
    "$lighttpdc" "$modcgic" "$manglec" "$filterc" "$nfqueuec" "$queuebypassc" \
    "$queue_base" "$queue_max" "$queue_capacity" "$wc" "$mappedc" "$pppoec" "$ipoec" "$wispc" \
    "$([ "$wc" -gt 1 ] && echo 1 || echo 0)"
  printf ' "wans":[\n'
  first=1
  for ifc in $(internet_wans); do
    [ "$first" -eq 1 ] || printf ',\n'
    first=0
    printf '  {"iface":"%s","linux_iface":"%s","kind":"%s","type":"%s","isp":"%s","ipv4":"%s","state":"%s","defaultgw":"%s","priority":"%s"}' \
      "$(json_escape "$ifc")" "$(json_escape "$(linux_if_for_ndmc "$ifc")")" \
      "$(json_escape "$(internet_wan_kind "$ifc")")" "$(json_escape "$(iface_type "$ifc")")" \
      "$(json_escape "$(isp_label "$ifc")")" "$(json_escape "$(iface_address "$ifc")")" \
      "$(json_escape "$(iface_state "$ifc")")" "$(json_escape "$(iface_defaultgw "$ifc")")" \
      "$(json_escape "$(iface_priority "$ifc")")"
  done
  printf '\n ],\n'
  printf ' "dpi":{"zapret2":"%s"}\n' "$(zapret_status)"
  printf '}\n'
} > "$tmp"
mv "$tmp" "$KZSC_TOPOLOGY"
cat "$KZSC_TOPOLOGY"
