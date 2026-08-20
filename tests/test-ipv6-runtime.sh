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
grep -Fq "sed 's/:ip_ttl=" "$NATIVE" || fail 'IPv6 ip_ttl/ip6_ttl strategy normalization missing'
grep -Fq 'ip6_filter_rule_add FORWARD' "$NATIVE" || fail 'IPv6 QUIC-to-TCP fallback missing'
grep -Fq 'start_proc "$nd"' "$NATIVE" && grep -Fq 'rules_add "$nd"; then' "$NATIVE" || fail 'IPv6 state change does not rebuild the engine'
grep -Fq 'IPv6 değişikliği uygulanamadı; önceki güvenli durum geri yüklendi.' "$NATIVE" || fail 'IPv6 rollback message missing'
ok 'IPv6 transaction and rollback contracts present'

# Exercise the actual normalizer function without starting the daemon.
eval "$(sed -n '/^strategy_for_wan(){/,/^}/p' "$NATIVE")"
ipv6_wan_enabled(){ return 0; }
normalized="$(strategy_for_wan PPPoE1 '--lua-desync=fake:ip_ttl=6:repeats=1')"
[ "$normalized" = '--lua-desync=fake:ip_ttl=6:ip6_ttl=6:repeats=1' ] || \
  fail "IPv6 TTL normalization mismatch: $normalized"
normalized="$(strategy_for_wan PPPoE1 '--lua-desync=fake:ip_ttl=6:ip6_ttl=6:repeats=1')"
[ "$normalized" = '--lua-desync=fake:ip_ttl=6:ip6_ttl=6:repeats=1' ] || \
  fail 'IPv6 TTL normalization duplicated an existing ip6_ttl'
ipv6_wan_enabled(){ return 1; }
normalized="$(strategy_for_wan PPPoE1 '--lua-desync=fake:ip_ttl=6:ip6_ttl=6:repeats=1')"
[ "$normalized" = '--lua-desync=fake:ip_ttl=6:repeats=1' ] || \
  fail 'IPv4-only WAN retained stale ip6_ttl'
ok 'KZM2-compatible IPv6 TTL strategy normalization is idempotent per WAN'

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

