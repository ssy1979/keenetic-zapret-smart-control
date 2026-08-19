#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh
ROOT="$KZSC_HOME"
BDIR="$ROOT/var/backups"
PUB="$ROOT/www/data/backups"
STATUS="$ROOT/www/data/backup-status.json"
MAX_BACKUP_BYTES=5242880
MAX_EXTRACTED_KB=10240
mkdir -p "$BDIR" "$PUB" "$ROOT/www/data"
safe_backup_name(){
  name="$1"
  case "$name" in
    ''|*/*|*..*|*[!A-Za-z0-9._-]*) return 1 ;;
    kzsc-backup-*.tar.gz) return 0 ;;
    *) return 1 ;;
  esac
}
safe_id(){ case "$1" in ''|*[!a-z0-9_-]*) return 1;; *) return 0;; esac; }
json_file_status(){
  f="$1"; [ -f "$f" ] || { printf '{"available":false}\n'; return; }
  b="${f##*/}"; sz="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"; ts="$(date +%s 2>/dev/null)"
  printf '{"available":true,"filename":"%s","url":"data/backups/%s","size":%s,"updated":%s}\n' "$(json_escape "$b")" "$(json_escape "$b")" "${sz:-0}" "${ts:-0}"
}
publish_status(){
  latest="$(ls -1t "$PUB"/kzsc-backup-*.tar.gz 2>/dev/null | head -n1)"
  t="$STATUS.tmp.$$"; json_file_status "$latest" >"$t"; mv "$t" "$STATUS"; chmod 644 "$STATUS" 2>/dev/null || true
}
create(){
  ts="$(date +%Y%m%d-%H%M%S)"; name="kzsc-backup-$ts.tar.gz"; work="/tmp/kzsc-backup-build.$$"; stage="$work/kzsc-backup"
  rm -rf "$work"; mkdir -p "$stage/etc" "$stage/var/dns" "$stage/var/dpi"
  for f in kzsc.conf isp-map.conf dpi-map.conf; do [ -f "$ROOT/etc/$f" ] && cp "$ROOT/etc/$f" "$stage/etc/$f"; done
  if [ -f "$ROOT/etc/telegram.conf" ]; then
    awk '/^TG_TOKEN=/{print "TG_TOKEN=\"\"";next} /^TG_LAST_UPDATE_ID=|^TG_LAST_SENT=|^TG_LAST_ERROR=/{next} {print}' "$ROOT/etc/telegram.conf" > "$stage/etc/telegram.conf"
  fi
  for f in state.conf owned-dot.list owned-doh.list owned-ignore.list; do [ -f "$ROOT/var/dns/$f" ] && cp "$ROOT/var/dns/$f" "$stage/var/dns/$f"; done
  [ -d "$ROOT/var/dpi/wan-registry" ] && cp -R "$ROOT/var/dpi/wan-registry" "$stage/var/dpi/"
  [ -d "$ROOT/var/dpi/auto-presets" ] && cp -R "$ROOT/var/dpi/auto-presets" "$stage/var/dpi/"
  [ -d "$ROOT/var/dpi/policy" ] && cp -R "$ROOT/var/dpi/policy" "$stage/var/dpi/"
  mkdir -p "$stage/var/dpi/enabled"
  for d in "$ROOT"/var/dpi/engines/*; do [ -d "$d" ] || continue; [ -f "$d/enabled" ] && touch "$stage/var/dpi/enabled/${d##*/}"; done
  cat > "$stage/MANIFEST" <<EOF
format=KZSC_BACKUP_V1
created=$ts
version=0.11.2.41-generic
telegram_token_included=no
EOF
  tar -czf "$BDIR/$name" -C "$work" kzsc-backup || { rm -rf "$work"; echo 'Yedek oluşturulamadı.' >&2; return 1; }
  rm -rf "$work"
  cp "$BDIR/$name" "$PUB/$name" || return 1
  chmod 600 "$BDIR/$name" 2>/dev/null || true
  chmod 644 "$PUB/$name" 2>/dev/null || true
  # Son 5 indirilebilir yedeği tut.
  ls -1t "$PUB"/kzsc-backup-*.tar.gz 2>/dev/null | awk 'NR>5' | xargs -r rm -f 2>/dev/null || true
  ls -1t "$BDIR"/kzsc-backup-*.tar.gz 2>/dev/null | awk 'NR>10' | xargs -r rm -f 2>/dev/null || true
  publish_status
  echo "Yedek oluşturuldu: $name"
}
validate_archive(){
  f="$1"; [ -s "$f" ] || { echo 'Yedek dosyası boş.' >&2; return 1; }
  size="$(wc -c <"$f" 2>/dev/null | tr -d ' ')"
  case "$size" in ''|*[!0-9]*) echo 'Yedek boyutu okunamadı.' >&2; return 1;; esac
  [ "$size" -le "$MAX_BACKUP_BYTES" ] || { echo 'Yedek dosyası 5 MiB sınırını aşıyor.' >&2; return 1; }
  list="$(tar -tzf "$f" 2>/dev/null | tr -d '\r')" || { echo 'Geçersiz veya bozuk tar.gz yedeği.' >&2; return 1; }
  printf '%s\n' "$list" | grep -q '^kzsc-backup/MANIFEST$' || { echo 'KZSC MANIFEST bulunamadı.' >&2; return 1; }
  printf '%s\n' "$list" | grep -Ev '^kzsc-backup(/|$)' | grep -q . && { echo 'Yedekte izin verilmeyen yol var.' >&2; return 1; }
  printf '%s\n' "$list" | grep -E '(^|/)\.\.(/|$)' | grep -q . && { echo 'Yedekte geçersiz üst dizin yolu var.' >&2; return 1; }
  count="$(printf '%s\n' "$list" | awk 'NF{n++} END{print n+0}')"
  [ "$count" -le 256 ] || { echo 'Yedek çok fazla dosya içeriyor.' >&2; return 1; }

  verbose="$(tar -tvzf "$f" 2>/dev/null | tr -d '\r')" || { echo 'Yedek içerik türleri okunamadı.' >&2; return 1; }
  printf '%s\n' "$verbose" | awk 'NF && substr($0,1,1)!="-" && substr($0,1,1)!="d" {exit 1}' \
    || { echo 'Yedekte sembolik bağ veya özel dosya var.' >&2; return 1; }
  printf '%s\n' "$verbose" | awk -v max="$((MAX_EXTRACTED_KB*1024))" '
    {
      size=0
      for(i=2;i<NF;i++) if($i ~ /^[0-9]+$/ && $i>size) size=$i
      total += size
    }
    END {exit(total > max)}
  ' || { echo 'Yedek açıldığında güvenli boyut sınırını aşıyor.' >&2; return 1; }

  bad=0
  while IFS= read -r member; do
    [ -n "$member" ] || continue
    case "$member" in
      kzsc-backup|kzsc-backup/|kzsc-backup/MANIFEST|\
      kzsc-backup/etc|kzsc-backup/etc/|\
      kzsc-backup/etc/kzsc.conf|kzsc-backup/etc/isp-map.conf|kzsc-backup/etc/dpi-map.conf|kzsc-backup/etc/telegram.conf|\
      kzsc-backup/var|kzsc-backup/var/|kzsc-backup/var/dns|kzsc-backup/var/dns/|\
      kzsc-backup/var/dns/state.conf|kzsc-backup/var/dns/owned-dot.list|kzsc-backup/var/dns/owned-doh.list|kzsc-backup/var/dns/owned-ignore.list|\
      kzsc-backup/var/dpi|kzsc-backup/var/dpi/|\
      kzsc-backup/var/dpi/wan-registry|kzsc-backup/var/dpi/wan-registry/|\
      kzsc-backup/var/dpi/auto-presets|kzsc-backup/var/dpi/auto-presets/|\
      kzsc-backup/var/dpi/policy|kzsc-backup/var/dpi/policy/|\
      kzsc-backup/var/dpi/policy/wans|kzsc-backup/var/dpi/policy/wans/|\
      kzsc-backup/var/dpi/policy/devices|kzsc-backup/var/dpi/policy/devices/|\
      kzsc-backup/var/dpi/enabled|kzsc-backup/var/dpi/enabled/)
        ;;
      kzsc-backup/var/dpi/wan-registry/*.queue)
        base="${member##*/}"; safe_id "${base%.queue}" || bad=1
        ;;
      kzsc-backup/var/dpi/wan-registry/*.profile)
        base="${member##*/}"; safe_id "${base%.profile}" || bad=1
        ;;
      kzsc-backup/var/dpi/auto-presets/auto_*.conf)
        base="${member##*/}"; sid="${base#auto_}"; safe_id "${sid%.conf}" || bad=1
        ;;
      kzsc-backup/var/dpi/policy/wans/*/mode|kzsc-backup/var/dpi/policy/wans/*/auto-domains.txt|kzsc-backup/var/dpi/policy/wans/*/exclude-domains.txt)
        base="${member#kzsc-backup/var/dpi/policy/wans/}"; safe_id "${base%%/*}" || bad=1
        ;;
      kzsc-backup/var/dpi/policy/devices/[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f].mode|kzsc-backup/var/dpi/policy/devices/[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f].static-ip)
        ;;
      kzsc-backup/var/dpi/enabled/*)
        base="${member##*/}"; safe_id "$base" || bad=1
        ;;
      *) bad=1 ;;
    esac
  done <<EOF
$list
EOF
  [ "$bad" -eq 0 ] || { echo 'Yedekte izin verilmeyen dosya adı var.' >&2; return 1; }
  return 0
}

validate_assignment_file(){
  f="$1"; allowed="$2"
  [ -f "$f" ] || return 0
  grep -Fq '$' "$f" 2>/dev/null && return 1
  grep -Fq '`' "$f" 2>/dev/null && return 1
  grep -Fq '\' "$f" 2>/dev/null && return 1
  awk -v allowed="$allowed" '
    BEGIN {n=split(allowed,a," "); for(i=1;i<=n;i++) ok[a[i]]=1}
    /^[[:space:]]*($|#)/ {next}
    {
      line=$0
      key=line; sub(/=.*/,"",key)
      if(!ok[key] || line !~ /^[A-Z][A-Z0-9_]*="[^"]*"$/) bad=1
    }
    END {exit bad}
  ' "$f"
}

validate_extracted(){
  s="$1"
  kb="$(du -sk "$s" 2>/dev/null | awk '{print $1}')"
  case "$kb" in ''|*[!0-9]*) return 1;; esac
  [ "$kb" -le "$MAX_EXTRACTED_KB" ] || return 1

  validate_assignment_file "$s/etc/kzsc.conf" 'KZSC_PORT KZSC_BIND_IP KZSC_INTERVAL KZSC_FAST_INTERVAL KZSC_HEAVY_REFRESH_INTERVAL KZSC_MODE KZSC_POLICY_DIR KZSC_WAN_AUTO_VALIDATE KZSC_WAN_AUTO_ENABLE_NEW KZSC_WAN_REVALIDATE_RETRY_SECONDS KZSC_WAN_INTERVAL KZSC_WAN_PING_COUNT KZSC_WAN_TARGETS KZSC_WAN_HISTORY_LINES KZSC_BLOCKCHECK_AUTO_APPLY KZSC_BLOCKCHECK_MAX_SECONDS KZSC_BLOCKCHECK_NIGHTLY KZSC_BLOCKCHECK_NIGHTLY_HOUR KZSC_BLOCKCHECK_NIGHTLY_MODE KZSC_UPDATE_CHECK_INTERVAL KZSC_UPDATE_AUTO KZSC_KEENDNS_REMOTE KZSC_QUEUE_BASE KZSC_QUEUE_MAX' \
    || { echo 'Yedekte güvenli olmayan KZSC yapılandırması var.' >&2; return 1; }
  validate_assignment_file "$s/etc/telegram.conf" 'TG_ENABLED TG_TOKEN TG_CHAT_ID TG_NOTIFY_WAN TG_NOTIFY_DPI TG_NOTIFY_BLOCKCHECK TG_NOTIFY_DNS TG_NOTIFY_ZAPRET2 TG_NOTIFY_SYSTEM TG_COMMANDS_ENABLED TG_LAST_UPDATE_ID TG_LAST_SENT TG_LAST_ERROR' \
    || { echo 'Yedekte güvenli olmayan Telegram yapılandırması var.' >&2; return 1; }

  for qf in "$s"/var/dpi/wan-registry/*.queue; do
    [ -f "$qf" ] || continue
    q="$(tr -d '\r\n' <"$qf")"
    case "$q" in ''|*[!0-9]*) echo 'Yedekte geçersiz DPI queue kaydı var.' >&2; return 1;; esac
    [ "$q" -ge 320 ] && [ "$q" -le 399 ] || { echo 'Yedekte izin verilmeyen DPI queue numarası var.' >&2; return 1; }
  done
  for pf in "$s"/var/dpi/wan-registry/*.profile; do
    [ -f "$pf" ] || continue
    sid="${pf##*/}"; sid="${sid%.profile}"; profile="$(tr -d '\r\n' <"$pf")"
    case "$profile" in kablonet|sol|tt-fiber|vodafone|vodafone-tt|vodafone-tt2) [ -f "$KZSC_HOME/share/dpi-presets/$profile.conf" ] || { echo 'Yedekte geçersiz DPI profil eşlemesi var.' >&2; return 1; };; "auto_$sid") :;; *) echo 'Yedekte geçersiz DPI profil eşlemesi var.' >&2; return 1;; esac
  done
  for af in "$s"/var/dpi/auto-presets/auto_*.conf; do
    [ -f "$af" ] || continue
    validate_assignment_file "$af" 'ID NAME SOURCE HTTP_OPT TLS_OPT UDP_OPT NO_UDP MATCH' \
      || { echo 'Yedekte güvenli olmayan AUTO DPI profili var.' >&2; return 1; }
    sid="${af##*/}"; sid="${sid#auto_}"; sid="${sid%.conf}"
    aid="$(sed -n 's/^ID="\([^"]*\)"$/\1/p' "$af" | head -n1)"
    [ "$aid" = "auto_$sid" ] || { echo 'Yedekte AUTO DPI profil kimliği dosya adıyla eşleşmiyor.' >&2; return 1; }
  done
  for mf in "$s"/var/dpi/policy/wans/*/mode; do
    [ -f "$mf" ] || continue
    case "$(tr -d '\r\n' <"$mf")" in all|auto) :;; *) echo 'Yedekte geçersiz DPI çalışma modu var.' >&2; return 1;; esac
  done
  for lf in "$s"/var/dpi/policy/wans/*/auto-domains.txt "$s"/var/dpi/policy/wans/*/exclude-domains.txt; do
    [ -f "$lf" ] || continue
    awk 'NF && $0 !~ /^\^?[a-z0-9]([a-z0-9.-]*[a-z0-9])?$/ {bad=1} END{exit bad}' "$lf" || { echo 'Yedekte geçersiz DPI alan adı listesi var.' >&2; return 1; }
  done
  for sf in "$s"/var/dpi/policy/devices/*.static-ip; do
    [ -f "$sf" ] || continue
    awk -F. 'NF==4 {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || $i<0 || $i>255) exit 1; exit 0} {exit 1}' "$sf" || { echo 'Yedekte geçersiz DHCP sabit IP kaydı var.' >&2; return 1; }
  done
  return 0
}
resolve_restore_file(){
  f="$1"
  [ -n "$f" ] || { printf '%s\n' ''; return; }
  case "$f" in
    */*) printf '%s\n' "$f" ;;
    kzsc-backup-*.tar.gz)
      if [ -s "$BDIR/$f" ]; then printf '%s\n' "$BDIR/$f"
      elif [ -s "$PUB/$f" ]; then printf '%s\n' "$PUB/$f"
      else printf '%s\n' "$f"
      fi
      ;;
    *) printf '%s\n' "$f" ;;
  esac
}
restore(){
  f="$(resolve_restore_file "$1")"; validate_archive "$f" || return 1
  work="/tmp/kzsc-backup-restore.$$"; rm -rf "$work"; mkdir -p "$work"
  tar -xzf "$f" -C "$work" || { rm -rf "$work"; echo 'Yedek açılamadı.' >&2; return 1; }
  s="$work/kzsc-backup"; grep -q '^format=KZSC_BACKUP_V1$' "$s/MANIFEST" || { rm -rf "$work"; echo 'Desteklenmeyen yedek biçimi.' >&2; return 1; }
  validate_extracted "$s" || { rm -rf "$work"; echo 'Yedek içeriği güvenlik doğrulamasını geçemedi.' >&2; return 1; }
  oldtok="$(sed -n 's/^TG_TOKEN="\(.*\)"$/\1/p' "$ROOT/etc/telegram.conf" 2>/dev/null | tail -n1)"
  /opt/kzsc/bin/kzsc-native-dpi.sh disable-all >/dev/null 2>&1 || true
  for x in kzsc.conf isp-map.conf dpi-map.conf; do [ -f "$s/etc/$x" ] && cp "$s/etc/$x" "$ROOT/etc/$x"; done
  if [ -f "$s/etc/telegram.conf" ]; then
    awk '!/^TG_LAST_UPDATE_ID=/ && !/^TG_LAST_SENT=/ && !/^TG_LAST_ERROR=/' "$s/etc/telegram.conf" > "$ROOT/etc/telegram.conf.tmp.$$" &&
      mv "$ROOT/etc/telegram.conf.tmp.$$" "$ROOT/etc/telegram.conf"
    [ -n "$oldtok" ] && awk -v v="$oldtok" '/^TG_TOKEN=/{print "TG_TOKEN=\""v"\"";next}{print}' "$ROOT/etc/telegram.conf" > "$ROOT/etc/telegram.conf.tmp.$$" && mv "$ROOT/etc/telegram.conf.tmp.$$" "$ROOT/etc/telegram.conf"
    chmod 600 "$ROOT/etc/telegram.conf" 2>/dev/null || true
  fi
  mkdir -p "$ROOT/var/dns" "$ROOT/var/dpi"
  for x in state.conf owned-dot.list owned-doh.list owned-ignore.list; do [ -f "$s/var/dns/$x" ] && cp "$s/var/dns/$x" "$ROOT/var/dns/$x"; done
  if [ -d "$s/var/dpi/wan-registry" ]; then rm -rf "$ROOT/var/dpi/wan-registry"; cp -R "$s/var/dpi/wan-registry" "$ROOT/var/dpi/"; fi
  if [ -d "$s/var/dpi/auto-presets" ]; then rm -rf "$ROOT/var/dpi/auto-presets"; cp -R "$s/var/dpi/auto-presets" "$ROOT/var/dpi/"; fi
  if [ -d "$s/var/dpi/policy" ]; then rm -rf "$ROOT/var/dpi/policy"; cp -R "$s/var/dpi/policy" "$ROOT/var/dpi/"; fi
  /opt/kzsc/bin/kzsc-wan-registry.sh refresh >/dev/null 2>&1 || true
  /opt/kzsc/bin/kzsc-engines.sh refresh >/dev/null 2>&1 || true
  if [ -d "$s/var/dpi/enabled" ]; then
    for m in "$s"/var/dpi/enabled/*; do [ -e "$m" ] || continue; id="${m##*/}"; for nd in $(internet_wans); do [ "$(printf '%s' "$nd"|tr ' A-Z/:.' '_a-z___'|tr -cd 'a-z0-9_-')" = "$id" ] && /opt/kzsc/bin/kzsc-native-dpi.sh enable "$nd" >/dev/null 2>&1 || true; done; done
  fi
  for sf in "$ROOT"/var/dpi/policy/devices/*.static-ip; do
    [ -f "$sf" ] || continue
    id="${sf##*/}"; id="${id%.static-ip}"
    mac="$(printf '%s' "$id" | sed 's/\(..\)/\1:/g;s/:$//')"
    /opt/kzsc/bin/kzsc-dpi-policy.sh static "$mac" "$(tr -d '\r\n' <"$sf")" >/dev/null 2>&1 || true
  done
  /opt/kzsc/bin/kzsc-dns.sh refresh >/dev/null 2>&1 || true
  /opt/kzsc/bin/kzsc-telegram.sh publish-status >/dev/null 2>&1 || true
  rm -rf "$work"
  echo 'KZSC yedeği geri yüklendi. Telegram Bot Token güvenlik nedeniyle mevcut cihazdaki değer olarak korundu.'
}
send_telegram(){
  name="${1:-}"
  if [ -n "$name" ]; then safe_backup_name "$name" || { echo 'Geçersiz yedek adı.' >&2; return 1; }; target="$BDIR/$name"
  else target="$(ls -1t "$BDIR"/kzsc-backup-*.tar.gz 2>/dev/null | head -n1)"
  fi
  [ -f "$target" ] || { echo 'Gönderilecek yedek bulunamadı.' >&2; return 1; }
  /opt/kzsc/bin/kzsc-telegram.sh send-file "$target" "KZSC yedeği · $(router_model) · $(date '+%Y-%m-%d %H:%M')"
}
delete_backup(){
  name="${1:-}"
  safe_backup_name "$name" || { echo 'Geçersiz yedek adı.' >&2; return 1; }
  found=0
  [ -f "$BDIR/$name" ] && { rm -f "$BDIR/$name" || return 1; found=1; }
  [ -f "$PUB/$name" ] && { rm -f "$PUB/$name" || return 1; found=1; }
  [ "$found" -eq 1 ] || { echo 'Silinecek yedek bulunamadı.' >&2; return 1; }
  publish_status
  echo "Yedek silindi: $name"
}
case "${1:-status}" in
 create) create;;
 restore) restore "$2";;
 send-telegram) send_telegram "$2";;
 delete) delete_backup "$2";;
 status) publish_status; cat "$STATUS";;
 *) echo 'Usage: kzsc-backup {create|restore FILE|send-telegram [FILE]|delete FILE|status}' >&2; exit 1;;
esac
