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
POLICY="$SRC/opt/kzsc/bin/kzsc-dpi-policy.sh"
POLICY_CGI="$SRC/opt/kzsc/www/cgi-bin/dpi_policy.cgi"
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

sh -n "$POLICY_CGI" || fail 'DPI policy CGI shell syntax'
ok 'DPI policy CGI shell syntax'

# Exercise the shipped CGI itself, including POST decoding and its JSON
# response. This catches endpoints that pass sh -n but cannot be consumed by
# the browser.
cgi_home="$TMP/cgi-home"
mkdir -p "$cgi_home/var/run/maintenance-queue"
cgi_response="$(printf '%s' 'action=device&mac=aa%3Abb%3Acc%3Add%3Aee%3Aff&value=disabled%0Ainjected%3Dyes' | \
  KZSC_HOME="$cgi_home" KZSC_LIB="$LIB" REQUEST_METHOD=POST QUERY_STRING='' sh "$POLICY_CGI")"
cgi_json="$(printf '%s\n' "$cgi_response" | tail -n1)"
printf '%s\n' "$cgi_json" | grep -Eq '^\{"ok":true,"queued":true,"action":"dpi_policy_device","request_id":"dpi_policy-[0-9]+-[0-9]+"\}$' || fail 'DPI policy CGI JSON response'
[ "$(find "$cgi_home/var/run/maintenance-queue" -name 'req.*' | awk 'END{print NR+0}')" -eq 1 ] || fail 'DPI policy CGI request queue entry'
grep -R -q '^mac=aa:bb:cc:dd:ee:ff$' "$cgi_home/var/run/maintenance-queue" || fail 'DPI policy CGI POST decoding'
if grep -R -q '^injected=yes$' "$cgi_home/var/run/maintenance-queue"; then
  fail 'DPI policy CGI decoded a control-byte payload injection'
fi
ok 'DPI policy CGI POST, JSON and queue flow'

cat >"$TMP/mockbin/ndmc" <<'EOF'
#!/bin/sh
case "$*" in
  *'show interface'*) cat "$KZSC_TEST_FIXTURE/show-interface.txt" ;;
  *'show version'*) cat "$KZSC_TEST_FIXTURE/show-version.txt" ;;
  *'ip dhcp host '*) printf '%s\n' "$*" >>"${KZSC_NDMC_LOG:?}" ;;
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
cat >"$TMP/mockbin/iptables" <<'EOF'
#!/bin/sh
[ -n "${KZSC_IPTABLES_LOG:-}" ] && printf '%s\n' "$*" >>"$KZSC_IPTABLES_LOG"
case " $* " in *' -C '*) exit 1;; *) exit 0;; esac
EOF
cat >"$TMP/mockbin/chmod" <<'EOF'
#!/bin/sh
# The bundled Windows POSIX test runtime has no chmod; NTFS test files remain
# executable to that runtime. Keenetic/BusyBox uses its real chmod in production.
exit 0
EOF
if command -v chmod >/dev/null 2>&1; then
  chmod 755 "$TMP/mockbin/ndmc" "$TMP/mockbin/ip" "$TMP/mockbin/iptables" "$TMP/mockbin/iptables-save" "$TMP/mockbin/chmod"
fi

make_case(){
  dir="$1"; count="$2"
  mkdir -p "$dir"
  cat >"$dir/show-version.txt" <<'EOF'
 model: KN-1811
 release: 4.3.6
 arch: aarch64
components: base,opkg,pppoe,dns-tls,dns-https,opkg-kmod-netfilter,opkg-kmod-netfilter-addons
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

# Per-WAN automatic hostlist/exclusion policies and per-device preferences
# must remain independent of the number or type of discovered WANs.
policy_home="$TMP/policy-home"
mkdir -p "$policy_home/var"
KZSC_HOME="$policy_home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$POLICY" init >/dev/null || fail 'DPI policy init'
grep -Fq '"label":"TEST-WAN-0"' "$policy_home/www/data/dpi-policy.json" || fail 'DPI policy connection label missing'
KZSC_HOME="$policy_home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$POLICY" mode PPPoE0 auto || fail 'automatic DPI mode'
KZSC_HOME="$policy_home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$POLICY" add PPPoE0 auto '*.gov.tr' || fail 'automatic hostlist wildcard normalization'
KZSC_HOME="$policy_home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$POLICY" add PPPoE0 exclude example.com || fail 'DPI exclusion hostlist'
grep -Fxq 'gov.tr' "$policy_home/var/dpi/policy/wans/pppoe0/auto-domains.txt" || fail 'wildcard was not normalized to Zapret suffix syntax'
grep -Fxq 'example.com' "$policy_home/var/dpi/policy/wans/pppoe0/exclude-domains.txt" || fail 'DPI exclusion was not persisted'
KZSC_HOME="$policy_home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$POLICY" device aa:bb:cc:dd:ee:ff disabled || fail 'device Zapret disable'
printf '%s\n' '{"count":1,"clients":[{"name":"test","ipv4":"192.168.1.20","mac":"aa:bb:cc:dd:ee:ff","wan_iface":"PPPoE0"}]}' >"$policy_home/var/clients.json"
disabled="$(KZSC_HOME="$policy_home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$POLICY" disabled-ips PPPoE0)"
[ "$disabled" = '192.168.1.20' ] || fail 'device bypass IP was not resolved for its WAN'
disabled_other="$(KZSC_HOME="$policy_home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" PATH="$TMP/mockbin:$PATH" sh "$POLICY" disabled-ips PPPoE1)"
[ "$disabled_other" = '192.168.1.20' ] || fail 'device bypass must survive multi-WAN failover'
mkdir -p "$policy_home/var/dpi/wan-registry" "$policy_home/share/dpi-presets"
printf '320\n' >"$policy_home/var/dpi/wan-registry/pppoe0.queue"
printf 'sol\n' >"$policy_home/var/dpi/wan-registry/pppoe0.profile"
printf 'ID="sol"\nNO_UDP="1"\n' >"$policy_home/share/dpi-presets/sol.conf"
: >"$TMP/iptables.log"
KZSC_HOME="$policy_home" KZSC_LIB="$LIB" KZSC_DPI_POLICY_BIN="$POLICY" KZSC_TEST_FIXTURE="$fixture" KZSC_IPTABLES_LOG="$TMP/iptables.log" PATH="$TMP/mockbin:$PATH" \
  sh "$SRC/opt/kzsc/bin/kzsc-native-dpi.sh" dedupe PPPoE0 || fail 'device-aware QUIC chain apply'
grep -Fq -- '-A KZSC320Q -s 192.168.1.20 -j RETURN' "$TMP/iptables.log" || fail 'disabled client QUIC bypass not installed'
grep -Fq -- '-A KZSC320Q -j REJECT' "$TMP/iptables.log" || fail 'QUIC fallback reject missing'
grep -Fq -- '-I FORWARD 1 -o ppp0 -p udp --dport 443 -j KZSC320Q' "$TMP/iptables.log" || fail 'QUIC fallback chain hook missing'
: >"$TMP/ndmc.log"
KZSC_HOME="$policy_home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" KZSC_NDMC_LOG="$TMP/ndmc.log" PATH="$TMP/mockbin:$PATH" sh "$POLICY" static aa:bb:cc:dd:ee:ff 192.168.1.50 || fail 'Keenetic static DHCP reservation'
grep -Fq 'ip dhcp host aa:bb:cc:dd:ee:ff 192.168.1.50' "$TMP/ndmc.log" || fail 'Keenetic static DHCP command missing'
[ "$(KZSC_HOME="$policy_home" KZSC_LIB="$LIB" sh "$POLICY" static-get aa:bb:cc:dd:ee:ff)" = '192.168.1.50' ] || fail 'static DHCP reservation was not persisted'
printf '%s\n' '{"count":1,"clients":[{"name":"other","ipv4":"192.168.1.51","mac":"00:11:22:33:44:55","wan_iface":"PPPoE0"}]}' >"$policy_home/var/clients.json"
if KZSC_HOME="$policy_home" KZSC_LIB="$LIB" KZSC_TEST_FIXTURE="$fixture" KZSC_NDMC_LOG="$TMP/ndmc.log" PATH="$TMP/mockbin:$PATH" sh "$POLICY" static aa:bb:cc:dd:ee:ff 192.168.1.51 >/dev/null 2>&1; then
  fail 'static DHCP collision was accepted'
fi
ok 'DPI policy modes, hostlists, device bypass and static DHCP reservations'

grep -Fq 'quic_filter_rules "$nd" "$cquic"' "$SRC/opt/kzsc/bin/kzsc-native-dpi.sh" || fail 'device-aware QUIC fallback chain missing'
grep -Fq 'rule_add filter "$chain" -s "$ip" -j RETURN' "$SRC/opt/kzsc/bin/kzsc-native-dpi.sh" || fail 'QUIC device bypass rule missing'
grep -Fq 'device_excludes_ok "$nd" "$cin" "$cout" "$cquic" "$no_udp"' "$SRC/opt/kzsc/bin/kzsc-native-dpi.sh" || fail 'device bypass datapath verification missing'
grep -Fq 'for nd in $(internet_wans); do ensure "$nd" || rc=1; done' "$SRC/opt/kzsc/bin/kzsc-native-dpi.sh" || fail 'ensure-all hides per-WAN failures'
grep -Fq 'engine_pid_state' "$SRC/opt/kzsc/bin/kzsc-engines.sh" || fail 'engine status trusts stale/reused PIDs'
grep -Fq 'Cihaz tercihi kaydedildi fakat trafik kuralları uygulanamadı' "$SRC/opt/kzsc/bin/kzsc-maintenance.sh" || fail 'device policy apply failure is not reported'
ok 'device bypass covers every WAN and TCP-only QUIC fallback'

grep -Fq '[ -f "$SRC/opt/kzsc/www/cgi-bin/$b" ] && continue' "$SRC/install.sh" || fail 'installer source-backed CGI allowlist missing'
grep -Fq 'for f in "$SRC"/opt/kzsc/www/cgi-bin/*' "$SRC/install.sh" || fail 'installer CGI post-copy verification missing'
grep -Fq 'for preset in kablonet sol tt-fiber vodafone vodafone-tt vodafone-tt2; do' "$SRC/install.sh" || fail 'installer does not enforce complete built-in preset set'
grep -Fq "sed 's/\\r$//' \"\$f\"" "$SRC/opt/kzsc/bin/kzsc-presets.sh" || fail 'preset metadata parser does not tolerate CRLF files'
grep -Fq "sed 's/\\r$//' \"\$f\"" "$SRC/opt/kzsc/bin/kzsc-native-dpi.sh" || fail 'native preset parser does not tolerate CRLF files'
grep -Fq 'KZSC politika servisi bulunamadı' "$SRC/opt/kzsc/www/index.html" || fail 'DPI policy frontend HTML-error handling missing'
grep -Fq 'Henüz rezervasyon yok' "$SRC/opt/kzsc/www/index.html" || fail 'device reservation state UI missing'
grep -Fq 'value="${escapeHtml(reservation)}"' "$SRC/opt/kzsc/www/index.html" || fail 'unreserved device IP field must not look preconfigured'
grep -Fq 'data-tab="dpiPolicyPanel"' "$SRC/opt/kzsc/www/index.html" || fail 'top-level operating mode tab missing'
grep -Fq 'w.label||w.ndmc' "$SRC/opt/kzsc/www/index.html" || fail 'operating mode must prefer connection labels'
grep -Fq 'Otomatik alan adları' "$SRC/opt/kzsc/www/index.html" || fail 'automatic domains are not visible in operating mode'
grep -Fq "root.querySelectorAll('.dpiDomain').forEach" "$SRC/opt/kzsc/www/index.html" || fail 'operating mode domain drafts are not preserved during refresh'
grep -Fq 'input.setSelectionRange(focused.start,focused.end)' "$SRC/opt/kzsc/www/index.html" || fail 'operating mode domain focus is not preserved during refresh'
grep -Fq 'if(ok){const current=document.getElementById(inputId);if(current)current.value=' "$SRC/opt/kzsc/www/index.html" || fail 'saved operating mode domain draft is not cleared'
grep -Fq 'latestEngines=engines||' "$SRC/opt/kzsc/www/index.html" || fail 'engine snapshot is not retained for profile/start actions'
grep -Fq 'engineActionBusy' "$SRC/opt/kzsc/www/index.html" || fail 'engine action refresh guard missing'
grep -Fq 'waitMaintenanceResult(x.request_id,120000)' "$SRC/opt/kzsc/www/index.html" || fail 'engine action timeout is too short for a busy daemon'
ok 'DPI policy install retention, frontend error handling and device UI clarity'

grep -Fq 'ACTION="restart"' "$SRC/opt/kzsc/bin/kzsc-audit.sh" || fail 'audit still expects legacy restart queue literal'
grep -Fq 'ACTION="router_reboot"' "$SRC/opt/kzsc/bin/kzsc-audit.sh" || fail 'audit still expects legacy router reboot queue literal'
grep -Fq 'for candidate in /bin/ndmc' "$SRC/opt/kzsc/bin/kzsc-audit.sh" || fail 'audit does not recognize fixed-path ndmc discovery'
grep -Fq 'dpi_policy.cgi|refresh.cgi' "$SRC/opt/kzsc/bin/kzsc-audit.sh" || fail 'audit CGI allow-list misses current policy/refresh endpoints'
grep -Fq 'Görünür UI çift dilli mesaj/tarih yardımcıları' "$SRC/opt/kzsc/bin/kzsc-ui-selftest.sh" || fail 'self-test still expects the removed Event Log panel'
ok 'audit contracts follow current restart, CGI and visible UI architecture'

grep -q 'deadline=$((worker_started+MAX_SECONDS))' "$SRC/opt/kzsc/bin/kzsc-blockcheck.sh" || fail 'absolute Blockcheck deadline missing'
if grep -q 'deadline=$(( $(date +%s) + MAX_SECONDS ))' "$SRC/opt/kzsc/bin/kzsc-blockcheck.sh"; then
  fail 'broad phase still resets Blockcheck deadline'
fi
ok 'Blockcheck deadline begins at worker entry and is never reset'

echo 'ALL ADAPTIVE WAN TESTS PASSED'
