#!/bin/sh
set -eu

SRC="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
REAL_LIB="$SRC/opt/kzsc/bin/kzsc-lib.sh"
PREFLIGHT="$SRC/opt/kzsc/bin/kzsc-preflight.sh"
REGISTRY="$SRC/opt/kzsc/bin/kzsc-wan-registry.sh"
DISCOVER="$SRC/opt/kzsc/bin/kzsc-discover.sh"
BLOCKCGI="$SRC/opt/kzsc/bin/kzsc-blockcheck-cgi.sh"
ENGINECGI="$SRC/opt/kzsc/bin/kzsc-engine-cgi.sh"
PRESETCGI="$SRC/opt/kzsc/bin/kzsc-presets-cgi.sh"
BLOCKCHECK="$SRC/opt/kzsc/bin/kzsc-blockcheck.sh"
TMP="${TMPDIR:-/tmp}/kzsc-adaptive-test.$$"
trap 'rm -rf "$TMP"' EXIT INT TERM HUP
mkdir -p "$TMP/mockbin"
LIB="$TMP/kzsc-test-lib.sh"
cat >"$LIB" <<EOF
. "$REAL_LIB"
PATH="$TMP/mockbin:\$PATH"
export PATH
EOF

fail(){ echo "FAIL: $*" >&2; exit 1; }
ok(){ echo "OK: $*"; }

cat >"$TMP/mockbin/ndmc" <<'EOF'
#!/bin/sh
case "$*" in
  *'show interface'*) cat "$KZSC_TEST_FIXTURE/show-interface.txt" ;;
  *'show version'*) cat "$KZSC_TEST_FIXTURE/show-version.txt" ;;
  *) exit 1 ;;
esac
EOF
cat >"$TMP/mockbin/ip" <<'EOF'
#!/bin/sh
case "$*" in
  '-4 -o addr show') cat "$KZSC_TEST_FIXTURE/ip-addr.txt" ;;
  'link show '*) want="${*#link show }"; awk -v w="$want" '$2==w {found=1} END{exit !found}' "$KZSC_TEST_FIXTURE/ip-addr.txt" ;;
  *) exit 1 ;;
esac
EOF
cat >"$TMP/mockbin/iptables-save" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$TMP/mockbin/chmod" <<'EOF'
#!/bin/sh
# The bundled Windows POSIX test runtime has no chmod; NTFS test files remain
# executable to that runtime. Keenetic/BusyBox uses its real chmod in production.
exit 0
EOF
if command -v chmod >/dev/null 2>&1; then
  chmod 755 "$TMP/mockbin/ndmc" "$TMP/mockbin/ip" "$TMP/mockbin/iptables-save" "$TMP/mockbin/chmod"
fi

make_case(){
  dir="$1"; count="$2"
  mkdir -p "$dir"
  cat >"$dir/show-version.txt" <<'EOF'
 model: KN-1811
 release: 4.3.6
 arch: aarch64
 components: base,opkg,pppoe,dns-tls,dns-https
EOF
  : >"$dir/show-interface.txt"
  : >"$dir/ip-addr.txt"
  n=0
  while [ "$n" -lt "$count" ]; do
    case "$n" in
      0) nd=PPPoE0; type=PPPoE; lin=ppp0 ;;
      1) nd=GigabitEthernet0/Vlan2; type=GigabitEthernet; lin=eth3 ;;
      2) nd=WifiMaster0/WifiStation0; type=WifiStation; lin=wlan0 ;;
      *) nd="PPPoE$n"; type=PPPoE; lin="ppp$n" ;;
    esac
    oct=$((n+10)); addr="100.64.0.$oct"
    cat >>"$dir/show-interface.txt" <<EOF
Interface, name = "$nd":
 type: $type
 role: inet
 description: TEST-WAN-$n
 address: $addr
 state: up
 defaultgw: yes
 priority: $((n+1))
EOF
    printf '%s: %s    inet %s/32 scope global %s\n' "$((n+2))" "$lin" "$addr" "$lin" >>"$dir/ip-addr.txt"
    n=$((n+1))
  done
  cat >>"$dir/show-interface.txt" <<'EOF'
Interface, name = "Bridge0":
 type: Bridge
 role: misc
 security-level: private
 address: 192.168.1.1
 state: up
EOF
  printf '20: br0    inet 192.168.1.1/24 scope global br0\n' >>"$dir/ip-addr.txt"
}

run_case(){
  count="$1"; fixture="$TMP/case-$count"; home="$TMP/home-$count"
  make_case "$fixture" "$count"
  KZSC_LIB="$LIB" KZSC_PREFLIGHT_FIXTURE_DIR="$fixture" sh "$PREFLIGHT" fixture >/dev/null || fail "$count WAN pre-flight"
  mkdir -p "$home/var/run/maintenance-queue"
  KZSC_HOME="$home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$REGISTRY" refresh >/dev/null || fail "$count WAN registry"
  grep -q "\"count\":$count" "$home/www/data/wan-registry.json" || fail "$count WAN registry count"
  queues="$(sed -n 's/.*\"queue\":\([0-9][0-9]*\).*/\1/p' "$home/www/data/wan-registry.json" | sort -n | uniq | awk 'END{print NR+0}')"
  [ "$queues" -eq "$count" ] || fail "$count WAN unique queues"
  KZSC_HOME="$home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$DISCOVER" >/dev/null || fail "$count WAN capability profile"
  grep -q "\"wan_count\":$count" "$home/var/topology.json" || fail "$count WAN capability count"
  grep -q '"kind":"pppoe"' "$home/var/topology.json" || fail "$count WAN PPPoE kind"
  [ "$count" -lt 2 ] || grep -q '"kind":"ipoe"' "$home/var/topology.json" || fail "$count WAN IPoE kind"
  [ "$count" -lt 3 ] || grep -q '"kind":"wisp"' "$home/var/topology.json" || fail "$count WAN WISP kind"
  KZSC_HOME="$home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$BLOCKCGI" || fail "$count WAN Blockcheck CGI"
  starts="$(find "$home/www/cgi-bin" -name 'blockcheck_start_*.cgi' | awk 'END{print NR+0}')"
  stops="$(find "$home/www/cgi-bin" -name 'blockcheck_stop_*.cgi' | awk 'END{print NR+0}')"
  [ "$starts" -eq "$count" ] && [ "$stops" -eq "$count" ] || fail "$count WAN Blockcheck endpoints"
  KZSC_HOME="$home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$ENGINECGI" || fail "$count WAN engine CGI"
  KZSC_HOME="$home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$PRESETCGI" || fail "$count WAN preset CGI"
  ok "$count WAN: discovery, mapping, queues and CGI"
}

run_case 1
run_case 2
run_case 3
run_case 4

fixture="$TMP/exhaust"; home="$TMP/exhaust-home"
make_case "$fixture" 3
mkdir -p "$home"
if KZSC_HOME="$home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" KZSC_QUEUE_BASE=320 KZSC_QUEUE_MAX=321 PATH="$TMP/mockbin:$PATH" sh "$REGISTRY" refresh >/dev/null 2>&1; then
  fail 'queue exhaustion must fail closed'
fi
[ ! -e "$home/www/data/wan-registry.json" ] || fail 'exhausted registry must not be published'
ok 'queue exhaustion fails closed without queue 0'

badfixture="$TMP/unsupported"
mkdir -p "$badfixture"
cp "$fixture/show-version.txt" "$badfixture/show-version.txt"
cat >"$badfixture/show-interface.txt" <<'EOF'
Interface, name = "UsbQmi0":
 type: UsbQmi
 role: inet
 address: 100.64.9.2
 state: up
EOF
printf '5: wwan0    inet 100.64.9.2/32 scope global wwan0\n' >"$badfixture/ip-addr.txt"
if KZSC_LIB="$LIB" KZSC_PREFLIGHT_FIXTURE_DIR="$badfixture" sh "$PREFLIGHT" fixture >/dev/null 2>&1; then
  fail 'unsupported mobile WAN must be rejected'
fi
ok 'unsupported mobile WAN is rejected'

fixture="$TMP/case-1"; home="$TMP/domain-home"
mkdir -p "$home"
ten='a.example b.example c.example d.example e.example f.example g.example h.example i.example j.example'
KZSC_HOME="$home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$BLOCKCHECK" set-domains PPPoE0 "$ten" >/dev/null || fail '10 Blockcheck domains should be accepted'
eleven="$ten k.example"
if KZSC_HOME="$home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$BLOCKCHECK" set-domains PPPoE0 "$eleven" >/dev/null 2>&1; then
  fail '11 Blockcheck domains must be rejected by backend'
fi
toolong='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.example'
if KZSC_HOME="$home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$BLOCKCHECK" set-domains PPPoE0 "$toolong" >/dev/null 2>&1; then
  fail 'overlong Blockcheck domain must be rejected by backend'
fi
ok 'Blockcheck backend enforces 10 targets and length limits'

grep -q 'deadline=$((worker_started+MAX_SECONDS))' "$SRC/opt/kzsc/bin/kzsc-blockcheck.sh" || fail 'absolute Blockcheck deadline missing'
if grep -q 'deadline=$(( $(date +%s) + MAX_SECONDS ))' "$SRC/opt/kzsc/bin/kzsc-blockcheck.sh"; then
  fail 'broad phase still resets Blockcheck deadline'
fi
ok 'Blockcheck deadline begins at worker entry and is never reset'

echo 'ALL ADAPTIVE WAN TESTS PASSED'
