#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh
CONF="$KZSC_HOME/etc/kzsc.conf"
OUT="$KZSC_HOME/www/data/keendns.json"
STATE="$KZSC_HOME/var/keendns"
mkdir -p "$KZSC_HOME/www/data" "$STATE"

getv(){ sed -n "s/^$1=\"\([^\"]*\)\"$/\1/p" "$CONF" 2>/dev/null | tail -n1; }
setv(){ k="$1"; v="$2"; t="$CONF.tmp.$$"; awk -v k="$k" -v v="$v" 'BEGIN{d=0}$0~"^"k"="{print k"=\""v"\"";d=1;next}{print}END{if(!d)print k"=\""v"\""}' "$CONF" >"$t" && mv "$t" "$CONF"; }
rcfg(){ LD_LIBRARY_PATH= /bin/ndmc -c 'show running-config' 2>/dev/null; }

base_domain(){
  # Primary source on KeeneticOS 5.x: `show ndns` exposes the booking as
  # separate fields, e.g. name/booked + domain. Do not depend on running-config.
  ndns="$(LD_LIBRARY_PATH= /bin/ndmc -c 'show ndns' 2>/dev/null)"
  name="$(printf '%s\n' "$ndns" | sed -n 's/^[[:space:]]*name:[[:space:]]*//p' | head -n1 | tr -d '\r')"
  booked="$(printf '%s\n' "$ndns" | sed -n 's/^[[:space:]]*booked:[[:space:]]*//p' | head -n1 | tr -d '\r')"
  dom="$(printf '%s\n' "$ndns" | sed -n 's/^[[:space:]]*domain:[[:space:]]*//p' | head -n1 | tr -d '\r')"
  [ -n "$booked" ] && name="$booked"
  case "$name" in ''|*[!A-Za-z0-9_-]*) name='';; esac
  case "$dom" in keenetic.link|keenetic.pro|keenetic.name|keenetic.io) :;; *) dom='';; esac
  if [ -n "$name" ] && [ -n "$dom" ]; then
    d="$name.$dom"
    printf '%s\n' "$d" >"$STATE/domain"
    printf '%s\n' "$d"
    return 0
  fi

  # Compatibility fallback for firmware that prints a complete FQDN.
  d="$({ printf '%s\n' "$ndns"; rcfg; } | grep -Eio '[a-z0-9][a-z0-9.-]*\.keenetic\.(link|pro|name|io)' | sed 's/^kzsc\.//' | awk 'length($0)>0&&!seen[$0]++{print;exit}')"
  [ -n "$d" ] && { printf '%s\n' "$d" >"$STATE/domain"; printf '%s\n' "$d"; return 0; }

  # Last-known-good cache prevents UI flapping during a temporary NDM/cloud miss.
  d="$(cat "$STATE/domain" 2>/dev/null)"
  case "$d" in *.keenetic.link|*.keenetic.pro|*.keenetic.name|*.keenetic.io) printf '%s\n' "$d";; esac
}

proxy_block(){
  rcfg | awk '/^ip http proxy kzsc$/{f=1} f{print} f&&(/^!$/||/^exit$/){exit}'
}
proxy_present(){ proxy_block | grep -q '^ip http proxy kzsc$'; }
proxy_host(){ proxy_block | awk '$1=="upstream" && $2=="http" {print $3; exit}'; }
proxy_port(){ proxy_block | awk '$1=="upstream" && $2=="http" {print $4; exit}'; }
port(){ x="$(getv KZSC_PORT)"; case "$x" in ''|*[!0-9]*) x=9090;; esac; printf '%s' "$x"; }

enable(){
  d="$(base_domain)"; [ -n "$d" ] || { echo 'KeenDNS etkin alan adı algılanamadı.' >&2; return 2; }
  p="$(port)"; lan="$(detect_lan_ip)"; [ -n "$lan" ] || lan='192.168.1.1'

  # Use the exact fully-qualified NDM commands validated on Keenetic Titan.
  LD_LIBRARY_PATH= /bin/ndmc -c 'no ip http proxy kzsc' >/dev/null 2>&1 || true
  out="$(LD_LIBRARY_PATH= /bin/ndmc -c 'ip http proxy kzsc' 2>&1)" || { printf '%s\n' "$out" >&2; return 1; }
  out="$(LD_LIBRARY_PATH= /bin/ndmc -c "ip http proxy kzsc upstream http $lan $p" 2>&1)" || { printf '%s\n' "$out" >&2; return 1; }
  out="$(LD_LIBRARY_PATH= /bin/ndmc -c 'ip http proxy kzsc domain ndns' 2>&1)" || { printf '%s\n' "$out" >&2; return 1; }
  out="$(LD_LIBRARY_PATH= /bin/ndmc -c 'ip http proxy kzsc allow public' 2>&1)" || { printf '%s\n' "$out" >&2; return 1; }
  LD_LIBRARY_PATH= /bin/ndmc -c 'system configuration save' >/dev/null 2>&1 || true

  setv KZSC_KEENDNS_REMOTE 1; printf '%s\n' "$d" >"$STATE/domain"; rm -f "$STATE/miss-count"; publish
  echo "KeenDNS KZSC erişimi aktif: https://kzsc.$d"
}

disable(){
  LD_LIBRARY_PATH= /bin/ndmc -c 'no ip http proxy kzsc' >/dev/null 2>&1 || true
  LD_LIBRARY_PATH= /bin/ndmc -c 'system configuration save' >/dev/null 2>&1 || true
  setv KZSC_KEENDNS_REMOTE 0; rm -f "$STATE/miss-count"; publish
  echo 'KeenDNS KZSC erişimi kapatıldı.'
}

publish(){
  enabled="$(getv KZSC_KEENDNS_REMOTE)"; [ "$enabled" = 1 ] || enabled=0
  d="$(base_domain)"; present=false
  if proxy_present; then
    present=true
    # Adopt an already-existing KZSC-owned proxy (for example one created during
    # pre-existing/manual validation) so UI state matches actual router state.
    [ "$enabled" = 1 ] || { enabled=1; setv KZSC_KEENDNS_REMOTE 1 >/dev/null 2>&1 || true; }
  fi
  url=''; [ -n "$d" ] && url="https://kzsc.$d"
  t="$OUT.tmp.$$"
  printf '{"enabled":%s,"detected":%s,"domain":"%s","url":"%s","proxy_present":%s,"internal_port":%s}\n' \
    "$([ "$enabled" = 1 ]&&echo true||echo false)" "$([ -n "$d" ]&&echo true||echo false)" "$(json_escape "$d")" "$(json_escape "$url")" "$present" "$(port)" >"$t"
  mv "$t" "$OUT"; chmod 644 "$OUT" 2>/dev/null || true; cat "$OUT"
}

sync(){
  enabled="$(getv KZSC_KEENDNS_REMOTE)"
  [ "$enabled" = 1 ] || { publish >/dev/null; return 0; }

  d="$(base_domain)"
  if [ -n "$d" ]; then
    old="$(cat "$STATE/domain" 2>/dev/null)"
    printf '%s\n' "$d" >"$STATE/domain"
    rm -f "$STATE/miss-count"

    want="$(port)"
    actual="$(proxy_port)"

    if ! proxy_present || [ "$actual" != "$want" ]; then
      if enable >/dev/null 2>&1; then
        if [ -n "$actual" ] && [ "$actual" != "$want" ]; then
          /opt/kzsc/bin/kzsc-oplog.sh append keendns_port_sync true \
            "KeenDNS KZSC proxy portu otomatik güncellendi: $actual → $want." \
            "keendns-port-$(date +%s)-$$" >/dev/null 2>&1 || true
        fi
      else
        publish >/dev/null
        return 1
      fi
    elif [ -n "$old" ] && [ "$old" != "$d" ]; then
      /opt/kzsc/bin/kzsc-oplog.sh append keendns_domain_change true \
        "KeenDNS adresi değişti: $old → $d. KZSC erişim adresi otomatik güncellendi." \
        "keendns-domain-$(date +%s)-$$" >/dev/null 2>&1 || true
    fi
  else
    n="$(cat "$STATE/miss-count" 2>/dev/null)"; case "$n" in ''|*[!0-9]*) n=0;; esac
    n=$((n+1)); echo "$n" >"$STATE/miss-count"
    if [ "$n" -ge 3 ]; then
      LD_LIBRARY_PATH= /bin/ndmc -c 'no ip http proxy kzsc; system configuration save' >/dev/null 2>&1 || true
    fi
  fi

  publish >/dev/null
}

audit(){
  enabled="$(getv KZSC_KEENDNS_REMOTE)"
  want="$(port)"
  actual="$(proxy_port)"

  if [ "$enabled" = 1 ]; then
    proxy_present || { echo "ERROR: KeenDNS KZSC proxy missing" >&2; return 1; }
    [ "$actual" = "$want" ] || {
      echo "ERROR: KeenDNS proxy port mismatch: actual=$actual expected=$want" >&2
      return 1
    }
  fi

  echo "OK: KeenDNS port sync enabled=$enabled port=$want proxy_port=${actual:-none}"
  return 0
}

case "$1" in
  enable) enable;;
  disable) disable;;
  status|json|publish) publish;;
  sync) sync;;
  audit) audit;;
  *) echo 'Usage: kzsc-keendns {enable|disable|status|sync|audit}'; exit 1;;
esac
