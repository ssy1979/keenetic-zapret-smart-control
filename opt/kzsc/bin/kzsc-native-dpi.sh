#!/opt/bin/sh
. "${KZSC_LIB:-/opt/kzsc/bin/kzsc-lib.sh}"

ROOT="$KZSC_HOME/var/dpi/engines"
REG="$KZSC_HOME/var/dpi/wan-registry"
ZROOT="$KZSC_HOME/zapret2"
PRESET="$KZSC_HOME/share/dpi-presets"
AUTO_PRESET="$KZSC_HOME/var/dpi/auto-presets"
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
    tt|sol|kablonet) return 0;;
    auto_*) [ -f "$AUTO_PRESET/$1.conf" ] && return 0 || return 1;;
    *) return 1;;
  esac
}

preset_field(){
  local profile="$1" key="$2" f
  case "$profile" in auto_*) f="$AUTO_PRESET/$profile.conf";; *) f="$PRESET/$profile.conf";; esac
  [ -f "$f" ] || return 1
  sed -n "s/^${key}=\"\(.*\)\"$/\1/p" "$f" | head -n1
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

chain_in(){ local q="$1"; echo "KZSC${q}I"; }
chain_out(){ local q="$1"; echo "KZSC${q}O"; }
chain_quic(){ local q="$1"; echo "KZSC${q}Q"; }


rule_add(){
  local table="$1"; shift
  iptables -t "$table" -C "$@" >/dev/null 2>&1 && return 0
  iptables -t "$table" -A "$@"
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

  http_args="$(profile_with_mode "$nd" "$http")"
  tls_args="$(profile_with_mode "$nd" "$tls")"
  append_tokens "$http_args" >>"$args"
  append_tokens "$tls_args" >>"$args"
  if [ "$no_udp" != 1 ] && [ -n "$udp" ]; then
    udp_args="$(profile_with_mode "$nd" "$udp")"
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
  [ -n "$p" ] && kill "$p" 2>/dev/null || true
  sleep 1
  [ -n "$p" ] && kill -0 "$p" 2>/dev/null && kill -9 "$p" 2>/dev/null || true

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
  ifc="$(linux_if_for_ndmc "$nd")"
  q="$(queue_for "$nd")"
  [ -n "$ifc" ] && [ -n "$q" ] || { echo "WAN/queue hazır değil: $nd" >&2; return 1; }
  valid_profile "$(profile_for "$nd")" || { echo "$nd için DPI profili seçilmemiş." >&2; return 1; }
  [ -x "$ZROOT/nfq2/nfqws2" ] || { echo "KZSC Zapret2 kurulu değil." >&2; return 1; }

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
  return 0
}

ensure(){
  local nd="$1" d ifc previous current
  d="$(edir "$nd")"
  [ -f "$d/enabled" ] || return 0
  ifc="$(linux_if_for_ndmc "$nd")"
  ip link show "$ifc" >/dev/null 2>&1 || return 0

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
  purge-binding) purge_binding "$2" "$3" ;;
  dedupe) dedupe_quic "$2" ;;
  dedupe-all) dedupe_all ;;
  *)
    echo "Usage: kzsc-native-dpi {enable NDMC_WAN|disable NDMC_WAN|ensure NDMC_WAN|ensure-all|reconfigure NDMC_WAN|check NDMC_WAN|check-all|disable-all|purge-binding LINUX_IF QUEUE|dedupe NDMC_WAN|dedupe-all}"
    exit 1
    ;;
esac
