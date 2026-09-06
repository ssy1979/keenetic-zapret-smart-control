#!/bin/sh
set -eu

SRC="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
NATIVE="$SRC/opt/kzsc/bin/kzsc-native-dpi.sh"
TEST_SH="$(command -v sh || printf '%s' sh)"
TMP="${TMPDIR:-/tmp}/kzsc-ipv6-test.$$"
trap 'rm -rf "$TMP"' EXIT INT TERM HUP
mkdir -p "$TMP/mockbin"

fail(){ echo "FAIL: $*" >&2; exit 1; }
ok(){ echo "OK: $*"; }

sh -n "$NATIVE" || fail 'native DPI shell syntax'
grep -Fq 'ipv6_runtime_probe' "$NATIVE" || fail 'IPv6 runtime probe missing'
grep -Fq 'ipv6_https_probe_enabled' "$NATIVE" || fail 'IPv6 live HTTPS transaction probe missing'
grep -Fq 'ipv6_wan_enabled' "$NATIVE" || fail 'per-WAN IPv6 capability markers missing'
grep -Fq 'ipv6_iface_has_global_addr' "$NATIVE" || fail 'per-interface global IPv6 address probe missing'
if grep -Fq 'ip -6 route show default 2>/dev/null' "$NATIVE"; then
  fail 'IPv6 probe still requires a main-table per-interface default route'
fi
grep -Fq 'ip6_filter_rule_add FORWARD' "$NATIVE" || fail 'IPv6 QUIC-to-TCP fallback missing'
grep -Fq 'start_proc "$nd"' "$NATIVE" && grep -Fq 'rules_add "$nd"; then' "$NATIVE" || fail 'IPv6 state change does not rebuild the engine'
grep -Fq 'IPv6 değişikliği uygulanamadı; önceki güvenli durum geri yüklendi.' "$NATIVE" || fail 'IPv6 rollback message missing'
ok 'IPv6 transaction and rollback contracts present'

# Exercise actual argument handling without starting the daemon. Each
# family-specific hop count stays explicit; no guessed IPv6 TTL is injected.
eval "$(sed -n '/^strategy_for_wan(){/,/^}/p' "$NATIVE")"
eval "$(sed -n '/^append_tokens(){/,/^}/p' "$NATIVE")"
compact(){ awk '{$1=$1; print}'; }
strategy(){ strategy_for_wan PPPoE1 "$1" | compact; }
ipv6_wan_enabled(){ return 0; }
input='--lua-desync=fake:ip_ttl=6:repeats=1'
[ "$(strategy "$input")" = "--filter-l3=ipv4 $input" ] || fail 'IPv4-only TTL was guessed for IPv6'
input='--lua-desync=fake:ip_ttl=6:ip6_ttl=9:repeats=1'
[ "$(strategy "$input")" = "$input" ] || fail 'Explicit independent IPv6 Hop Limit changed'
input='--lua-desync=fake:ip_autottl=-1,3-8'
[ "$(strategy "$input")" = "--filter-l3=ipv4 $input" ] || fail 'IPv4 autoTTL broadened to IPv6'
input='--lua-desync=fake:ip_ttl=4:ip6_ttl=7 --lua-desync=fake:ip_ttl=3'
[ "$(strategy "$input")" = "--filter-l3=ipv4 $input" ] || fail 'One IPv6 expression incorrectly covered another IPv4-only expression'
input='--lua-desync=multisplit:pos=1,sniext+2'
[ "$(strategy "$input")" = "$input" ] || fail 'Family-neutral splitting rejected on dual-stack WAN'
input='--lua-desync=custom:note=literal\:ip_ttl=6'
[ "$(strategy "$input")" = "$input" ] || fail 'Escaped option-like text changed the IP family'
input='--lua-desync=custom:note=literal\:ip6_ttl=9:ip_ttl=4'
[ "$(strategy "$input")" = "--filter-l3=ipv4 $input" ] || fail 'Escaped text incorrectly supplied an IPv6 counterpart'
input='--filter-l3=ipv4 --lua-desync=multisplit:pos=3'
[ "$(strategy "$input")" = "$input" ] || fail 'Explicit IPv4 restriction broadened'
input='--lua-desync=fake:ip_ttl=3 --new=tls --lua-desync=multisplit:pos=3'
[ "$(strategy "$input")" = "--filter-l3=ipv4 $input" ] || fail 'Named profile boundary lost'
input='--lua-desync=fake:ip_ttl=3 --new --lua-desync=fake:ip6_ttl=8'
[ "$(strategy "$input")" = '--filter-l3=ipv4 --lua-desync=fake:ip_ttl=3 --new --filter-l3=ipv6 --lua-desync=fake:ip6_ttl=8' ] || fail 'Separate profile family restrictions leaked'
ipv6_wan_enabled(){ return 1; }
input='--lua-desync=fake:ip_ttl=6:ip6_ttl=9'
normalized="$(strategy "$input")"
[ "$normalized" = "--filter-l3=ipv4 $input" ] || fail 'IPv4-only WAN changed explicit Lua options'
[ "$(strategy "$normalized")" = "$normalized" ] || fail 'Family restriction is not idempotent'
input='--filter-l3=ipv6 --lua-desync=multisplit:pos=3'
[ "$(strategy "$input")" = '--skip --lua-desync=multisplit:pos=3' ] || fail 'IPv6-only profile was applied to IPv4'
[ "$(append_tokens '* --filter-tcp=80' | tr '\n' ' ' | compact)" = '* --filter-tcp=80' ] || fail 'Profile tokens expanded a filesystem wildcard'
ok 'Explicit hop settings and per-profile IP families remain isolated'

eval "$(sed -n '/^profile_with_mode(){/,/^}/p' "$NATIVE")"
policy_mode(){ echo auto; }
auto_filter_opts(){ echo '--hostlist=/example/auto --hostlist-exclude=/example/exclude --hostlist-auto=/example/auto --hostlist-auto-fail-threshold=3'; }
input='--filter-tcp=80 --lua-desync=multisplit --new=tls --filter-tcp=443 --lua-desync=multisplit --new'
mode_args="$(profile_with_mode PPPoE1 "$input" | compact)"
[ "$mode_args" = '--filter-tcp=80 --lua-desync=multisplit --hostlist=/example/auto --hostlist-exclude=/example/exclude --hostlist-auto=/example/auto --hostlist-auto-fail-threshold=3 --new=tls --filter-tcp=443 --lua-desync=multisplit --hostlist=/example/auto --hostlist-exclude=/example/exclude --hostlist-auto=/example/auto --hostlist-auto-fail-threshold=3 --new' ] || fail 'Auto mode lost a profile or applied hostlists across boundaries'
ok 'Automatic hostlists stay inside every filter profile without truncating later strategies'
(
  eval "$(sed -n '/^auto_hostlist_prepare(){/,/^}/p' "$NATIVE")"
  eval "$(sed -n '/^auto_filter_opts(){/,/^}/p' "$NATIVE")"
  policy_auto_file(){ printf '%s/hostlists/auto' "$TMP"; }
  policy_exclude_file(){ printf '%s/hostlists/exclude' "$TMP"; }
  chown(){ return 1; }
  if auto_filter_opts PPPoE1 >/dev/null 2>&1; then
    fail 'Unwritable automatic hostlist was accepted'
  fi
) || fail 'Automatic hostlist ownership regression'
ok 'Automatic hostlist preparation failure stops argument construction'

eval "$(sed -n '/^preset_field(){/,/^}/p' "$NATIVE")"
PRESET="$SRC/opt/kzsc/share/dpi-presets"
AUTO_PRESET="$TMP/auto"
for preset in kablonet sol tt-fiber vodafone vodafone-tt vodafone-tt2; do
  http="$(preset_field "$preset" HTTP_OPT)"; tls="$(preset_field "$preset" TLS_OPT)"
  [ -n "$http" ] && [ -n "$tls" ] || fail "Empty baseline strategy: $preset"
  [ "$(preset_field "$preset" ID)" = "$preset" ] || fail "Saved preset ID changed: $preset"
  case "$(preset_field "$preset" SOURCE)" in *'RevolutionTR/KZM2 v26.9.2'*'GPL-3.0-or-later'*'verify on the target WAN'*) :;; *) fail "Missing KZM2 source/license/validation notice: $preset";; esac
done
[ "$(preset_field sol HTTP_OPT)" = '--filter-tcp=80 --filter-l7=http --payload=http_req --lua-desync=http_hostcase:spell=hoSt --new' ] || fail 'KZM2 Superonline HTTP profile mismatch'
case "$(preset_field sol TLS_OPT)" in *'fake_default_tls:ip_ttl=6:repeats=1'*) :;; *) fail 'KZM2 Superonline TLS profile mismatch';; esac
[ "$(preset_field sol NO_UDP)" = 1 ] || fail 'KZM2 Superonline QUIC policy mismatch'
case "$(preset_field tt-fiber HTTP_OPT)" in *'fake_default_http:ip_ttl=2:repeats=1'*) :;; *) fail 'KZM2 TT HTTP profile mismatch';; esac
case "$(preset_field tt-fiber UDP_OPT)" in *'fake_default_quic:ip_ttl=2:repeats=6'*) :;; *) fail 'KZM2 TT QUIC profile mismatch';; esac
[ "$(preset_field tt-fiber NO_UDP)" = 0 ] || fail 'KZM2 TT QUIC policy mismatch'
case "$(preset_field kablonet TLS_OPT)" in *'multidisorder:pos=2:seqovl=1'*) :;; *) fail 'KZM2 multidisorder profile mismatch';; esac
ok 'All bundled profiles track KZM2 v26.9.2 with stable KZSC IDs'

eval "$(sed -n '/^proc_queue_owned(){/,/^}/p' "$NATIVE")"
ZROOT='/opt/kzsc/zapret2'
proc_arguments(){ printf '%s\n' "$mock_argv"; }
mock_argv="$(printf '%s\n' "$ZROOT/nfq2/nfqws2" '--qnum=320' '--user=nobody')"
proc_queue_owned 1234 320 || fail 'Exact native process/queue identity rejected'
mock_argv="$(printf '%s\n' "$ZROOT/nfq2/nfqws2" '--qnum=3200')"
if proc_queue_owned 1234 320; then fail 'Queue prefix collision accepted'; fi
mock_argv="$(printf '%s\n' '/bin/echo' "$ZROOT/nfq2/nfqws2" '--qnum=320')"
if proc_queue_owned 1234 320; then fail 'Unrelated process mentioning native path accepted'; fi
mock_argv="$(printf '%s\n' "$ZROOT/nfq2/nfqws2.other" '--qnum=320')"
if proc_queue_owned 1234 320; then fail 'Executable path prefix collision accepted'; fi
mock_argv="$(printf '%s\n' "$ZROOT/nfq2/nfqws2" '--qnum=319')"
if proc_queue_owned 1234 319; then fail 'Unreserved queue accepted'; fi
if proc_queue_owned '-1' 320; then fail 'Invalid PID accepted'; fi
ok 'Native worker identity requires exact executable and reserved queue arguments'

# Exercise the IPv6 transition with two WANs. The first loses connectivity
# only after queues attach; the second remains dual stack. No real rules run.
(
  KZSC_HOME="$TMP/transition"
  KZSC_DPI_POLICY_DIR="$KZSC_HOME/policy"
  IPV6_STATE="$KZSC_HOME/var/dpi/ipv6-enabled"
  IPV6_WAN_STATE_DIR="$KZSC_HOME/var/dpi/ipv6-wan"
  PAUSE_STATE="$KZSC_HOME/paused"
  for fn in ipv6_device_exclusions ipv6_device_notice ipv6_enabled ipv6_status ipv6_wan_key ipv6_wan_marker ipv6_wan_enabled ipv6_wan_mark ipv6_wan_unmark ipv6_wan_clear ipv6_wan_any ipv6_apply ensure; do
    eval "$(awk -v f="$fn" '
      $0 ~ ("^" f "\\(\\)\\{") {print; if($0 ~ /}$/) exit; copying=1; next}
      copying {print; if($0=="}") exit}
    ' "$NATIVE")"
  done
  internet_wans(){ echo 'WAN1 WAN2'; }
  log(){ printf '%s\n' "$*" >>"$KZSC_HOME/runtime.log"; }
  edir(){ printf '%s/%s' "$KZSC_HOME" "$1"; }
  linux_if_for_ndmc(){ printf '%s' "$1"; }
  ipv6_runtime_probe(){ return 0; }
  ipv6_https_probe_iface(){ [ "$1" = WAN2 ] || [ ! -f "$KZSC_HOME/attached-WAN1" ]; }
  rules_del(){ rm -f "$KZSC_HOME/attached-$1"; }
  stop_proc(){ :; }
  start_proc(){ :; }
  rules_add(){
    if ipv6_wan_enabled "$1"; then
      touch "$KZSC_HOME/attached-$1"
    else
      printf '%s\n' "$1" >>"$KZSC_HOME/fallback"
    fi
  }
  mkdir -p "$KZSC_HOME/WAN1" "$KZSC_HOME/WAN2"
  touch "$KZSC_HOME/WAN1/enabled" "$KZSC_HOME/WAN2/enabled"
  ipv6_apply on >/dev/null || fail 'Mixed-WAN transition could not recover IPv4'
  if ipv6_wan_enabled WAN1; then fail 'Broken post-attach IPv6 WAN remained marked'; fi
  ipv6_wan_enabled WAN2 || fail 'Working IPv6 WAN was lost during another WAN fallback'
  grep -Fxq WAN1 "$KZSC_HOME/fallback" || fail 'Failed WAN was not rebuilt as IPv4'
  internet_wans(){ echo WAN1; }
  ipv6_apply on >/dev/null || fail 'IPv4-only recovery returned a failed transition'
  [ ! -e "$IPV6_STATE" ] || fail 'No usable IPv6 WAN but global state remained enabled'

  # Start with a healthy IPv6 WAN; then disable a client whose future/private
  # IPv6 addresses are not represented by the IPv4 client registry.
  internet_wans(){ echo WAN2; }
  ipv6_apply on >/dev/null || fail 'IPv6 setup before device exclusion failed'
  [ -f "$KZSC_HOME/attached-WAN2" ] || fail 'IPv6 queue was not attached before exclusion test'
  mkdir -p "$KZSC_DPI_POLICY_DIR/devices"
  printf 'disabled\n' >"$KZSC_DPI_POLICY_DIR/devices/aabbccddeeff.mode"
  ip(){ return 0; }
  pid_alive(){ return 0; }
  device_filter_signature(){ echo ''; }
  datapath_ok(){ return 0; }
  ensure WAN2 >/dev/null || fail 'Device exclusion could not recover the active WAN'
  [ ! -e "$IPV6_STATE" ] && [ ! -e "$KZSC_HOME/attached-WAN2" ] || fail 'Disabled client could still enter an old IPv6 queue'
  grep -Fxq WAN2 "$KZSC_HOME/fallback" || fail 'IPv4 engine was not retained after device exclusion'
  grep -q 'device has DPI disabled' "$KZSC_HOME/runtime.log" || fail 'Device exclusion reason was not logged'
  [ "$(ipv6_status 2>"$KZSC_HOME/status-reason")" = disabled ] || fail 'Native status lost machine-readable state'
  grep -q 'device exclusion' "$KZSC_HOME/status-reason" || fail 'Native status omitted the IPv6 pause reason'
  ipv6_apply on >/dev/null || fail 'Blocked IPv6 enable should retain working IPv4'
  [ ! -e "$IPV6_STATE" ] && [ ! -e "$KZSC_HOME/attached-WAN2" ] || fail 'IPv6 enable ignored an existing disabled-device preference'
) || fail 'IPv6 post-attach transaction regression'
ok 'IPv6 post-attach rollback and disabled-device bypass preserve IPv4 engines'

cat >"$TMP/mockbin/ndmc" <<'EOF'
#!/bin/sh
exit 1
EOF
cat >"$TMP/mockbin/ip6tables" <<'EOF'
#!/bin/sh
[ -n "${KZSC_IP6_LOG:-}" ] && printf '%s\n' "$*" >>"$KZSC_IP6_LOG"
case " $* " in
  *' -A '*|*' -I '*)
    [ "${KZSC_IP6_FAIL:-0}" = 1 ] && exit 1
    ;;
esac
exit 0
EOF
cat >"$TMP/mockbin/ip" <<'EOF'
#!/bin/sh
case "$*" in
  '-6 addr show dev ppp1')
    cat <<OUT
52: ppp1: <POINTOPOINT,UP,LOWER_UP> mtu 1492
    inet6 2001:db8:1::10/128 scope global
    inet6 fe80::10/10 scope link
OUT
    ;;
  '-6 addr show dev ppp2')
    echo '53: ppp2: <POINTOPOINT,UP,LOWER_UP> mtu 1492'
    echo '    inet6 fe80::20/10 scope link'
    ;;
  '-6 route show default')
    echo 'default via fe80::1 dev ppp0 metric 1000'
    ;;
  *) exit 1 ;;
esac
EOF
cat >"$TMP/mockbin/curl" <<'EOF'
#!/bin/sh
case " $* " in
  *' --interface ppp1 '*) exit 0 ;;
  *) exit 1 ;;
esac
EOF
if command -v chmod >/dev/null 2>&1; then
  chmod 755 "$TMP/mockbin/ndmc" "$TMP/mockbin/ip6tables" "$TMP/mockbin/ip" "$TMP/mockbin/curl"
fi

cat >"$TMP/lib.sh" <<EOF
. "$SRC/opt/kzsc/bin/kzsc-lib.sh"
PATH="$TMP/mockbin:\$PATH"
export PATH
EOF

KZSC_HOME="$TMP/probe-home" KZSC_LIB="$TMP/lib.sh" \
  PATH="$TMP/mockbin:$PATH" "$TEST_SH" "$NATIVE" ipv6-probe ppp1 || \
  fail 'working secondary IPv6 WAN without a main-table default route was rejected'
if KZSC_HOME="$TMP/probe-home" KZSC_LIB="$TMP/lib.sh" \
  PATH="$TMP/mockbin:$PATH" "$TEST_SH" "$NATIVE" ipv6-probe ppp2; then
  fail 'link-local-only WAN was accepted as IPv6 capable'
fi
ok 'IPv6 capability uses global address plus live interface-bound HTTPS'

home="$TMP/home"
log="$TMP/ip6.log"
mkdir -p "$home"
KZSC_HOME="$home" KZSC_LIB="$TMP/lib.sh" KZSC_IP6_LOG="$log" \
  PATH="$TMP/mockbin:\$PATH" "$TEST_SH" "$NATIVE" ipv6 on || fail 'IPv6 probe should pass with supported extensions'
[ -f "$home/var/dpi/ipv6-enabled" ] || fail 'IPv6 state was not persisted after a successful probe'
grep -Fq -- '-m multiport' "$log" || fail 'IPv6 probe did not exercise multiport'
grep -Fq -- '-m connbytes' "$log" || fail 'IPv6 probe did not exercise connbytes'
grep -Fq -- '-j NFQUEUE' "$log" || fail 'IPv6 probe did not exercise NFQUEUE'
ok 'IPv6 runtime probe accepts a working ip6tables datapath'

KZSC_HOME="$home" KZSC_LIB="$TMP/lib.sh" KZSC_IP6_LOG="$log" \
  PATH="$TMP/mockbin:\$PATH" "$TEST_SH" "$NATIVE" ipv6 off || fail 'IPv6 disable failed'
[ ! -e "$home/var/dpi/ipv6-enabled" ] || fail 'IPv6 state survived disable'
ok 'IPv6 disable clears the durable state'

rm -f "$home/var/dpi/ipv6-enabled" "$log"
if KZSC_HOME="$home" KZSC_LIB="$TMP/lib.sh" KZSC_IP6_LOG="$log" KZSC_IP6_FAIL=1 \
  PATH="$TMP/mockbin:\$PATH" "$TEST_SH" "$NATIVE" ipv6 on >/dev/null 2>&1; then
  fail 'IPv6 probe failure was accepted'
fi
[ ! -e "$home/var/dpi/ipv6-enabled" ] || fail 'IPv6 state persisted after a failed probe'
ok 'Unsupported IPv6 extensions fail closed before live rules change'

echo 'ALL IPV6 RUNTIME TESTS PASSED'
