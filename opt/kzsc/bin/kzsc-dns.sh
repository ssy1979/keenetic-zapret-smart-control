#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

# CGI environments may not inherit Entware paths. Keep DNS backend independent
# from the caller's PATH and resolve ndmc deterministically.
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
NDMC_BIN=""
for x in /opt/bin/ndmc /bin/ndmc /usr/bin/ndmc /sbin/ndmc /usr/sbin/ndmc; do
  [ -x "$x" ] && { NDMC_BIN="$x"; break; }
done
[ -n "$NDMC_BIN" ] || NDMC_BIN="$(command -v ndmc 2>/dev/null || true)"

ROOT="$KZSC_HOME"
DIR="$ROOT/var/dns"
STATE="$DIR/state.conf"
OWN_DOT="$DIR/owned-dot.list"
OWN_DOH="$DIR/owned-doh.list"
OWN_IGNORE="$DIR/owned-ignore.list"
PUBLIC="$ROOT/www/data/dns.json"
BACKUP_DIR="$DIR/backups"
mkdir -p "$BACKUP_DIR"
mkdir -p "$DIR" "$ROOT/www/data"

DNS_LOG="$ROOT/var/log/dns.log"
mkdir -p "$ROOT/var/log"

dns_log(){ printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$DNS_LOG"; }

ndmc_dns(){
  cmd="$*"
  dns_log "CMD: $cmd"
  if [ -z "$NDMC_BIN" ]; then
    out="ndmc bulunamadı (PATH=$PATH)"; rc=127
  else
    out="$(LD_LIBRARY_PATH= "$NDMC_BIN" -c "$cmd" 2>&1)"; rc=$?
  fi
  [ -n "$out" ] && dns_log "OUT($rc): $(printf '%s' "$out" | tr '\r\n' '  ')"
  # Callers use ndmc_dns both as a command and as a data source.  Always
  # preserve the original CLI stdout so running_config / show dns-proxy
  # parsers can actually inspect Keenetic state.
  [ -n "$out" ] && printf '%s\n' "$out"
  return "$rc"
}

normalize_ignore(){
  case "$1" in
    1|ignore|on|true|yes) echo 1 ;;
    0|keep|off|false|no|'') echo 0 ;;
    *) return 1 ;;
  esac
}

running_config(){
  ndmc_dns 'show running-config'
}

json_bool(){ [ "$1" = "1" ] && echo true || echo false; }

provider_name(){
  case "$1" in
    cloudflare) echo 'Cloudflare' ;;
    google) echo 'Google' ;;
    quad9) echo 'Quad9' ;;
    adguard) echo 'AdGuard' ;;
    *) echo "$1" ;;
  esac
}

provider_dot(){
  case "$1" in
    cloudflare)
      echo '1.1.1.1|cloudflare-dns.com'
      echo '1.0.0.1|cloudflare-dns.com'
      ;;
    google)
      echo '8.8.8.8|dns.google'
      echo '8.8.4.4|dns.google'
      ;;
    quad9)
      echo '9.9.9.9|dns.quad9.net'
      echo '149.112.112.112|dns.quad9.net'
      ;;
    adguard)
      echo '94.140.14.14|dns.adguard-dns.com'
      echo '94.140.15.15|dns.adguard-dns.com'
      ;;
    *) return 1 ;;
  esac
}

provider_doh(){
  case "$1" in
    cloudflare) echo 'https://cloudflare-dns.com/dns-query|dnsm' ;;
    google) echo 'https://dns.google/dns-query|dnsm' ;;
    quad9) echo 'https://dns.quad9.net/dns-query|dnsm' ;;
    adguard) echo 'https://dns.adguard-dns.com/dns-query|dnsm' ;;
    *) return 1 ;;
  esac
}

valid_provider(){ case "$1" in cloudflare|google|quad9|adguard) return 0;; *) return 1;; esac; }
valid_protocol(){ case "$1" in dot|doh|both) return 0;; *) return 1;; esac; }

cfg_has_dot(){
  addr="$1"; sni="$2"
  running_config | awk '{$1=$1;print}' | grep -F "tls upstream $addr" | grep -F "sni $sni" >/dev/null 2>&1
}

cfg_has_doh(){
  url="$1"
  running_config | awk '{$1=$1;print}' | grep -F "https upstream $url" >/dev/null 2>&1
}

iface_block(){
  nd="$1"
  running_config | awk -v n="$nd" '
    $1=="interface" && $2==n {on=1; next}
    on && $1=="!" {exit}
    on {print}
  '
}

iface_ignores(){
  nd="$1"; proto="$2"
  case "$proto" in
    ip) iface_block "$nd" | awk '{$1=$1;print}' | grep -qx 'ip no name-servers' ;;
    ipv6) iface_block "$nd" | awk '{$1=$1;print}' | grep -qx 'ipv6 no name-servers' ;;
    *) return 1 ;;
  esac
}

remove_owned_secure(){
  if [ -f "$OWN_DOT" ]; then
    while IFS='|' read -r addr sni; do
      [ -n "$addr" ] || continue
      ndmc_dns "no dns-proxy tls upstream $addr" >/dev/null || return 1
    done < "$OWN_DOT"
  fi
  if [ -f "$OWN_DOH" ]; then
    while IFS='|' read -r url fmt; do
      [ -n "$url" ] || continue
      ndmc_dns "no dns-proxy https upstream $url" >/dev/null || return 1
    done < "$OWN_DOH"
  fi
  : > "$OWN_DOT"; : > "$OWN_DOH"
}

restore_owned_ignore(){
  [ -f "$OWN_IGNORE" ] || return 0
  while IFS='|' read -r nd proto; do
    [ -n "$nd" ] || continue
    case "$proto" in
      ip) ndmc_dns "interface $nd ip name-servers" >/dev/null || return 1 ;;
      ipv6) ndmc_dns "interface $nd ipv6 name-servers" >/dev/null || return 1 ;;
    esac
  done < "$OWN_IGNORE"
  : > "$OWN_IGNORE"
}

apply_ignore(){
  for nd in $(internet_wans); do
    if ! iface_ignores "$nd" ip; then
      ndmc_dns "interface $nd ip no name-servers" >/dev/null || return 1
      printf '%s|ip\n' "$nd" >> "$OWN_IGNORE"
    fi
    # Ignore IPv6 provider DNS when the command is supported on this WAN.
    if ! iface_ignores "$nd" ipv6; then
      out="$(ndmc_dns "interface $nd ipv6 no name-servers")" || {
        # Some IPv4-only WANs do not expose IPv6 name-server control; do not fail IPv4 DNS setup.
        :
      }
      iface_ignores "$nd" ipv6 && printf '%s|ipv6\n' "$nd" >> "$OWN_IGNORE"
    fi
  done
}

save_state(){
  cat > "$STATE" <<EOF
ENABLED="$1"
PROVIDER="$2"
PROTOCOL="$3"
IGNORE_ISP="$4"
CLEAN_INSTALL="${5:-0}"
LAST_BACKUP="${6:-}"
UPDATED="$(date +%s)"
EOF
}

load_state(){
  ENABLED=0; PROVIDER='cloudflare'; PROTOCOL='both'; IGNORE_ISP=1; CLEAN_INSTALL=0; LAST_BACKUP=''; UPDATED=0
  [ -f "$STATE" ] && . "$STATE"
  : "${CLEAN_INSTALL:=0}"
  : "${LAST_BACKUP:=}"
}

configured_plain_dns_lines(){
  running_config | awk '{$1=$1;print}' | awk '
    /^ip name-server / {print; next}
    /^ipv6 name-server / {print; next}
  '
}

configured_secure_dns_commands(){
  # running-config is the canonical, replayable source.  It preserves the
  # full DoH URI on one line, unlike human-oriented show dns-proxy output
  # which may wrap long URIs across lines.
  running_config | awk '{$1=$1; print}' | awk '
    /^tls upstream / {
      print "dns-proxy " $0
      next
    }
    /^https upstream / {
      print "dns-proxy " $0
      next
    }
  ' | sort -u
}

configured_dns_lines(){
  configured_plain_dns_lines
  configured_secure_dns_commands
}

backup_configured_dns(){
  stamp="$(date +%Y%m%d-%H%M%S)"
  file="$BACKUP_DIR/dns-before-clean-$stamp.conf"
  configured_dns_lines > "$file" || return 1
  chmod 600 "$file" 2>/dev/null || true
  dns_log "BACKUP: $file"
  printf '%s\n' "$file"
}

remove_configured_dns(){
  tmp="$DIR/remove-dns.$$"
  configured_dns_lines > "$tmp" || return 1
  dns_log "CLEAN: discovered $(wc -l < "$tmp" | tr -d ' ') configured DNS records"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    dns_log "CLEAN ITEM: $line"
    case "$line" in
      'dns-proxy tls upstream '*)
        addr="$(printf '%s\n' "$line" | awk '{print $4}')"
        [ -n "$addr" ] || continue
        out="$(ndmc_dns "no dns-proxy tls upstream $addr")" || {
          dns_log "FAIL remove DoT $addr: $out"
          rm -f "$tmp"; return 1;
        }
        ;;
      'dns-proxy https upstream '*)
        url="$(printf '%s\n' "$line" | awk '{print $4}')"
        [ -n "$url" ] || continue
        out="$(ndmc_dns "no dns-proxy https upstream $url")" || {
          dns_log "FAIL remove DoH $url: $out"
          rm -f "$tmp"; return 1;
        }
        ;;
      'ip name-server '*|'ipv6 name-server '*)
        out="$(ndmc_dns "no $line")" || {
          dns_log "FAIL remove plain DNS [$line]: $out"
          rm -f "$tmp"; return 1;
        }
        ;;
    esac
  done < "$tmp"
  rm -f "$tmp"
  : > "$OWN_DOT"; : > "$OWN_DOH"
}

restore_dns_backup(){
  file="$1"
  [ -f "$file" ] || return 0
  dns_log "RESTORE: $file"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    out="$(ndmc_dns "$line")" || {
      dns_log "FAIL restore [$line]: $out"
      return 1
    }
  done < "$file"
}

add_selected_dns(){
  provider="$1"; protocol="$2"
  case "$protocol" in
    both)
      add_selected_dns "$provider" dot || return 1
      add_selected_dns "$provider" doh || return 1
      ;;
    dot)
      provider_dot "$provider" | while IFS='|' read -r addr sni; do
        [ -n "$addr" ] || continue
        if ! cfg_has_dot "$addr" "$sni"; then
          out="$(ndmc_dns "dns-proxy tls upstream $addr sni $sni")" || {
            echo "DoT eklenemedi: $out" >&2
            exit 31
          }
          printf '%s|%s\n' "$addr" "$sni" >> "$OWN_DOT"
        fi
      done
      rc=$?; [ "$rc" -eq 0 ] || return 1
      ;;
    doh)
      provider_doh "$provider" | while IFS='|' read -r url fmt; do
        [ -n "$url" ] || continue
        if ! cfg_has_doh "$url"; then
          out="$(ndmc_dns "dns-proxy https upstream $url $fmt")" || {
            echo "DoH eklenemedi: $out" >&2
            exit 32
          }
          printf '%s|%s\n' "$url" "$fmt" >> "$OWN_DOH"
        fi
      done
      rc=$?; [ "$rc" -eq 0 ] || return 1
      ;;
    *) return 1 ;;
  esac
}

clean_apply(){
  provider="$1"; protocol="$2"; raw_ignore="$3"
  dns_log "ACTION apply provider=$provider protocol=$protocol ignore=$raw_ignore"
  dns_log "ACTION clean-apply provider=$provider protocol=$protocol ignore=$raw_ignore"
  valid_provider "$provider" || { echo 'Geçersiz DNS sağlayıcısı.' >&2; return 2; }
  valid_protocol "$protocol" || { echo 'Geçersiz DNS protokolü.' >&2; return 2; }
  ignore="$(normalize_ignore "$raw_ignore")" || { echo 'Geçersiz ISS DNS seçeneği.' >&2; return 2; }

  restore_owned_ignore || { echo 'Önceki KZSC ISS DNS ayarı geri yüklenemedi.' >&2; return 4; }
  backup="$(backup_configured_dns)" || { echo 'Mevcut DNS yapılandırması yedeklenemedi.' >&2; return 7; }

  if ! remove_configured_dns; then
    restore_dns_backup "$backup" >/dev/null 2>&1 || true
    echo 'Mevcut DNS kayıtları tamamen temizlenemedi; yedek geri yüklenmeye çalışıldı.' >&2
    return 8
  fi

  if [ "$ignore" = "1" ]; then
    if ! apply_ignore; then
      restore_dns_backup "$backup" >/dev/null 2>&1 || true
      echo 'ISS DNS yok sayma ayarı uygulanamadı; DNS yedeği geri yüklenmeye çalışıldı.' >&2
      return 4
    fi
  fi

  if ! add_selected_dns "$provider" "$protocol"; then
    restore_owned_ignore >/dev/null 2>&1 || true
    restore_dns_backup "$backup" >/dev/null 2>&1 || true
    ndmc_dns 'system configuration save' >/dev/null 2>&1 || true
    echo 'Yeni güvenli DNS eklenemedi; önceki DNS yedeği geri yüklenmeye çalışıldı.' >&2
    return 5
  fi

  ndmc_dns 'system configuration save' >/dev/null || {
    restore_owned_ignore >/dev/null 2>&1 || true
    remove_owned_secure >/dev/null 2>&1 || true
    restore_dns_backup "$backup" >/dev/null 2>&1 || true
    ndmc_dns 'system configuration save' >/dev/null 2>&1 || true
    echo 'Keenetic yapılandırması kaydedilemedi; önceki DNS yedeği geri yüklenmeye çalışıldı.' >&2
    return 6
  }

  save_state 1 "$provider" "$protocol" "$ignore" 1 "$backup"
  publish
  echo "Temiz kurulum tamamlandı: $(provider_name "$provider") ${protocol}. Önceki DNS snapshot: $backup"
}

apply(){
  provider="$1"; protocol="$2"; raw_ignore="$3"
  valid_provider "$provider" || { echo 'Geçersiz DNS sağlayıcısı.' >&2; return 2; }
  valid_protocol "$protocol" || { echo 'Geçersiz DNS protokolü.' >&2; return 2; }
  ignore="$(normalize_ignore "$raw_ignore")" || { echo 'Geçersiz ISS DNS seçeneği.' >&2; return 2; }

  # Only remove entries KZSC itself added previously.
  remove_owned_secure || { echo 'Önceki KZSC DNS kayıtları kaldırılamadı.' >&2; return 3; }

  if [ "$ignore" = "1" ]; then
    apply_ignore || { echo 'ISS DNS yok sayma ayarı uygulanamadı.' >&2; return 4; }
  else
    restore_owned_ignore || { echo 'ISS DNS ayarı geri yüklenemedi.' >&2; return 4; }
  fi

  add_selected_dns "$provider" "$protocol" || { echo "${protocol} bileşeni yok veya DNS kaydı eklenemedi." >&2; return 5; }

  ndmc_dns 'system configuration save' >/dev/null || { echo 'Keenetic yapılandırması kaydedilemedi.' >&2; return 6; }
  save_state 1 "$provider" "$protocol" "$ignore" 0 ""
  publish
  echo "$(provider_name "$provider") ${protocol} DNS uygulandı."
}

disable(){
  remove_owned_secure || { echo 'KZSC DNS kayıtları kaldırılamadı.' >&2; return 3; }
  restore_owned_ignore || { echo 'ISS DNS ayarı geri yüklenemedi.' >&2; return 4; }
  ndmc_dns 'system configuration save' >/dev/null || { echo 'Keenetic yapılandırması kaydedilemedi.' >&2; return 6; }
  save_state 0 cloudflare dot 0 0 ""
  publish
  echo 'KZSC DNS devre dışı bırakıldı.'
}

publish(){
  load_state
  tmp="$PUBLIC.tmp.$$"
  wtmp="$DIR/wans.$$"
  : > "$wtmp"
  first=1
  for nd in $(internet_wans); do
    i4=0; i6=0
    iface_ignores "$nd" ip && i4=1
    iface_ignores "$nd" ipv6 && i6=1
    [ "$first" -eq 1 ] || printf ',' >> "$wtmp"
    first=0
    # Prefer the exact connection description configured in Keenetic UI
    # (e.g. TURK TELEKOM FIBER / SUPERONLINE FIBER).
    label="$(iface_config_description "$nd")"
    [ -n "$label" ] || label="$(iface_description "$nd")"
    [ -n "$label" ] || label="$(isp_label "$nd")"
    [ -n "$label" ] || label="$nd"
    printf '{"ndmc":"%s","label":"%s","isp":"%s","ipv4_ignore":%s,"ipv6_ignore":%s}' \
      "$(json_escape "$nd")" "$(json_escape "$label")" "$(json_escape "$(isp_label "$nd")")" "$(json_bool "$i4")" "$(json_bool "$i6")" >> "$wtmp"
  done
  printf '{"enabled":%s,"provider":"%s","provider_name":"%s","protocol":"%s","ignore_isp":%s,"clean_install":%s,"last_backup":"%s","updated":%s,"wans":[' \
    "$(json_bool "$ENABLED")" "$(json_escape "$PROVIDER")" "$(json_escape "$(provider_name "$PROVIDER")")" \
    "$(json_escape "$PROTOCOL")" "$(json_bool "$IGNORE_ISP")" "$(json_bool "$CLEAN_INSTALL")" "$(json_escape "$LAST_BACKUP")" "${UPDATED:-0}" > "$tmp"
  cat "$wtmp" >> "$tmp"
  printf ']}\n' >> "$tmp"
  rm -f "$wtmp"
  mv "$tmp" "$PUBLIC"
  chmod 644 "$PUBLIC" 2>/dev/null || true
}

status(){ publish; cat "$PUBLIC"; }

audit(){
  tmp="$DIR/audit.$$"
  configured_dns_lines > "$tmp" || { rm -f "$tmp"; return 1; }
  count="$(wc -l < "$tmp" | tr -d ' ')"
  printf 'configured_dns_count=%s\n' "$count"
  cat "$tmp"
  rm -f "$tmp"
}

oplog_dns(){
  action="$1"; ok="$2"; msg="$3"
  [ -x /opt/kzsc/bin/kzsc-oplog.sh ] || return 0
  /opt/kzsc/bin/kzsc-oplog.sh append "$action" "$ok" "$msg" "dns-$(date +%s)-$$" >/dev/null 2>&1 || true
}

run_dns_mutation(){
  action="$1"; shift
  fn="$1"; shift
  out="$("$fn" "$@" 2>&1)"; rc=$?
  [ -n "$out" ] && printf '%s\n' "$out"
  if [ "$rc" -eq 0 ]; then
    oplog_dns "$action" true "${out:-DNS işlemi tamamlandı.}"
  else
    oplog_dns "$action" false "${out:-DNS işlemi başarısız.}"
  fi
  return "$rc"
}

case "${1:-status}" in
  apply) run_dns_mutation dns_apply apply "$2" "$3" "$4" ;;
  clean-apply) run_dns_mutation dns_clean_apply clean_apply "$2" "$3" "$4" ;;
  disable) run_dns_mutation dns_disable disable ;;
  status|json) status ;;
  audit) audit ;;
  refresh) publish ;;
  *) echo 'Usage: kzsc-dns {status|refresh|audit|apply PROVIDER both|dot|doh 0|1|clean-apply PROVIDER both|dot|doh 0|1|disable}' >&2; exit 1 ;;
esac
