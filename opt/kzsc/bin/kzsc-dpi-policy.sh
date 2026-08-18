#!/opt/bin/sh
. "${KZSC_LIB:-/opt/kzsc/bin/kzsc-lib.sh}"

ROOT="$KZSC_DPI_POLICY_DIR"
ENGROOT="$KZSC_HOME/var/dpi/engines"
OUT="$KZSC_HOME/www/data/dpi-policy.json"
mkdir -p "$ROOT/devices" "$ENGROOT" "$KZSC_HOME/www/data"

safe_id(){ printf '%s' "$1" | tr ' A-Z/:.' '_a-z___' | tr -cd 'a-z0-9_-'; }
wan_dir(){ printf '%s/%s' "$ROOT/wans" "$(safe_id "$1")"; }
mode_file(){ printf '%s/mode' "$(wan_dir "$1")"; }
auto_file(){ printf '%s/auto-domains.txt' "$(wan_dir "$1")"; }
exclude_file(){ printf '%s/exclude-domains.txt' "$(wan_dir "$1")"; }

valid_wan(){
  local wanted="$1" nd
  for nd in $(internet_wans); do [ "$nd" = "$wanted" ] && return 0; done
  return 1
}

ensure_wan(){
  local nd="$1" d
  valid_wan "$nd" || return 1
  d="$(wan_dir "$nd")"; mkdir -p "$d" || return 1
  [ -f "$d/mode" ] || printf 'all\n' >"$d/mode"
  [ -f "$d/auto-domains.txt" ] || : >"$d/auto-domains.txt"
  [ -f "$d/exclude-domains.txt" ] || : >"$d/exclude-domains.txt"
}

mode_for(){
  local nd="$1" v
  ensure_wan "$nd" >/dev/null 2>&1 || { echo all; return; }
  v="$(head -n1 "$(mode_file "$nd")" 2>/dev/null)"
  case "$v" in auto) echo auto;; *) echo all;; esac
}

# Zapret hostlists match a plain suffix against all subdomains.  Accept the
# familiar '*.gov.tr' spelling but persist it as 'gov.tr'; '^name' is exact.
normal_domain(){
  local d="$1"
  d="$(printf '%s' "$d" | tr 'A-Z' 'a-z' | tr -d '[:space:]')"
  case "$d" in \*.*) d="${d#*.}";; esac
  case "$d" in
    \^*)
      d="${d#^}"
      case "$d" in ''|.*|*..*|*[!a-z0-9.-]*|*.) return 1;; esac
      printf '^%s' "$d";;
    *)
      case "$d" in ''|.*|*..*|*[!a-z0-9.-]*|*.) return 1;; esac
      printf '%s' "$d";;
  esac
}

list_normalize(){
  local f="$1" tmp d out first=1
  [ -f "$f" ] || : >"$f"
  tmp="$f.tmp.$$"; : >"$tmp"
  while IFS= read -r d || [ -n "$d" ]; do
    d="$(normal_domain "$d")" || continue
    grep -Fqx "$d" "$tmp" 2>/dev/null || printf '%s\n' "$d" >>"$tmp"
  done <"$f"
  mv "$tmp" "$f"
}

list_add(){
  local nd="$1" kind="$2" raw="$3" f d
  ensure_wan "$nd" || { echo "WAN bulunamadı: $nd" >&2; return 1; }
  case "$kind" in auto) f="$(auto_file "$nd")";; exclude) f="$(exclude_file "$nd")";; *) return 1;; esac
  d="$(normal_domain "$raw")" || { echo 'Geçersiz alan adı.' >&2; return 1; }
  grep -Fqx "$d" "$f" 2>/dev/null || printf '%s\n' "$d" >>"$f"
  list_normalize "$f"
}

list_remove(){
  local nd="$1" kind="$2" raw="$3" f d tmp
  ensure_wan "$nd" || { echo "WAN bulunamadı: $nd" >&2; return 1; }
  case "$kind" in auto) f="$(auto_file "$nd")";; exclude) f="$(exclude_file "$nd")";; *) return 1;; esac
  d="$(normal_domain "$raw")" || { echo 'Geçersiz alan adı.' >&2; return 1; }
  tmp="$f.tmp.$$"; grep -Fvx "$d" "$f" >"$tmp" 2>/dev/null || true; mv "$tmp" "$f"
}

set_mode(){
  local nd="$1" mode="$2"
  ensure_wan "$nd" || { echo "WAN bulunamadı: $nd" >&2; return 1; }
  case "$mode" in all|auto) printf '%s\n' "$mode" >"$(mode_file "$nd")";; *) echo 'Geçersiz DPI modu.' >&2; return 1;; esac
}

valid_mac(){ case "$1" in [0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]) return 0;; *) return 1;; esac; }
device_file(){ printf '%s/devices/%s.mode' "$ROOT" "$(printf '%s' "$1" | tr 'A-F' 'a-f' | tr -cd 'a-f0-9')"; }
static_file(){ printf '%s/devices/%s.static-ip' "$ROOT" "$(printf '%s' "$1" | tr 'A-F' 'a-f' | tr -cd 'a-f0-9')"; }
set_device(){
  local mac="$1" mode="$2" f
  valid_mac "$mac" || { echo 'Geçersiz MAC adresi.' >&2; return 1; }
  f="$(device_file "$mac")"
  case "$mode" in enabled) rm -f "$f";; disabled) printf 'disabled\n' >"$f";; *) echo 'Geçersiz cihaz DPI durumu.' >&2; return 1;; esac
}
device_mode(){ valid_mac "$1" || { echo enabled; return; }; kzsc_dpi_device_mode "$1"; }

valid_ipv4(){
  printf '%s\n' "$1" | awk -F. 'NF==4 {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || $i<0 || $i>255) exit 1; if($1==0 || $1==127 || $1>=224 || $4==0 || $4==255) exit 1; exit 0} {exit 1}'
}

ip_in_use_by_other(){
  local wanted_ip="$1" wanted_mac="$2" ip mac
  [ -f "$KZSC_CLIENTS" ] || return 1
  sed -n 's/.*"ipv4":"\([0-9.]*\)".*"mac":"\([^"]*\)".*/\1|\2/p' "$KZSC_CLIENTS" | \
  while IFS='|' read -r ip mac; do
    [ "$ip" = "$wanted_ip" ] || continue
    [ "$(printf '%s' "$mac" | tr 'A-F' 'a-f')" = "$(printf '%s' "$wanted_mac" | tr 'A-F' 'a-f')" ] || { echo used; return 0; }
  done | grep -q used
}

set_static_ip(){
  local mac="$1" ip="$2" f lan
  valid_mac "$mac" || { echo 'Geçersiz MAC adresi.' >&2; return 1; }
  valid_ipv4 "$ip" || { echo 'Geçersiz IPv4 adresi.' >&2; return 1; }
  lan="$(detect_lan_ip | head -n1)"
  [ "$ip" != "$lan" ] || { echo 'Router LAN adresi cihaza atanamaz.' >&2; return 1; }
  ip_in_use_by_other "$ip" "$mac" && { echo 'Bu IP başka bir bağlı cihaz tarafından kullanılıyor.' >&2; return 1; }
  ndmc_cmd "ip dhcp host $mac $ip" || { echo 'Keenetic DHCP sabit IP rezervasyonu kaydedilemedi.' >&2; return 1; }
  f="$(static_file "$mac")"
  printf '%s\n' "$ip" >"$f"
}

static_for(){ valid_mac "$1" || return 0; kzsc_dpi_static_ip "$1"; }

disabled_ips_for_wan(){
  local nd="$1" ip mac mode
  [ -f "$KZSC_CLIENTS" ] || return 0
  # A device preference belongs to the LAN client, not to the route selected
  # at discovery time.  Install it in every interface-scoped WAN chain so it
  # survives failover/load-balancing and incomplete client-to-WAN mapping.
  sed -n 's/.*"ipv4":"\([0-9.]*\)".*"mac":"\([^"]*\)".*/\1|\2/p' "$KZSC_CLIENTS" | \
  while IFS='|' read -r ip mac; do
    mode="$(device_mode "$mac")"
    [ "$mode" = disabled ] && printf '%s\n' "$ip"
  done
}

write_json(){
  local tmp body first=1 count=0 nd d mode af ef auto excl aid label
  /opt/kzsc/bin/kzsc-wan-registry.sh refresh >/dev/null 2>&1 || true
  tmp="$OUT.tmp.$$"; body="$ROOT/.json.$$"; : >"$body"
  for nd in $(internet_wans); do
    ensure_wan "$nd" >/dev/null 2>&1 || continue
    d="$(wan_dir "$nd")"; mode="$(mode_for "$nd")"; af="$(auto_file "$nd")"; ef="$(exclude_file "$nd")"
    auto="$(tr '\n' ' ' <"$af" 2>/dev/null | sed 's/[[:space:]]*$//')"
    excl="$(tr '\n' ' ' <"$ef" 2>/dev/null | sed 's/[[:space:]]*$//')"
    [ "$first" -eq 1 ] || printf ',' >>"$body"; first=0; count=$((count+1)); aid="$(safe_id "$nd")"
    label="$(isp_label "$nd")"; [ -n "$label" ] || label="$nd"
    printf '{"id":"%s","ndmc":"%s","label":"%s","mode":"%s","auto_domains":"%s","exclude_domains":"%s"}' \
      "$(json_escape "$aid")" "$(json_escape "$nd")" "$(json_escape "$label")" "$(json_escape "$mode")" "$(json_escape "$auto")" "$(json_escape "$excl")" >>"$body"
  done
  printf '{"count":%s,"wans":[%s]}' "$count" "$(cat "$body")" >"$tmp"
  mv "$tmp" "$OUT"; rm -f "$body"; chmod 644 "$OUT" 2>/dev/null || true; cat "$OUT"
}

case "$1" in
  init|refresh) for _nd in $(internet_wans); do ensure_wan "$_nd" >/dev/null 2>&1 || true; done; write_json ;;
  json|status) write_json ;;
  mode) set_mode "$2" "$3" ;;
  get-mode) mode_for "$2" ;;
  add) list_add "$2" "$3" "$4" ;;
  remove) list_remove "$2" "$3" "$4" ;;
  device) set_device "$2" "$3" ;;
  device-mode) device_mode "$2" ;;
  static) set_static_ip "$2" "$3" ;;
  static-get) static_for "$2" ;;
  disabled-ips) disabled_ips_for_wan "$2" ;;
  *) echo 'Usage: kzsc-dpi-policy {init|json|get-mode WAN|mode WAN all|auto|add WAN auto|exclude DOMAIN|remove WAN auto|exclude DOMAIN|device MAC enabled|disabled|static MAC IP|static-get MAC|disabled-ips WAN}' >&2; exit 1;;
esac
