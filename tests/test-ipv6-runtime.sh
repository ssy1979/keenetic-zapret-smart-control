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
grep -Fq 'start_proc "$nd"' "$NATIVE" && grep -Fq 'rules_add "$nd"; then' "$NATIVE" || fail 'IPv6 state change does not rebuild the engine'
grep -Fq 'IPv6 değişikliği uygulanamadı; önceki güvenli durum geri yüklendi.' "$NATIVE" || fail 'IPv6 rollback message missing'
ok 'IPv6 transaction and rollback contracts present'

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
if command -v chmod >/dev/null 2>&1; then
  chmod 755 "$TMP/mockbin/ndmc" "$TMP/mockbin/ip6tables"
fi

cat >"$TMP/lib.sh" <<EOF
. "$SRC/opt/kzsc/bin/kzsc-lib.sh"
PATH="$TMP/mockbin:\$PATH"
export PATH
EOF

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
