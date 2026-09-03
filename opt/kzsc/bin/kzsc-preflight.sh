#!/opt/bin/sh

# Read-only compatibility gate for KZSC installation and upgrades.
# Production mode does not write router configuration or firewall rules.

PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

MODE="${1:-check}"
SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
LIB="${KZSC_LIB:-$SELF_DIR/kzsc-lib.sh}"
KZSC_HOME="${KZSC_HOME:-/opt/kzsc}"
export KZSC_HOME

FAIL=0
WARN=0
VERSION_OUT=""
INTERFACE_OUT=""
FIXTURE_DIR="${KZSC_PREFLIGHT_FIXTURE_DIR:-}"
MIN_FREE_KB="${KZSC_PREFLIGHT_MIN_FREE_KB:-32768}"
QUEUE_BASE="${KZSC_QUEUE_BASE:-320}"
QUEUE_MAX="${KZSC_QUEUE_MAX:-399}"

ok(){ printf 'OK   %s\n' "$*"; }
warn(){ printf 'WARN %s\n' "$*"; WARN=$((WARN+1)); }
bad(){ printf 'FAIL %s\n' "$*"; FAIL=$((FAIL+1)); }

case "$MIN_FREE_KB" in ''|*[!0-9]*) MIN_FREE_KB=32768;; esac
case "$QUEUE_BASE:$QUEUE_MAX" in
  *[!0-9:]*) QUEUE_BASE=320; QUEUE_MAX=399;;
esac
[ "$QUEUE_BASE" -le "$QUEUE_MAX" ] 2>/dev/null || { QUEUE_BASE=320; QUEUE_MAX=399; }

NDMC_BIN=""
for x in /bin/ndmc /opt/bin/ndmc /usr/bin/ndmc /sbin/ndmc /usr/sbin/ndmc; do
  [ -x "$x" ] && { NDMC_BIN="$x"; break; }
done
[ -n "$NDMC_BIN" ] || NDMC_BIN="$(command -v ndmc 2>/dev/null || true)"

if [ "$MODE" = fixture ]; then
  [ -n "$FIXTURE_DIR" ] || { echo 'KZSC_PREFLIGHT_FIXTURE_DIR gerekli.' >&2; exit 2; }
  [ -f "$FIXTURE_DIR/show-version.txt" ] || { echo 'show-version.txt eksik.' >&2; exit 2; }
  [ -f "$FIXTURE_DIR/show-interface.txt" ] || { echo 'show-interface.txt eksik.' >&2; exit 2; }
  [ -f "$FIXTURE_DIR/ip-addr.txt" ] || { echo 'ip-addr.txt eksik.' >&2; exit 2; }
  VERSION_OUT="$(cat "$FIXTURE_DIR/show-version.txt")"
  INTERFACE_OUT="$(cat "$FIXTURE_DIR/show-interface.txt")"
  ip(){
    case "$*" in
      '-4 -o addr show') cat "$FIXTURE_DIR/ip-addr.txt" ;;
      'link show '*)
        want="${*#link show }"
        awk -v w="$want" '$2==w {found=1} END{exit !found}' "$FIXTURE_DIR/ip-addr.txt"
        ;;
      *) return 1 ;;
    esac
  }
fi

[ -f "$LIB" ] || { echo "KZSC kitaplığı bulunamadı: $LIB" >&2; exit 2; }
. "$LIB"

# Use one stable NDMC snapshot throughout a check; interface state must not
# change between count, type and Linux binding validation.
show_interfaces(){
  if [ -n "$INTERFACE_OUT" ]; then
    printf '%s\n' "$INTERFACE_OUT"
  elif [ -n "$NDMC_BIN" ]; then
    LD_LIBRARY_PATH= "$NDMC_BIN" -c 'show interface' 2>/dev/null
  else
    return 1
  fi
}

has_component(){
  token="$1"
  normalized="$(printf '%s\n' "$VERSION_OUT" | tr '\n' ' ' | sed 's/-[[:space:]][[:space:]]*/-/g')"
  printf '%s\n' "$normalized" | grep -Eq "(^|[,:[:space:]])${token}([,[:space:]]|$)"
}

check_components(){
  echo '--- KeeneticOS bileşenleri ---'
  [ -n "$VERSION_OUT" ] || { bad 'show version çıktısı alınamadı'; return; }

  model="$(printf '%s\n' "$VERSION_OUT" | sed -n 's/.*model[^:]*:[[:space:]]*//Ip' | head -n1)"
  release="$(printf '%s\n' "$VERSION_OUT" | sed -n 's/.*release[^:]*:[[:space:]]*//Ip' | head -n1)"
  arch="$(printf '%s\n' "$VERSION_OUT" | sed -n 's/^[[:space:]]*arch:[[:space:]]*//p' | head -n1)"
  ok "Router: ${model:-unknown} · KeeneticOS: ${release:-unknown} · arch: ${arch:-unknown}"

  has_component opkg && ok 'Open Package support (opkg)' || bad 'KeeneticOS Open Package support (opkg) bileşeni eksik'
  has_component pppoe && ok 'PPPoE bileşeni' || warn 'PPPoE bileşeni görünmüyor; yalnız IPoE kullanılacaksa bu normaldir'
  has_component dns-tls && ok 'DNS-over-TLS proxy (dns-tls)' || bad 'DNS-over-TLS proxy (dns-tls) bileşeni eksik'
  has_component dns-https && ok 'DNS-over-HTTPS proxy (dns-https)' || bad 'DNS-over-HTTPS proxy (dns-https) bileşeni eksik'
  has_component opkg-kmod-netfilter && ok 'Entware netfilter çekirdek desteği' || bad 'KeeneticOS opkg-kmod-netfilter bileşeni eksik'
  has_component opkg-kmod-netfilter-addons && ok 'Entware netfilter ek modülleri' || bad 'KeeneticOS opkg-kmod-netfilter-addons bileşeni eksik'
}

check_wans(){
  echo '--- WAN keşfi ve Linux eşleme ---'
  wans="$(internet_wans)"
  count="$(printf '%s\n' "$wans" | awk 'NF{n++} END{print n+0}')"
  capacity=$((QUEUE_MAX-QUEUE_BASE+1))

  [ "$count" -gt 0 ] 2>/dev/null || bad 'Desteklenen aktif/yapılandırılmış WAN yok (PPPoE, kablolu IPoE veya WISP gerekli)'
  [ "$count" -le "$capacity" ] 2>/dev/null || bad "WAN sayısı queue kapasitesini aşıyor: $count > $capacity"
  [ "$count" -gt 0 ] 2>/dev/null && [ "$count" -le "$capacity" ] 2>/dev/null && \
    ok "Desteklenen WAN sayısı: $count · queue kapasitesi: $capacity"

  seen=" "
  for nd in $wans; do
    kind="$(internet_wan_kind "$nd")"
    typ="$(iface_type "$nd")"
    state="$(iface_state "$nd")"
    addr="$(iface_address "$nd")"
    lin="$(linux_if_for_ndmc "$nd" 2>/dev/null || true)"

    case "$kind" in
      pppoe|ipoe|wisp) : ;;
      *) bad "$nd desteklenmeyen WAN türü: ${typ:-unknown}"; continue ;;
    esac

    if [ -z "$lin" ]; then
      case "$state" in
        up) bad "$nd (${kind}) Linux arayüzüne eşlenemedi" ;;
        *) warn "$nd (${kind}) şu an ${state:-down}; ilk aktif bağlantıda Linux eşlemesi gerekli" ;;
      esac
      continue
    fi

    case "$seen" in
      *" $lin "*) bad "Birden fazla WAN aynı Linux arayüzüne eşlendi: $lin" ;;
      *) seen="$seen$lin " ;;
    esac
    ok "$nd · $kind/${typ:-unknown} · ${addr:-no-ip} · Linux=$lin · state=${state:-unknown}"
  done
}

check_host(){
  echo '--- Entware, web ve araçlar ---'
  [ "$(id -u 2>/dev/null)" = 0 ] && ok 'root yetkisi' || bad 'Kurulum root kullanıcısıyla çalıştırılmalı'
  [ -x /opt/bin/sh ] && ok '/opt/bin/sh' || bad 'Entware shell /opt/bin/sh eksik'
  [ -n "$NDMC_BIN" ] && ok "ndmc: $NDMC_BIN" || bad 'ndmc bulunamadı'

  lighttpd_bin="$(command -v lighttpd 2>/dev/null || true)"
  [ -n "$lighttpd_bin" ] || [ ! -x /opt/sbin/lighttpd ] || lighttpd_bin=/opt/sbin/lighttpd
  [ -n "$lighttpd_bin" ] && ok "lighttpd: $lighttpd_bin" || bad 'lighttpd eksik (BusyBox httpd/nginx KZSC backend değildir)'
  if [ -f /opt/lib/lighttpd/mod_cgi.so ] || [ -f /opt/lib/lighttpd/mod_cgi.so.0 ]; then
    ok 'lighttpd CGI modülü'
  else
    bad 'lighttpd mod_cgi eksik (/opt/lib/lighttpd/mod_cgi.so)'
  fi

  for cmd in awk sed grep tr cut head tail sort find xargs tar gzip sha256sum wc ip iptables iptables-save ps date; do
    command -v "$cmd" >/dev/null 2>&1 && ok "araç: $cmd" || bad "gerekli araç eksik: $cmd"
  done
  if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
    ok 'HTTPS indirici: curl/wget'
  else
    bad 'curl veya wget eksik'
  fi

  [ -d /opt/tmp ] && [ -w /opt/tmp ] && ok '/opt/tmp yazılabilir' || bad '/opt/tmp yok veya yazılamıyor'
  free_kb="$(df -Pk /opt 2>/dev/null | awk 'NR==2 {print $4; exit}')"
  case "$free_kb" in
    ''|*[!0-9]*) warn '/opt boş alanı ölçülemedi' ;;
    *)
      [ "$free_kb" -ge "$MIN_FREE_KB" ] && ok "/opt boş alan: ${free_kb} KiB" || bad "/opt boş alan yetersiz: ${free_kb} KiB < ${MIN_FREE_KB} KiB"
      ;;
  esac
  mem_kb="$(awk '/^MemAvailable:/ {print $2; found=1; exit} /^MemFree:/ && !fallback {fallback=$2} END{if(!found && fallback) print fallback}' /proc/meminfo 2>/dev/null | head -n1)"
  case "$mem_kb" in
    ''|*[!0-9]*) warn 'kullanılabilir RAM ölçülemedi' ;;
    *) [ "$mem_kb" -ge 32768 ] && ok "kullanılabilir RAM: ${mem_kb} KiB" || warn "kullanılabilir RAM düşük: ${mem_kb} KiB" ;;
  esac
}

check_firewall(){
  echo '--- iptables / NFQUEUE yetenekleri ---'
  # KeeneticOS may advertise the netfilter component while leaving optional
  # xtables modules unloaded after a reboot. Load the shipped modules before
  # the runtime probe; this is the safe, narrowly-scoped remediation needed by
  # KZSC and avoids asking users to run insmod manually.
  for mod in xt_multiport xt_connbytes; do
    lsmod 2>/dev/null | awk -v m="$mod" '$1==m {found=1} END{exit !found}' && continue
    mf="/lib/modules/$(uname -r 2>/dev/null)/$mod.ko"
    [ -f "$mf" ] || mf="/lib/modules/$(uname -r 2>/dev/null)/kernel/net/netfilter/$mod.ko"
    [ -f "$mf" ] && [ -x /opt/sbin/insmod ] && /opt/sbin/insmod "$mf" >/dev/null 2>&1 || true
  done
  iptables -t mangle -S >/dev/null 2>&1 && ok 'iptables mangle tablosu' || bad 'iptables mangle tablosu kullanılamıyor'
  iptables -t filter -S >/dev/null 2>&1 && ok 'iptables filter tablosu' || bad 'iptables filter tablosu kullanılamıyor'
  iptables -m multiport -h >/dev/null 2>&1 && ok 'iptables multiport match' || bad 'iptables multiport match eksik'
  iptables -m connbytes -h >/dev/null 2>&1 && ok 'iptables connbytes match' || bad 'iptables connbytes match eksik'
  iptables -m mark -h >/dev/null 2>&1 && ok 'iptables mark match' || bad 'iptables mark match eksik'
  nfqh="$(iptables -j NFQUEUE -h 2>&1)"
  [ $? -eq 0 ] && ok 'iptables NFQUEUE target' || bad 'iptables NFQUEUE target eksik'
  printf '%s\n' "$nfqh" | grep -q -- '--queue-bypass' && ok 'NFQUEUE --queue-bypass' || bad 'NFQUEUE --queue-bypass desteği eksik'

  # Help distinguish a userspace help entry from a usable kernel match.  Some
  # Keenetic images list connbytes/multiport in `-h` but reject the real rule
  # until the corresponding netfilter component is installed.
  probe="KZSC_PROBE_$$"
  if iptables -t mangle -N "$probe" >/dev/null 2>&1 &&
     iptables -t mangle -A "$probe" -p tcp -m multiport --dports 80,443 \
       -m connbytes --connbytes 1:2 --connbytes-mode packets --connbytes-dir original \
       -j NFQUEUE --queue-num 0 --queue-bypass >/dev/null 2>&1
  then
    ok 'iptables runtime multiport + connbytes + NFQUEUE'
  else
    bad 'iptables runtime multiport/connbytes/NFQUEUE kuralı uygulanamıyor (netfilter bileşenini kontrol edin)'
  fi
  iptables -t mangle -F "$probe" >/dev/null 2>&1 || true
  iptables -t mangle -X "$probe" >/dev/null 2>&1 || true
}

echo '=== KZSC v0.11.2.54-generic PRE-FLIGHT ==='

if [ "$MODE" = fixture ]; then
  check_components
  check_wans
else
  if [ -n "$NDMC_BIN" ]; then
    VERSION_OUT="$(LD_LIBRARY_PATH= "$NDMC_BIN" -c 'show version' 2>/dev/null)"
    INTERFACE_OUT="$(LD_LIBRARY_PATH= "$NDMC_BIN" -c 'show interface' 2>/dev/null)"
  fi
  check_components
  check_host
  check_wans
  check_firewall
fi

if [ "$FAIL" -gt 0 ]; then
  printf '=== PRE-FLIGHT: FAIL (%s hata, %s uyarı) ===\n' "$FAIL" "$WARN"
  printf '%s\n' 'KeeneticOS bileşenlerini/Entware paketlerini tamamlayıp tekrar çalıştırın.'
  exit 1
fi

printf '=== PRE-FLIGHT: OK (%s uyarı) ===\n' "$WARN"
exit 0
