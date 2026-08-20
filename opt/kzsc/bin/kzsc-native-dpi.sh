#!/opt/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# IPv6 strategy normalization is adapted from upstream-compatible; see
# THIRD_PARTY_NOTICES.md. KZSC-specific multi-WAN integration is maintained
# in this file.
. "${KZSC_LIB:-/opt/kzsc/bin/kzsc-lib.sh}"

ROOT="$KZSC_HOME/var/dpi/engines"
REG="$KZSC_HOME/var/dpi/wan-registry"
ZROOT="$KZSC_HOME/zapret2"
PRESET="$KZSC_HOME/share/dpi-presets"
AUTO_PRESET="$KZSC_HOME/var/dpi/auto-presets"
IPV6_STATE="$KZSC_HOME/var/dpi/ipv6-enabled"
PAUSE_STATE="$KZSC_HOME/var/dpi/engines-paused"
mkdir -p "$AUTO_PRESET"
LOGROOT="$KZSC_HOME/var/log"
mkdir -p "$ROOT" "$REG" "$LOGROOT"

safe_id(){ local v="$1"; printf '%s' "$v" | tr ' A-Z/:.' '_a-z___' | tr -cd 'a-z0-9_-'; }
edir(){ local nd="$1"; echo "$ROOT/$(safe_id "$nd")"; }
qfile(){ local nd="$1"; echo "$REG/$(safe_id "$nd").queue"; }
pfile(){ local nd="$1"; echo "$REG/$(safe_id "$nd").profile"; }
policy_mode(){ /opt/kzsc/bin/kzsc-dpi-policy.sh get-mode "$1" 2>/dev/null || echo all; }
policy_auto_file(){ echo "$KZSC_DPI_POLICY_DIR/wans/$(safe_id "$1")/auto-domains.txt"; }
policy_exclude_file(){ echo "$KZSC_DPI_POLICY_DIR/wans/$(safe_id "$1")/exclude-domains.txt"; }
policy_cmd(){
  if [ -n "${KZSC_DPI_POLICY_BIN:-}" ]; then
    sh "$KZSC_DPI_POLICY_BIN" "$@"
  else
    /opt/kzsc/bin/kzsc-dpi-policy.sh "$@"
  fi
}

queue_for(){ local nd="$1"; head -n1 "$(qfile "$nd")" 2>/dev/null; }
profile_for(){ local nd="$1"; head -n1 "$(pfile "$nd")" 2>/dev/null; }

valid_profile(){
  case "$1" in
    kablonet|sol|tt-fiber|vodafone|vodafone-tt|vodafone-tt2) [ -f "$PRESET/$1.conf" ] && return 0 || return 1;;
    auto_*) [ -f "$AUTO_PRESET/$1.conf" ] && return 0 || return 1;;
    *) return 1;;
  esac
}

preset_field(){
  local profile="$1" key="$2" f
  case "$profile" in auto_*) f="$AUTO_PRESET/$profile.conf";; *) f="$PRESET/$profile.conf";; esac
  [ -f "$f" ] || return 1
  # Accept presets assembled on Windows as well as native LF files.
  sed 's/\r$//' "$f" | sed -n "s/^${key}=\"\(.*\)\"$/\1/p" | head -n1
}

proc_cmdline(){
  local p="$1"
  [ -r "/proc/$p/cmdline" ] || return 1
  tr '\000' ' ' <"/proc/$p/cmdline"
}

pid_alive(){
  local nd="$1" d p q cmd
  d="$(edir "$nd")"
  p="$(cat "$d/pid" 2>/dev/null)"
  q="$(queue_for "$nd")"
  [ -n "$p" ] && [ -n "$q" ] || return 1
  kill -0 "$p" 2>/dev/null || return 1
  cmd="$(proc_cmdline "$p")"
  printf '%s\n' "$cmd" | grep -q "$ZROOT/nfq2/nfqws2" || return 1
  printf '%s\n' "$cmd" | grep -q -- "--qnum=$q" || return 1
}

external_queue_on_iface(){
  local ifc="$1"
  iptables-save -t mangle 2>/dev/null | awk -v i="$ifc" '
    (index($0,"-i " i " ") || index($0,"-o " i " ")) && index($0,"-j NFQUEUE") {
      for(n=1;n<=NF;n++) if($n=="--queue-num"){print $(n+1); exit}
    }'
}

load_netfilter_modules(){
  local mod mf k
  for mod in xt_multiport xt_connbytes xt_NFQUEUE; do
    lsmod 2>/dev/null | awk -v m="$mod" '$1==m {found=1} END{exit !found}' && continue
    mf="/lib/modules/$(uname -r 2>/dev/null)/$mod.ko"
    [ -f "$mf" ] || mf="/lib/modules/$(uname -r 2>/dev/null)/kernel/net/netfilter/$mod.ko"
    [ -f "$mf" ] && [ -x /opt/sbin/insmod ] && /opt/sbin/insmod "$mf" >/dev/null 2>&1 || true
  done
}

ensure_zapret_lua_permissions(){
  local lua="$ZROOT/lua"
  [ -d "$lua" ] || return 1
  # nfqws2 drops to nobody before loading Lua.  Keep the payload files
  # readable and every parent directory traversable after package restores.
  chmod a+rx "$KZSC_HOME" "$ZROOT" "$lua" 2>/dev/null || true
  find "$lua" -type d -exec chmod a+rx {} \; 2>/dev/null || true
  find "$lua" -type f -exec chmod a+r {} \; 2>/dev/null || true
  [ -r "$lua/zapret-lib.lua" ] || [ -r "$lua/zapret-lib.lua.gz" ]
}

chain_in(){ local q="$1"; echo "KZSC${q}I"; }
chain_out(){ local q="$1"; echo "KZSC${q}O"; }
chain_quic(){ local q="$1"; echo "KZSC${q}Q"; }


rule_add(){
  local table="$1"; shift
  iptables -t "$table" -C "$@" >/dev/null 2>&1 && return 0
  if ! iptables -t "$table" -A "$@"; then
    echo "iptables kuralı eklenemedi: table=$table chain=$1 rule=$*" >&2
    echo "iptables yetenekleri: multiport=$(iptables -m multiport -h >/dev/null 2>&1; echo $?) connbytes=$(iptables -m connbytes -h >/dev/null 2>&1; echo $?) nfqueue=$(iptables -j NFQUEUE -h >/dev/null 2>&1; echo $?)" >&2
    return 1
  fi
}
rule_insert(){
  local table="$1" chain="$2" pos="$3"
  shift 3

  # -I accepts an insertion position, but -C does not. Check the rule body
  # without the numeric position so daemon ensure remains idempotent.
  iptables -t "$table" -C "$chain" "$@" >/dev/null 2>&1 && return 0
  iptables -t "$table" -I "$chain" "$pos" "$@"
}
rule_del(){
  local table="$1"; shift
  while iptables -t "$table" -C "$@" >/dev/null 2>&1; do
    iptables -t "$table" -D "$@" >/dev/null 2>&1 || break
  done
}

IPV6_WAN_STATE_DIR="$KZSC_HOME/var/dpi/ipv6-wan"
ipv6_enabled(){ [ -f "$IPV6_STATE" ] && [ "$(cat "$IPV6_STATE" 2>/dev/null)" = 1 ]; }
ipv6_wan_key(){ printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_'; }
ipv6_wan_marker(){ printf '%s/%s.enabled' "$IPV6_WAN_STATE_DIR" "$(ipv6_wan_key "$1")"; }
ipv6_wan_enabled(){ ipv6_enabled && [ -f "$(ipv6_wan_marker "$1")" ]; }
ipv6_wan_mark(){ mkdir -p "$IPV6_WAN_STATE_DIR" && printf '1\n' >"$(ipv6_wan_marker "$1")"; }
ipv6_wan_unmark(){ rm -f "$(ipv6_wan_marker "$1")"; }
ipv6_wan_clear(){ rm -f "$IPV6_WAN_STATE_DIR"/*.enabled 2>/dev/null || true; }
ipv6_wan_any(){
  local nd
  for nd in $(internet_wans); do
    ipv6_wan_enabled "$nd" && return 0
  done
  return 1
}
ip6_rule_add(){
  command -v ip6tables >/dev/null 2>&1 || return 1
  local table="$1"; shift
  ip6tables -t "$table" -C "$@" >/dev/null 2>&1 && return 0
  ip6tables -t "$table" -A "$@"
}
ip6_rule_del(){
  command -v ip6tables >/dev/null 2>&1 || return 0
  local table="$1"; shift
  while ip6tables -t "$table" -C "$@" >/dev/null 2>&1; do ip6tables -t "$table" -D "$@" >/dev/null 2>&1 || break; done
}
ip6_filter_rule_add(){
  command -v ip6tables >/dev/null 2>&1 || return 1
  ip6tables -t filter -C "$@" >/dev/null 2>&1 && return 0
  ip6tables -t filter -A "$@"
}
ip6_filter_rule_del(){
  command -v ip6tables >/dev/null 2>&1 || return 0
  while ip6tables -t filter -C "$@" >/dev/null 2>&1; do
    ip6tables -t filter -D "$@" >/dev/null 2>&1 || break
  done
}
ip6_chain_ensure(){
  command -v ip6tables >/dev/null 2>&1 || return 1
  local c="$1"
  ip6tables -t mangle -N "$c" >/dev/null 2>&1 || true
  ip6tables -t mangle -F "$c" >/dev/null 2>&1 || return 1
}
ip6_chain_remove(){ command -v ip6tables >/dev/null 2>&1 || return 0; ip6tables -t mangle -F "$1" >/dev/null 2>&1 || true; ip6tables -t mangle -X "$1" >/dev/null 2>&1 || true; }

# ip6tables may exist while the kernel lacks one of the extensions used by the
# IPv6 datapath.  Probe an unhooked temporary chain before changing the live
# WAN rules.  This is intentionally a real append/delete operation, not only
# a command-help check: multiport, connbytes and NFQUEUE must all be accepted
# by the running Keenetic kernel.
ipv6_runtime_probe(){
  local c rc
  command -v ip6tables >/dev/null 2>&1 || return 1
  load_netfilter_modules
  c="KZSC6P$$"
  ip6tables -t mangle -N "$c" >/dev/null 2>&1 || {
    ip6tables -t mangle -F "$c" >/dev/null 2>&1 || return 1
  }
  ip6tables -t mangle -F "$c" >/dev/null 2>&1 || {
    ip6tables -t mangle -X "$c" >/dev/null 2>&1 || true
    return 1
  }
  rc=0
  ip6tables -t mangle -A "$c" -p tcp -m multiport --dports 80,443 \
    -m connbytes --connbytes 1:20 --connbytes-mode packets --connbytes-dir original \
    -j NFQUEUE --queue-num 0 --queue-bypass >/dev/null 2>&1 || rc=1
  if [ "$rc" -eq 0 ]; then
    ip6tables -t mangle -A "$c" -p udp --dport 443 \
      -m connbytes --connbytes 1:5 --connbytes-mode packets --connbytes-dir original \
      -j NFQUEUE --queue-num 0 --queue-bypass >/dev/null 2>&1 || rc=1
  fi
  ip6tables -t mangle -F "$c" >/dev/null 2>&1 || rc=1
  ip6tables -t mangle -X "$c" >/dev/null 2>&1 || rc=1
  return "$rc"
}

# A kernel accepting ip6tables syntax is not proof that IPv6 still reaches the
# Internet once the live NFQUEUE path is attached. Test a normal HTTPS request
# over each enabled WAN before and after an IPv6 transition. A secondary PPP
# WAN does not necessarily have its own entry in the main IPv6 default-route
# table: Keenetic policy routing can still carry traffic bound to that PPP
# interface. Therefore the decisive test is a global address plus a successful
# `curl -6 --interface` transaction, not a `default ... dev IFACE` text match.
# This follows the working upstream approach of treating live IPv6
# reachability as capability while keeping the IPv4 datapath independent.
ipv6_iface_has_global_addr(){
  local ifc
  ifc="$1"
  [ -n "$ifc" ] || return 1
  ip -6 addr show dev "$ifc" 2>/dev/null | awk '
    $1 == "inet6" && $0 ~ /[[:space:]]scope[[:space:]]global([[:space:]]|$)/ {found=1}
    END {exit(found ? 0 : 1)}
  '
}

ipv6_https_probe_iface(){
  local ifc
  ifc="$1"
  [ -n "$ifc" ] || return 1
  command -v curl >/dev/null 2>&1 || return 1
  ipv6_iface_has_global_addr "$ifc" || return 1
  # Do not make availability depend on a single endpoint. Either independent
  # HTTPS endpoint proves that the WAN can still carry ordinary IPv6 traffic.
  for url in \
    'https://one.one.one.one/cdn-cgi/trace' \
    'https://www.google.com/generate_204'; do
    # Any HTTP response proves that DNS, TCP, TLS, and IPv6 routing worked;
    # a provider endpoint may legitimately answer HEAD/GET with 4xx.
    curl -6 -sS --interface "$ifc" --connect-timeout 4 --max-time 12 \
      "$url" >/dev/null 2>&1 && return 0
  done
  return 1
}

ipv6_https_probe_enabled(){
  local nd ifc found=0 capable=0
  for nd in $(internet_wans); do
    [ -f "$(edir "$nd")/enabled" ] || continue
    found=1
    ifc="$(linux_if_for_ndmc "$nd")"
    if ipv6_https_probe_iface "$ifc"; then
      capable=1
    else
      echo "IPv6 HTTPS çalışma testi başarısız: $nd/${ifc:-bilinmiyor}" >&2
    fi
  done
  # IPv6 is a per-WAN capability. At least one enabled WAN must pass, while a
  # secondary WAN without an IPv6 route remains IPv4-only.
  [ "$found" -eq 0 ] || [ "$capable" -eq 1 ]
}

rule_keep_one(){
  local table="$1" chain="$2"
  shift 2
  local count=0

  # Delete all duplicates, then add exactly one. This is used only for
  # deterministic KZSC-owned fallback rules.
  while iptables -t "$table" -C "$chain" "$@" >/dev/null 2>&1; do
    iptables -t "$table" -D "$chain" "$@" >/dev/null 2>&1 || break
    count=$((count+1))
  done
  iptables -t "$table" -I "$chain" 1 "$@"
}

chain_ensure(){
  local c="$1"
  iptables -t mangle -N "$c" >/dev/null 2>&1 || true
  iptables -t mangle -F "$c" >/dev/null 2>&1 || return 1
}
chain_remove(){
  local c="$1"
  iptables -t mangle -F "$c" >/dev/null 2>&1 || true
  iptables -t mangle -X "$c" >/dev/null 2>&1 || true
}
filter_chain_ensure(){
  local c="$1"
  iptables -t filter -N "$c" >/dev/null 2>&1 || true
  iptables -t filter -F "$c" >/dev/null 2>&1 || return 1
}
filter_chain_remove(){
  local c="$1"
  iptables -t filter -F "$c" >/dev/null 2>&1 || true
  iptables -t filter -X "$c" >/dev/null 2>&1 || true
}

device_filter_signature(){
  policy_cmd disabled-ips "$1" 2>/dev/null | sort -u | tr '\n' ' '
}

device_exclude_rules(){
  local nd="$1" cin="$2" cout="$3" ip
  # A disabled LAN device must bypass the queue in both directions.
  for ip in $(policy_cmd disabled-ips "$nd" 2>/dev/null); do
    case "$ip" in *[!0-9.]*|'') continue;; esac
    rule_add mangle "$cin" -d "$ip" -j RETURN || return 1
    rule_add mangle "$cout" -s "$ip" -j RETURN || return 1
  done
}

quic_filter_rules(){
  local nd="$1" chain="$2" ip
  filter_chain_ensure "$chain" || return 1
  # RETURN continues through Keenetic's normal filter rules; it bypasses only
  # KZSC's TCP-fallback rejection and does not grant a blanket firewall ACCEPT.
  for ip in $(policy_cmd disabled-ips "$nd" 2>/dev/null); do
    case "$ip" in *[!0-9.]*|'') continue;; esac
    rule_add filter "$chain" -s "$ip" -j RETURN || return 1
  done
  rule_add filter "$chain" -j REJECT || return 1
}

device_excludes_ok(){
  local nd="$1" cin="$2" cout="$3" cquic="$4" no_udp="$5" ip
  for ip in $(policy_cmd disabled-ips "$nd" 2>/dev/null); do
    case "$ip" in *[!0-9.]*|'') continue;; esac
    iptables -t mangle -C "$cin" -d "$ip" -j RETURN 2>/dev/null || return 1
    iptables -t mangle -C "$cout" -s "$ip" -j RETURN 2>/dev/null || return 1
    if [ "$no_udp" = 1 ]; then
      iptables -t filter -C "$cquic" -s "$ip" -j RETURN 2>/dev/null || return 1
    fi
  done
}

rules_add(){
  local nd="$1" ifc q profile cin cout cquic no_udp d
  ifc="$(linux_if_for_ndmc "$nd")"
  q="$(queue_for "$nd")"
  profile="$(profile_for "$nd")"
  [ -n "$ifc" ] && [ -n "$q" ] && valid_profile "$profile" || return 1

  cin="$(chain_in "$q")"
  cout="$(chain_out "$q")"
  cquic="$(chain_quic "$q")"
  no_udp="$(preset_field "$profile" NO_UDP)"
  chain_ensure "$cin" || return 1
  chain_ensure "$cout" || return 1
  device_exclude_rules "$nd" "$cin" "$cout" || return 1

  # Return packets: enough early packets for retrans/auto analysis.
  rule_add mangle "$cin" -p tcp -m multiport --sports 80,443 \
    -m connbytes --connbytes 1:10 --connbytes-mode packets --connbytes-dir reply \
    -j NFQUEUE --queue-num "$q" --queue-bypass || return 1

  # Outgoing HTTP/TLS.
  rule_add mangle "$cout" -p tcp -m multiport --dports 80,443 \
    -m mark ! --mark 0x40000000/0x40000000 \
    -m connbytes --connbytes 1:20 --connbytes-mode packets --connbytes-dir original \
    -j NFQUEUE --queue-num "$q" --queue-bypass || return 1

  if [ "$no_udp" != 1 ]; then
    rule_add mangle "$cin" -p udp --sport 443 \
      -m connbytes --connbytes 1:3 --connbytes-mode packets --connbytes-dir reply \
      -j NFQUEUE --queue-num "$q" --queue-bypass || return 1
    rule_add mangle "$cout" -p udp --dport 443 \
      -m mark ! --mark 0x40000000/0x40000000 \
      -m connbytes --connbytes 1:5 --connbytes-mode packets --connbytes-dir original \
      -j NFQUEUE --queue-num "$q" --queue-bypass || return 1
  fi

  # Hooks are interface scoped, so each WAN owns only its own traffic.
  rule_add mangle INPUT -i "$ifc" -j "$cin" || return 1
  rule_add mangle FORWARD -i "$ifc" -j "$cin" || return 1
  rule_add mangle POSTROUTING -o "$ifc" -j "$cout" || return 1

  if ipv6_wan_enabled "$nd"; then
    command -v ip6tables >/dev/null 2>&1 || { echo 'IPv6 etkin ancak ip6tables bulunamadı.' >&2; return 1; }
    ip6_chain_ensure "$cin" || return 1
    ip6_chain_ensure "$cout" || return 1
    ip6_rule_add mangle "$cin" -p tcp -m multiport --sports 80,443 -m connbytes --connbytes 1:10 --connbytes-mode packets --connbytes-dir reply -j NFQUEUE --queue-num "$q" --queue-bypass || return 1
    ip6_rule_add mangle "$cout" -p tcp -m multiport --dports 80,443 -m mark ! --mark 0x40000000/0x40000000 -m connbytes --connbytes 1:20 --connbytes-mode packets --connbytes-dir original -j NFQUEUE --queue-num "$q" --queue-bypass || return 1
    if [ "$no_udp" != 1 ]; then
      ip6_rule_add mangle "$cin" -p udp --sport 443 -m connbytes --connbytes 1:3 --connbytes-mode packets --connbytes-dir reply -j NFQUEUE --queue-num "$q" --queue-bypass || return 1
      ip6_rule_add mangle "$cout" -p udp --dport 443 -m mark ! --mark 0x40000000/0x40000000 -m connbytes --connbytes 1:5 --connbytes-mode packets --connbytes-dir original -j NFQUEUE --queue-num "$q" --queue-bypass || return 1
    fi
    ip6_rule_add mangle INPUT -i "$ifc" -j "$cin" || return 1
    ip6_rule_add mangle FORWARD -i "$ifc" -j "$cin" || return 1
    ip6_rule_add mangle POSTROUTING -o "$ifc" -j "$cout" || return 1
    if [ "$no_udp" = 1 ]; then
      # Keep TCP-only presets equivalent on IPv4 and IPv6. Otherwise browsers
      # can keep using HTTP/3 over IPv6 and bypass the TLS strategy.
      ip6_filter_rule_add FORWARD -o "$ifc" -p udp --dport 443 -j REJECT || return 1
      ip6_filter_rule_add OUTPUT -o "$ifc" -p udp --dport 443 -j REJECT || return 1
    else
      ip6_filter_rule_del FORWARD -o "$ifc" -p udp --dport 443 -j REJECT
      ip6_filter_rule_del OUTPUT -o "$ifc" -p udp --dport 443 -j REJECT
    fi
  fi

  # Remove the pre-v0.11.2.22 direct fallback before installing the
  # device-aware chain; otherwise it would still reject excluded clients.
  rule_del filter FORWARD -o "$ifc" -p udp --dport 443 -j REJECT
  if [ "$no_udp" = 1 ]; then
    # Force client/router QUIC to TCP fallback for TCP-only profiles.
    quic_filter_rules "$nd" "$cquic" || return 1
    rule_insert filter FORWARD 1 -o "$ifc" -p udp --dport 443 -j "$cquic" || return 1
    rule_insert filter OUTPUT 1 -o "$ifc" -p udp --dport 443 -j REJECT || return 1
  else
    rule_del filter FORWARD -o "$ifc" -p udp --dport 443 -j "$cquic"
    rule_del filter OUTPUT -o "$ifc" -p udp --dport 443 -j REJECT
    filter_chain_remove "$cquic"
  fi
  d="$(edir "$nd")"
  device_filter_signature "$nd" >"$d/device-filter.signature"
}

rules_del(){
  local nd="$1" ifc q profile cin cout cquic no_udp
  ifc="$(linux_if_for_ndmc "$nd")"
  q="$(queue_for "$nd")"
  profile="$(profile_for "$nd")"
  [ -n "$ifc" ] && [ -n "$q" ] || return 0

  cin="$(chain_in "$q")"
  cout="$(chain_out "$q")"
  cquic="$(chain_quic "$q")"
  no_udp="$(preset_field "$profile" NO_UDP 2>/dev/null)"

  rule_del mangle INPUT -i "$ifc" -j "$cin"
  rule_del mangle FORWARD -i "$ifc" -j "$cin"
  rule_del mangle POSTROUTING -o "$ifc" -j "$cout"

  rule_del filter FORWARD -o "$ifc" -p udp --dport 443 -j "$cquic"
  # Remove the legacy direct rule as well when upgrading from older releases.
  rule_del filter FORWARD -o "$ifc" -p udp --dport 443 -j REJECT
  rule_del filter OUTPUT -o "$ifc" -p udp --dport 443 -j REJECT
  filter_chain_remove "$cquic"

  chain_remove "$cin"
  chain_remove "$cout"
  if command -v ip6tables >/dev/null 2>&1; then
    ip6_rule_del mangle INPUT -i "$ifc" -j "$cin"
    ip6_rule_del mangle FORWARD -i "$ifc" -j "$cin"
    ip6_rule_del mangle POSTROUTING -o "$ifc" -j "$cout"
    ip6_filter_rule_del FORWARD -o "$ifc" -p udp --dport 443 -j REJECT
    ip6_filter_rule_del OUTPUT -o "$ifc" -p udp --dport 443 -j REJECT
    ip6_chain_remove "$cin"
    ip6_chain_remove "$cout"
  fi
}

append_tokens(){
  local value="$1" x
  for x in $value; do [ -n "$x" ] && printf '%s\n' "$x"; done
}

auto_filter_opts(){
  local nd="$1" af ef
  af="$(policy_auto_file "$nd")"; ef="$(policy_exclude_file "$nd")"
  mkdir -p "${af%/*}"; [ -f "$af" ] || : >"$af"; [ -f "$ef" ] || : >"$ef"
  # The auto file is also a normal hostlist: manual entries are active
  # immediately, and nfqws appends confirmed DPI-block detections to it.
  printf '%s' "--hostlist=$af --hostlist-exclude=$ef --hostlist-auto=$af --hostlist-auto-fail-threshold=3"
}

profile_with_mode(){
  local nd="$1" opt="$2" mode extra before
  mode="$(policy_mode "$nd")"
  [ "$mode" = auto ] || { printf '%s' "$opt"; return; }
  extra="$(auto_filter_opts "$nd")"
  case " $opt " in
    *' --new '*)
      before="${opt%% --new*}"
      printf '%s %s --new' "$before" "$extra"
      ;;
    *) printf '%s %s' "$opt" "$extra";;
  esac
}

# The normalizer handles IPv4 Blockcheck/profile strategies in the same way: when
# IPv6 is enabled, ip_ttl=N must be mirrored as ip6_ttl=N inside the nfqws2
# Lua desync expression. Without this, packets reach NFQUEUE but the selected
# TTL-based strategy applies only to IPv4. Remove stale ip6_ttl values again
# for IPv4-only WANs so a mixed dual-WAN setup remains isolated per WAN.
strategy_for_wan(){
  local nd="$1" opt="$2"
  if ipv6_wan_enabled "$nd"; then
    case "$opt" in
      *:ip6_ttl=*) printf '%s' "$opt" ;;
      *) printf '%s' "$opt" | sed 's/:ip_ttl=\([0-9][0-9]*\)/:ip_ttl=\1:ip6_ttl=\1/g' ;;
    esac
  else
    printf '%s' "$opt" | sed 's/:ip6_ttl=[0-9][0-9]*//g'
  fi
}

build_args(){
  local nd="$1" d q profile http tls udp no_udp args http_args tls_args udp_args
  d="$(edir "$nd")"; mkdir -p "$d"
  q="$(queue_for "$nd")"
  profile="$(profile_for "$nd")"
  valid_profile "$profile" || { echo "Geçerli DPI profili seçilmemiş: $profile" >&2; return 1; }

  http="$(preset_field "$profile" HTTP_OPT)"
  tls="$(preset_field "$profile" TLS_OPT)"
  udp="$(preset_field "$profile" UDP_OPT)"
  no_udp="$(preset_field "$profile" NO_UDP)"
  args="$d/nfqws2.args"
  : >"$args"

  cat >>"$args" <<EOF
--user=nobody
--fwmark=0x40000000
--bind-fix4
--lua-init=@$ZROOT/lua/zapret-lib.lua
--lua-init=@$ZROOT/lua/zapret-antidpi.lua
--lua-init=@$ZROOT/lua/zapret-auto.lua
--qnum=$q
EOF
  if ipv6_wan_enabled "$nd"; then printf '%s\n' '--bind-fix6' >>"$args"; fi

  http_args="$(strategy_for_wan "$nd" "$(profile_with_mode "$nd" "$http")")"
  tls_args="$(strategy_for_wan "$nd" "$(profile_with_mode "$nd" "$tls")")"
  append_tokens "$http_args" >>"$args"
  append_tokens "$tls_args" >>"$args"
  if [ "$no_udp" != 1 ] && [ -n "$udp" ]; then
    udp_args="$(strategy_for_wan "$nd" "$(profile_with_mode "$nd" "$udp")")"
    append_tokens "$udp_args" >>"$args"
  fi
}

start_proc(){
  local nd="$1" d args bin p tries arg
  d="$(edir "$nd")"; mkdir -p "$d"
  pid_alive "$nd" && return 0
  bin="$ZROOT/nfq2/nfqws2"
  [ -x "$bin" ] || { echo "KZSC nfqws2 hazır değil: $bin" >&2; return 1; }
  build_args "$nd" || return 1
  args="$d/nfqws2.args"

  set --
  while IFS= read -r arg; do
    [ -n "$arg" ] && set -- "$@" "$arg"
  done <"$args"

  "$bin" "$@" >>"$LOGROOT/native-$(safe_id "$nd").log" 2>&1 &
  p=$!
  echo "$p" >"$d/pid"

  tries=0
  while [ "$tries" -lt 5 ]; do
    pid_alive "$nd" && return 0
    tries=$((tries+1)); sleep 1
  done
  rm -f "$d/pid"
  echo "KZSC nfqws2 başlatılamadı: $nd" >&2
  return 1
}

stop_proc(){
  local nd="$1" d p q x cmd
  d="$(edir "$nd")"; q="$(queue_for "$nd")"
  p="$(cat "$d/pid" 2>/dev/null)"
  # Never signal a PID merely because it was persisted: after a crash or
  # reboot the number may belong to an unrelated router process.  pid_alive
  # verifies both the nfqws2 executable and its reserved queue.
  if [ -n "$p" ] && pid_alive "$nd"; then
    kill "$p" 2>/dev/null || true
    sleep 1
    pid_alive "$nd" && kill -9 "$p" 2>/dev/null || true
  fi

  # Queue number is KZSC-owned (320-399); clean orphans only for this queue/root.
  for x in $(pidof nfqws2 2>/dev/null); do
    cmd="$(proc_cmdline "$x")"
    printf '%s\n' "$cmd" | grep -q "$ZROOT/nfq2/nfqws2" || continue
    printf '%s\n' "$cmd" | grep -q -- "--qnum=$q" || continue
    kill "$x" 2>/dev/null || true
  done
  rm -f "$d/pid"
}

purge_binding(){
  local ifc="$1" q="$2" cin cout cquic x cmd
  [ -n "$ifc" ] && [ -n "$q" ] || return 0
  case "$q" in ''|*[!0-9]*) return 0;; esac
  [ "$q" -ge 320 ] 2>/dev/null && [ "$q" -le 399 ] 2>/dev/null || return 0

  cin="$(chain_in "$q")"
  cout="$(chain_out "$q")"
  cquic="$(chain_quic "$q")"

  # Remove hooks from the *recorded old Linux interface*. This is intentionally
  # independent of the current NDMC->Linux mapping, which may already have moved.
  rule_del mangle INPUT -i "$ifc" -j "$cin"
  rule_del mangle FORWARD -i "$ifc" -j "$cin"
  rule_del mangle POSTROUTING -o "$ifc" -j "$cout"
  rule_del filter FORWARD -o "$ifc" -p udp --dport 443 -j "$cquic"
  rule_del filter FORWARD -o "$ifc" -p udp --dport 443 -j REJECT
  rule_del filter OUTPUT -o "$ifc" -p udp --dport 443 -j REJECT

  chain_remove "$cin"
  chain_remove "$cout"
  filter_chain_remove "$cquic"

  if command -v ip6tables >/dev/null 2>&1; then
    ip6_rule_del mangle INPUT -i "$ifc" -j "$cin"
    ip6_rule_del mangle FORWARD -i "$ifc" -j "$cin"
    ip6_rule_del mangle POSTROUTING -o "$ifc" -j "$cout"
    ip6_filter_rule_del FORWARD -o "$ifc" -p udp --dport 443 -j REJECT
    ip6_filter_rule_del OUTPUT -o "$ifc" -p udp --dport 443 -j REJECT
    ip6_chain_remove "$cin"
    ip6_chain_remove "$cout"
  fi

  # Stop only KZSC-owned nfqws2 processes using this reserved queue.
  for x in $(pidof nfqws2 2>/dev/null); do
    cmd="$(proc_cmdline "$x")"
    printf '%s\n' "$cmd" | grep -q "$ZROOT/nfq2/nfqws2" || continue
    printf '%s\n' "$cmd" | grep -q -- "--qnum=$q" || continue
    kill "$x" 2>/dev/null || true
  done
  sleep 1
  for x in $(pidof nfqws2 2>/dev/null); do
    cmd="$(proc_cmdline "$x")"
    printf '%s\n' "$cmd" | grep -q "$ZROOT/nfq2/nfqws2" || continue
    printf '%s\n' "$cmd" | grep -q -- "--qnum=$q" || continue
    kill -9 "$x" 2>/dev/null || true
  done
}

enable(){
  local nd="$1" d ifc q existing
  d="$(edir "$nd")"; mkdir -p "$d"
  [ ! -f "$PAUSE_STATE" ] || { echo 'KZSC Zapret2 motorları genel olarak durduruldu; önce Zapret2 sekmesinden Başlat seçin.' >&2; return 1; }
  ifc="$(linux_if_for_ndmc "$nd")"
  q="$(queue_for "$nd")"
  [ -n "$ifc" ] && [ -n "$q" ] || { echo "WAN/queue hazır değil: $nd" >&2; return 1; }
  valid_profile "$(profile_for "$nd")" || { echo "$nd için DPI profili seçilmemiş." >&2; return 1; }
  [ -x "$ZROOT/nfq2/nfqws2" ] || { echo "KZSC Zapret2 kurulu değil." >&2; return 1; }
  load_netfilter_modules
  ensure_zapret_lua_permissions || { echo "KZSC Lua dosyaları okunamıyor: $ZROOT/lua" >&2; return 1; }

  # Do not attach a new IPv6 NFQUEUE engine on a WAN that cannot first prove
  # ordinary IPv6 HTTPS connectivity. This keeps the optional feature fail
  # closed and preserves the user's existing Internet path.
  if ipv6_enabled; then
    if ipv6_https_probe_iface "$ifc"; then
      ipv6_wan_mark "$nd"
    else
      ipv6_wan_unmark "$nd"
      echo "$nd için kullanılabilir IPv6 yolu yok; IPv4 DPI motoru başlatılıyor." >&2
    fi
  fi

  # Do not overlap an unrelated NFQUEUE rule on the same WAN.
  existing="$(external_queue_on_iface "$ifc")"
  if [ -n "$existing" ] && [ "$existing" != "$q" ]; then
    echo "$nd / $ifc üzerinde başka bir NFQUEUE kuyruğu aktif: $existing. KZSC motoru başlatılmadı." >&2
    return 2
  fi

  rules_del "$nd"
  stop_proc "$nd"

  start_proc "$nd" || return 1
  if ! rules_add "$nd"; then
    rules_del "$nd"
    stop_proc "$nd"
    echo "KZSC firewall kuralları eklenemedi; geri alındı." >&2
    return 1
  fi

  if ipv6_wan_enabled "$nd" && ! ipv6_https_probe_iface "$ifc"; then
    ipv6_wan_unmark "$nd"
    rules_del "$nd"
    stop_proc "$nd"
    start_proc "$nd" || return 1
    rules_add "$nd" || return 1
    echo "$nd için IPv6 yolu kayboldu; IPv4 DPI motoru ile devam ediliyor." >&2
  fi

  touch "$d/enabled"
  rm -f "$d/prepared"
  echo "$nd KZSC-native DPI motoru aktif: queue $q / profil $(profile_for "$nd")."
}

disable(){
  local nd="$1" d
  d="$(edir "$nd")"
  rm -f "$d/enabled"
  rules_del "$nd"
  stop_proc "$nd"
  touch "$d/prepared"
  echo "$nd KZSC-native DPI motoru durduruldu."
}

datapath_ok(){
  local nd="$1" ifc q cin cout cquic profile no_udp
  ifc="$(linux_if_for_ndmc "$nd")"
  q="$(queue_for "$nd")"
  [ -n "$ifc" ] && [ -n "$q" ] || return 1
  cin="$(chain_in "$q")"; cout="$(chain_out "$q")"; cquic="$(chain_quic "$q")"
  iptables -t mangle -S "$cin" 2>/dev/null | grep -q -- "--queue-num $q" || return 1
  iptables -t mangle -S "$cout" 2>/dev/null | grep -q -- "--queue-num $q" || return 1
  iptables -t mangle -C INPUT -i "$ifc" -j "$cin" 2>/dev/null || return 1
  iptables -t mangle -C FORWARD -i "$ifc" -j "$cin" 2>/dev/null || return 1
  iptables -t mangle -C POSTROUTING -o "$ifc" -j "$cout" 2>/dev/null || return 1
  profile="$(profile_for "$nd")"; no_udp="$(preset_field "$profile" NO_UDP 2>/dev/null)"
  if [ "$no_udp" = 1 ]; then
    iptables -t filter -C FORWARD -o "$ifc" -p udp --dport 443 -j "$cquic" 2>/dev/null || return 1
    iptables -t filter -S "$cquic" 2>/dev/null | grep -q -- '-j REJECT' || return 1
  fi
  device_excludes_ok "$nd" "$cin" "$cout" "$cquic" "$no_udp" || return 1
  if ipv6_wan_enabled "$nd"; then
    command -v ip6tables >/dev/null 2>&1 || return 1
    ip6tables -t mangle -S "$cin" 2>/dev/null | grep -q -- "--queue-num $q" || return 1
    ip6tables -t mangle -S "$cout" 2>/dev/null | grep -q -- "--queue-num $q" || return 1
    ip6tables -t mangle -C INPUT -i "$ifc" -j "$cin" 2>/dev/null || return 1
    ip6tables -t mangle -C FORWARD -i "$ifc" -j "$cin" 2>/dev/null || return 1
    ip6tables -t mangle -C POSTROUTING -o "$ifc" -j "$cout" 2>/dev/null || return 1
    if [ "$no_udp" = 1 ]; then
      ip6tables -t filter -C FORWARD -o "$ifc" -p udp --dport 443 -j REJECT 2>/dev/null || return 1
      ip6tables -t filter -C OUTPUT -o "$ifc" -p udp --dport 443 -j REJECT 2>/dev/null || return 1
    fi
  fi
  return 0
}

ipv6_apply(){
  local value="$1" nd ifc failed=0 active=0 capable=0
  case "$value" in 1|on|enable) value=1;; 0|off|disable) value=0;; *) echo 'IPv6 değeri on veya off olmalı.' >&2; return 2;; esac
  if [ "$value" = 1 ]; then
    if ! ipv6_runtime_probe; then
      echo 'IPv6 etkinleştirilemedi: ip6tables/multiport/connbytes/NFQUEUE çalışma testi başarısız.' >&2
      return 1
    fi
  fi
  mkdir -p "${IPV6_STATE%/*}"
  if [ "$value" = 1 ]; then
    printf '1\n' >"$IPV6_STATE"
    ipv6_wan_clear
  else
    rm -f "$IPV6_STATE"
    ipv6_wan_clear
  fi
  if [ -f "$PAUSE_STATE" ]; then
    echo "Zapret2 IPv6 $( [ "$value" = 1 ] && echo etkinleştirildi || echo devre dışı bırakıldı ) (motorlar durdurulmuş durumda)."
    return 0
  fi
  for nd in $(internet_wans); do
    [ -f "$(edir "$nd")/enabled" ] || continue
    active=1
    if [ "$value" = 1 ]; then
      ifc="$(linux_if_for_ndmc "$nd")"
      if ipv6_https_probe_iface "$ifc"; then
        ipv6_wan_mark "$nd"
        capable=1
      else
        ipv6_wan_unmark "$nd"
        echo "$nd için kullanılabilir IPv6 rotası/HTTPS yolu yok; bu WAN IPv4 DPI ile çalışacak." >&2
      fi
    fi
    # The process command line contains --bind-fix6 only when the new state
    # is active.  Rebuild both rules and process as one transaction.
    rules_del "$nd"
    stop_proc "$nd"
    if ! start_proc "$nd" || ! rules_add "$nd"; then
      failed=1
      break
    fi
  done
  if [ "$failed" -eq 0 ] && [ "$value" = 1 ] && [ "$active" -eq 1 ] && [ "$capable" -eq 0 ]; then
    failed=1
  fi
  if [ "$failed" -ne 0 ]; then
    # Never leave IPv4 rules removed or a half-installed IPv6 chain behind.
    rm -f "$IPV6_STATE"
    ipv6_wan_clear
    for nd in $(internet_wans); do
      [ -f "$(edir "$nd")/enabled" ] || continue
      rules_del "$nd"
      stop_proc "$nd"
      start_proc "$nd" >/dev/null 2>&1 || true
      rules_add "$nd" >/dev/null 2>&1 || true
    done
    echo 'IPv6 değişikliği uygulanamadı; önceki güvenli durum geri yüklendi.' >&2
    return 1
  fi
  echo "Zapret2 IPv6 $( [ "$value" = 1 ] && echo etkinleştirildi || echo devre dışı bırakıldı )."
}

ensure(){
  local nd="$1" d ifc previous current ipv6_changed=0
  d="$(edir "$nd")"
  [ -f "$d/enabled" ] || return 0
  # A user-requested global Zapret2 pause must remain paused. The daemon still
  # checks topology, but it must not silently recreate NFQUEUE rules.
  [ -f "$PAUSE_STATE" ] && return 0
  ifc="$(linux_if_for_ndmc "$nd")"
  ip link show "$ifc" >/dev/null 2>&1 || return 0
  if ipv6_enabled; then
    if ipv6_https_probe_iface "$ifc"; then
      if ! ipv6_wan_enabled "$nd"; then ipv6_wan_mark "$nd"; ipv6_changed=1; fi
    elif ipv6_wan_enabled "$nd"; then
      # IPv6 is optional per WAN. If its route disappears, rebuild only this
      # WAN with the safe IPv4 datapath and keep other IPv6-capable WANs live.
      ipv6_wan_unmark "$nd"
      ipv6_changed=1
      echo "$nd için IPv6 canlı trafik testi başarısız; bu WAN IPv4 DPI ile devam ediyor." >&2
    fi
    if [ "$ipv6_changed" -eq 1 ]; then
      rules_del "$nd"
      stop_proc "$nd"
      start_proc "$nd" >/dev/null 2>&1 || true
      rules_add "$nd" >/dev/null 2>&1 || true
    fi
    ipv6_wan_any || { rm -f "$IPV6_STATE"; ipv6_wan_clear; }
  fi

  if [ -x "$KZSC_HOME/bin/kzsc-isolation.sh" ] &&
     "$KZSC_HOME/bin/kzsc-isolation.sh" iface-isolated "$ifc"; then
    # Recover only stale isolation markers. recover-all deliberately leaves a
    # live Blockcheck owner untouched.
    "$KZSC_HOME/bin/kzsc-isolation.sh" recover-all >/dev/null 2>&1 || true
    "$KZSC_HOME/bin/kzsc-isolation.sh" iface-isolated "$ifc" && return 0
  fi

  if ! pid_alive "$nd"; then
    stop_proc "$nd"
    start_proc "$nd" || return 1
  fi

  # Process health alone is insufficient: validate the complete datapath.
  # Rebuild on missing hooks or when DHCP/client discovery changed bypassed IPs.
  previous="$(cat "$d/device-filter.signature" 2>/dev/null)"
  current="$(device_filter_signature "$nd")"
  [ "$previous" = "$current" ] && datapath_ok "$nd" || rules_add "$nd" || return 1
}

reconfigure(){
  local nd="$1" d
  d="$(edir "$nd")"
  [ -f "$d/enabled" ] || { echo "$nd için motor kapalı; ayar kaydedildi."; return 0; }
  disable "$nd" || return 1
  enable "$nd"
}

ensure_all(){
  local nd rc=0
  for nd in $(internet_wans); do ensure "$nd" || rc=1; done
  return "$rc"
}

check_one(){
  local nd="$1" d
  d="$(edir "$nd")"
  [ -f "$d/enabled" ] || { echo "$nd disabled"; return 0; }
  [ -f "$PAUSE_STATE" ] && { echo "$nd paused"; return 0; }
  pid_alive "$nd" || { echo "$nd FAIL process"; return 1; }
  datapath_ok "$nd" || { echo "$nd FAIL datapath"; return 1; }
  echo "$nd OK"
}

check_all(){
  local nd rc=0
  for nd in $(internet_wans); do check_one "$nd" || rc=1; done
  return "$rc"
}

disable_all(){
  local nd
  for nd in $(internet_wans); do disable "$nd" >/dev/null 2>&1 || true; done
}

# Pause only the live datapath while preserving each WAN's enabled marker.
# Zapret2 replacement/repair must not leave one WAN attached to an old
# nfqws2 process while another WAN is rebuilt against the new runtime.
suspend_all(){
  local nd d rc=0
  for nd in $(internet_wans); do
    d="$(edir "$nd")"
    [ -f "$d/enabled" ] || continue
    rules_del "$nd" >/dev/null 2>&1 || rc=1
    stop_proc "$nd" >/dev/null 2>&1 || rc=1
  done
  return "$rc"
}

pause_all(){
  mkdir -p "${PAUSE_STATE%/*}"
  # Mark first so the daemon cannot race this operation and reattach a rule.
  : >"$PAUSE_STATE"
  suspend_all || return 1
  echo 'KZSC Zapret2 motorları durduruldu. Kayıtlı WAN profilleri korunuyor.'
}

resume_all(){
  rm -f "$PAUSE_STATE"
  # ensure_all refreshes IPv6 capability independently for each WAN. A WAN
  # without an IPv6 route remains IPv4-only while capable WANs are restored.
  if ensure_all; then
    echo 'KZSC Zapret2 motorları yeniden başlatıldı.'
    return 0
  fi
  # Preserve an unambiguous stopped state if any WAN cannot be restored.
  : >"$PAUSE_STATE"
  suspend_all >/dev/null 2>&1 || true
  echo 'KZSC Zapret2 motorları güvenle yeniden başlatılamadı; durdurulmuş durumda bırakıldı.' >&2
  return 1
}

reconfigure_all(){
  local nd d rc=0
  for nd in $(internet_wans); do
    d="$(edir "$nd")"
    [ -f "$d/enabled" ] || continue
    reconfigure "$nd" >/dev/null 2>&1 || rc=1
  done
  return "$rc"
}

dedupe_quic(){
  local nd="$1" ifc q profile no_udp cquic
  ifc="$(linux_if_for_ndmc "$nd")"
  q="$(queue_for "$nd")"
  profile="$(profile_for "$nd")"
  [ -n "$ifc" ] && [ -n "$q" ] || return 0
  cquic="$(chain_quic "$q")"
  no_udp="$(preset_field "$profile" NO_UDP 2>/dev/null)"

  # First remove every KZSC-style fallback rule on this WAN.
  rule_del filter FORWARD -o "$ifc" -p udp --dport 443 -j REJECT
  rule_del filter FORWARD -o "$ifc" -p udp --dport 443 -j "$cquic"
  rule_del filter OUTPUT -o "$ifc" -p udp --dport 443 -j REJECT
  filter_chain_remove "$cquic"

  # Re-add exactly one per chain only for TCP-only profiles.
  if [ "$no_udp" = 1 ]; then
    quic_filter_rules "$nd" "$cquic" || return 1
    rule_insert filter FORWARD 1 -o "$ifc" -p udp --dport 443 -j "$cquic"
    rule_insert filter OUTPUT 1 -o "$ifc" -p udp --dport 443 -j REJECT
  fi
}

dedupe_all(){
  local nd
  for nd in $(internet_wans); do
    dedupe_quic "$nd" || true
  done
}


case "$1" in
  enable) enable "$2" ;;
  disable) disable "$2" ;;
  ensure) ensure "$2" ;;
  ensure-all) ensure_all ;;
  reconfigure) reconfigure "$2" ;;
  check) check_one "$2" ;;
  check-all) check_all ;;
  disable-all) disable_all ;;
  suspend-all) suspend_all ;;
  pause-all) pause_all ;;
  resume-all) resume_all ;;
  reconfigure-all) reconfigure_all ;;
  purge-binding) purge_binding "$2" "$3" ;;
  dedupe) dedupe_quic "$2" ;;
  dedupe-all) dedupe_all ;;
  ipv6) ipv6_apply "$2" ;;
  ipv6-probe) ipv6_https_probe_iface "$2" ;;
  ipv6-status) ipv6_enabled && echo enabled || echo disabled ;;
  *)
    echo "Usage: kzsc-native-dpi {enable NDMC_WAN|disable NDMC_WAN|ensure NDMC_WAN|ensure-all|reconfigure NDMC_WAN|reconfigure-all|check NDMC_WAN|check-all|disable-all|suspend-all|pause-all|resume-all|purge-binding LINUX_IF QUEUE|dedupe NDMC_WAN|dedupe-all|ipv6 on|off|status|ipv6-probe LINUX_IF}"
    exit 1
    ;;
esac

