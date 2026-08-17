#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

VERSION="0.11.2.14-generic"
OUT="$KZSC_HOME/www/data/maintenance.json"
RESULT="$KZSC_HOME/www/data/maintenance-result.json"
PROGRESS="$KZSC_HOME/www/data/maintenance-progress.json"
RESULT_DIR="$KZSC_HOME/www/data/maintenance-results"
PROGRESS_DIR="$KZSC_HOME/www/data/maintenance-progress"
QUEUE="$KZSC_HOME/var/run/maintenance-queue"

mkdir -p "$KZSC_HOME/www/data" "$QUEUE" "$RESULT_DIR" "$PROGRESS_DIR"
chmod 755 "$RESULT_DIR" "$PROGRESS_DIR" 2>/dev/null || true
/opt/kzsc/bin/kzsc-oplog.sh publish >/dev/null 2>&1 || true

uptime_text(){
  sec="$(cut -d. -f1 /proc/uptime 2>/dev/null)"
  case "$sec" in ''|*[!0-9]*) sec=0;; esac
  d=$((sec/86400)); h=$(((sec%86400)/3600)); m=$(((sec%3600)/60))
  if [ "$d" -gt 0 ]; then printf '%sg %ss %sd' "$d" "$h" "$m"
  elif [ "$h" -gt 0 ]; then printf '%ss %sd' "$h" "$m"
  else printf '%sd' "$m"; fi
}

mem_info(){
  total="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)"
  avail="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null)"
  [ -n "$avail" ] || avail="$(awk '/^MemFree:/ {print $2}' /proc/meminfo 2>/dev/null)"
  case "$total" in ''|*[!0-9]*) total=0;; esac
  case "$avail" in ''|*[!0-9]*) avail=0;; esac
  used=$((total-avail)); [ "$used" -lt 0 ] && used=0
  printf '%s|%s' "$used" "$total"
}

opt_info(){
  df -k /opt 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $3"|"$2"|"$5; exit}'
}

proc_state_exact(){
  p="$1"; pat="$2"
  [ -n "$p" ] || { printf stopped; return; }
  kill -0 "$p" 2>/dev/null || { printf stopped; return; }
  if [ -n "$pat" ]; then
    ps w 2>/dev/null | awk -v p="$p" -v pat="$pat" '$1==p && index($0,pat)>0 {ok=1} END{exit !ok}' \
      && printf running || printf stopped
  else
    printf running
  fi
}

snapshot(){
  daemon_pid=""
  [ -f "$KZSC_HOME/var/run/daemon.lock/pid" ] && daemon_pid="$(cat "$KZSC_HOME/var/run/daemon.lock/pid" 2>/dev/null)"
  [ -n "$daemon_pid" ] || daemon_pid="$(cat "$KZSC_PID" 2>/dev/null || true)"
  web_pid="$(cat "$KZSC_HTTP_PID" 2>/dev/null || true)"

  mem="$(mem_info)"; mem_used="${mem%%|*}"; mem_total="${mem#*|}"
  opt="$(opt_info)"
  if [ -n "$opt" ]; then
    opt_used="${opt%%|*}"; rest="${opt#*|}"; opt_total="${rest%%|*}"; opt_pct="${rest#*|}"
  else
    opt_used=0; opt_total=0; opt_pct=0
  fi

  model="$(router_model)"
  kos="$(keenetic_version)"
  [ -n "$model" ] || model="unknown"
  [ -n "$kos" ] || kos="unknown"

  ts="$(date +%s 2>/dev/null)"
  case "$ts" in ''|*[!0-9]*) ts=0;; esac

  tmp="$OUT.tmp.$$"
  printf '{"timestamp":%s,"version":"%s","model":"%s","keeneticos":"%s","arch":"%s","uptime":"%s",' \
    "$ts" "$VERSION" "$(json_escape "$model")" "$(json_escape "$kos")" \
    "$(json_escape "$(uname -m)")" "$(json_escape "$(uptime_text)")" > "$tmp"

  printf '"memory":{"used_kb":%s,"total_kb":%s},"opt":{"used_kb":%s,"total_kb":%s,"percent":%s},' \
    "$mem_used" "$mem_total" "$opt_used" "$opt_total" "$opt_pct" >> "$tmp"

  printf '"daemon":{"state":"%s","pid":"%s"},"web":{"state":"%s","pid":"%s"},' \
    "$(proc_state_exact "$daemon_pid" 'kzsc-daemon.sh')" "$daemon_pid" \
    "$(proc_state_exact "$web_pid" 'lighttpd')" "$web_pid" >> "$tmp"

  printf '"zapret":"%s"}\n' "$(zapret_status)" >> "$tmp"
  mv "$tmp" "$OUT"
  chmod 644 "$OUT" 2>/dev/null || true
}

publish_progress(){
 rid="$1"; action="$2"; state="$3"; ts="$(date +%s)"
 safe="$(printf '%s' "$rid" | tr -cd 'A-Za-z0-9_.-')"; [ -n "$safe" ] || safe=invalid
 f="$PROGRESS_DIR/$safe.json"; t="$f.tmp.$$"
 printf '{"request_id":"%s","action":"%s","state":"%s","timestamp":%s}\n' \
  "$(json_escape "$rid")" "$(json_escape "$action")" "$(json_escape "$state")" "$ts" >"$t"
 mv "$t" "$f"; chmod 644 "$f" 2>/dev/null || true
 cp "$f" "$PROGRESS.tmp.$$" 2>/dev/null && mv "$PROGRESS.tmp.$$" "$PROGRESS"
}

write_result(){
 rid="$1"; action="$2"; ok="$3"; msg="$4"; ts="$(date +%s)"
 msg="$(printf '%s' "$msg" | tr '\r\n' '  ')"
 safe="$(printf '%s' "$rid" | tr -cd 'A-Za-z0-9_.-')"; [ -n "$safe" ] || safe=invalid
 f="$RESULT_DIR/$safe.json"; t="$f.tmp.$$"
 line="$(printf '{"request_id":"%s","action":"%s","ok":%s,"message":"%s","timestamp":%s}' \
  "$(json_escape "$rid")" "$(json_escape "$action")" "$ok" "$(json_escape "$msg")" "$ts")"
 printf '%s\n' "$line" >"$t"; mv "$t" "$f"; chmod 644 "$f" 2>/dev/null || true
 cp "$f" "$RESULT.tmp.$$" 2>/dev/null && mv "$RESULT.tmp.$$" "$RESULT"
}

publish_result(){
 rid="$1"; action="$2"; ok="$3"; msg="$4"
 write_result "$rid" "$action" "$ok" "$msg"
 notify=1
 # Availability is notified exactly once by kzsc-updater.sh. Keep the manual
 # check in Event Log without sending a duplicate Telegram message.
 [ "$action" = kzsc_update_check ] && notify=0
 /opt/kzsc/bin/kzsc-oplog.sh append "$action" "$ok" "$msg" "$rid" "$ts" "$notify" >/dev/null 2>&1 || true
}

valid_backup_name(){
  name="$1"
  case "$name" in
    ''|*/*|*..*|*[!A-Za-z0-9._-]*) return 1 ;;
    kzsc-backup-*.tar.gz) return 0 ;;
    *) return 1 ;;
  esac
}

clear_history(){
  : > "$KZSC_HOME/www/data/wan-history.ndjson"
  : > "$KZSC_HOME/www/data/wan-events.ndjson"
  rm -rf "$KZSC_HOME/var/run/wan-state"
  mkdir -p "$KZSC_HOME/var/run/wan-state"
}

clear_logs(){
  for f in "$KZSC_HOME"/var/log/*.log; do
    [ -f "$f" ] && : > "$f"
  done
}

zapret2_ready_postcondition(){
  zjson="$(/opt/kzsc/bin/kzsc-zapret2.sh status 2>/dev/null)" || return 1
  printf '%s' "$zjson" | grep -q '"installed":true' || return 1
  printf '%s' "$zjson" | grep -q '"lua_ok":true' || return 1
  printf '%s' "$zjson" | grep -q '"nfqws2":{"exists":true,"exec":true}' || return 1
  printf '%s' "$zjson" | grep -q '"mdig":{"exists":true,"exec":true}' || return 1
  printf '%s' "$zjson" | grep -q '"ip2net":{"exists":true,"exec":true}' || return 1
  return 0
}

zapret2_removed_postcondition(){
  zjson="$(/opt/kzsc/bin/kzsc-zapret2.sh status 2>/dev/null)" || return 1
  printf '%s' "$zjson" | grep -q '"installed":false'
}

run_action(){
  ACTION_MSG=""
  case "$1" in
    refresh)
      failed=0
      /opt/kzsc/bin/kzsc-discover.sh >/dev/null 2>&1 || failed=1
      /opt/kzsc/bin/kzsc-clients.sh >/dev/null 2>&1 || failed=1
      /opt/kzsc/bin/kzsc-wan.sh check >/dev/null 2>&1 || failed=1
      /opt/kzsc/bin/kzsc-wan-registry.sh refresh >/dev/null 2>&1 || failed=1
      /opt/kzsc/bin/kzsc-engines.sh refresh >/dev/null 2>&1 || failed=1
      if [ "$failed" -eq 0 ]; then
        ACTION_MSG="Veriler başarıyla yenilendi."
        log "maintenance: refresh complete"
        return 0
      fi
      ACTION_MSG="Veriler yenilenirken en az bir alt işlem başarısız oldu."
      log "maintenance: refresh failed"
      return 1
      ;;
    keendns_enable)
      ACTION_MSG="$(/opt/kzsc/bin/kzsc-keendns.sh enable 2>&1)"; return $?
      ;;
    keendns_disable)
      ACTION_MSG="$(/opt/kzsc/bin/kzsc-keendns.sh disable 2>&1)"; return $?
      ;;
    wan_check)
      if /opt/kzsc/bin/kzsc-wan.sh check >/dev/null 2>&1; then
        ACTION_MSG="WAN testi başarıyla tamamlandı."
        log "maintenance: wan_check complete"
        return 0
      fi
      ACTION_MSG="WAN testi başarısız oldu."
      log "maintenance: wan_check failed"
      return 1
      ;;
    dpi_repair)
      if /opt/kzsc/bin/kzsc-native-dpi.sh ensure-all >/dev/null 2>&1; then
        ACTION_MSG="DPI motor kontrolü başarıyla tamamlandı."
        log "maintenance: dpi_repair complete"
        return 0
      fi
      ACTION_MSG="DPI motor kontrolü başarısız oldu."
      log "maintenance: dpi_repair failed"
      return 1
      ;;
    clear_history)
      if clear_history; then
        ACTION_MSG="WAN geçmişi ve olay günlüğü temizlendi."
        log "maintenance: history cleared"
        return 0
      fi
      ACTION_MSG="WAN geçmişi temizlenemedi."
      return 1
      ;;
    clear_logs)
      if clear_logs; then
        ACTION_MSG="KZSC logları temizlendi."
        return 0
      fi
      ACTION_MSG="KZSC logları temizlenemedi."
      return 1
      ;;
    zapret2_install)
      /opt/kzsc/bin/kzsc-zapret2.sh install >/tmp/kzsc-z2.$$ 2>&1
      rc=$?; ACTION_MSG="$(cat /tmp/kzsc-z2.$$ 2>/dev/null)"; rm -f /tmp/kzsc-z2.$$
      /opt/kzsc/bin/kzsc-engines.sh refresh >/dev/null 2>&1 || true

      if zapret2_ready_postcondition; then
        [ -n "$ACTION_MSG" ] || ACTION_MSG="KZSC Zapret2 kurulumu tamamlandı."
        return 0
      fi

      [ -n "$ACTION_MSG" ] || ACTION_MSG="KZSC Zapret2 kurulamadı."
      return 1
      ;;
    zapret2_update)
      /opt/kzsc/bin/kzsc-zapret2.sh update >/tmp/kzsc-z2.$$ 2>&1
      rc=$?; ACTION_MSG="$(cat /tmp/kzsc-z2.$$ 2>/dev/null)"; rm -f /tmp/kzsc-z2.$$
      /opt/kzsc/bin/kzsc-engines.sh refresh >/dev/null 2>&1 || true

      if zapret2_ready_postcondition; then
        [ -n "$ACTION_MSG" ] || ACTION_MSG="KZSC Zapret2 güncellemesi tamamlandı."
        return 0
      fi

      [ -n "$ACTION_MSG" ] || ACTION_MSG="KZSC Zapret2 güncellenemedi."
      return 1
      ;;
    zapret2_repair)
      /opt/kzsc/bin/kzsc-zapret2.sh repair >/tmp/kzsc-z2.$$ 2>&1
      rc=$?; ACTION_MSG="$(cat /tmp/kzsc-z2.$$ 2>/dev/null)"; rm -f /tmp/kzsc-z2.$$
      /opt/kzsc/bin/kzsc-engines.sh refresh >/dev/null 2>&1 || true

      if zapret2_ready_postcondition; then
        [ -n "$ACTION_MSG" ] || ACTION_MSG="KZSC Zapret2 onarımı tamamlandı."
        return 0
      fi

      [ -n "$ACTION_MSG" ] || ACTION_MSG="KZSC Zapret2 onarılamadı."
      return 1
      ;;
    zapret2_remove)
      /opt/kzsc/bin/kzsc-zapret2.sh remove >/tmp/kzsc-z2.$$ 2>&1
      rc=$?; ACTION_MSG="$(cat /tmp/kzsc-z2.$$ 2>/dev/null)"; rm -f /tmp/kzsc-z2.$$
      /opt/kzsc/bin/kzsc-engines.sh refresh >/dev/null 2>&1 || true

      if zapret2_removed_postcondition; then
        [ -n "$ACTION_MSG" ] || ACTION_MSG="KZSC Zapret2 kaldırıldı."
        return 0
      fi

      [ -n "$ACTION_MSG" ] || ACTION_MSG="KZSC Zapret2 kaldırılamadı."
      return 1
      ;;
    kzsc_update_check)
      ACTION_MSG="$(/opt/kzsc/bin/kzsc-updater.sh check 2>&1)"
      rc=$?
      [ -n "$ACTION_MSG" ] || ACTION_MSG="KZSC güncelleme kontrolü tamamlandı."
      return "$rc"
      ;;
    kzsc_update_install)
      ACTION_MSG="$(/opt/kzsc/bin/kzsc-updater.sh install 2>&1)"
      rc=$?
      [ -n "$ACTION_MSG" ] || ACTION_MSG="KZSC güncelleme işçisi başlatıldı."
      return "$rc"
      ;;
    kzsc_update_auto_on)
      ACTION_MSG="$(/opt/kzsc/bin/kzsc-updater.sh auto 1 2>&1)"
      rc=$?
      [ -n "$ACTION_MSG" ] || ACTION_MSG="Otomatik KZSC güncellemesi açıldı."
      return "$rc"
      ;;
    kzsc_update_auto_off)
      ACTION_MSG="$(/opt/kzsc/bin/kzsc-updater.sh auto 0 2>&1)"
      rc=$?
      [ -n "$ACTION_MSG" ] || ACTION_MSG="Otomatik KZSC güncellemesi kapatıldı."
      return "$rc"
      ;;

    restart)
      ACTION_MSG="KZSC yeniden başlatma komutu kabul edildi."
      log "maintenance: restart requested"
      return 0
      ;;
  esac
  ACTION_MSG="Desteklenmeyen bakım işlemi."
  return 1
}

process_telegram_inbox(){
  for tf in /tmp/kzsc-telegram-req.*; do
    [ -f "$tf" ] || continue
    rid="${tf##*/kzsc-telegram-req.}"
    action="$(cat "$tf" 2>/dev/null | tr -d '\r\n')"
    rm -f "$tf"
    case "$action" in
      telegram_save)
        payload="/tmp/kzsc-telegram-payload.$rid"
        if [ ! -f "$payload" ]; then
          publish_result "$rid" "telegram_save" false "Telegram ayar istegi bulunamadi."
          continue
        fi
        body="$(cat "$payload" 2>/dev/null)"; rm -f "$payload"
        urldecode(){ printf '%b' "$(printf '%s' "$1"|sed 's/+/ /g;s/%/\\x/g')"; }
        set --; oifs="$IFS"; IFS='&'
        for pair in $body; do
          k="${pair%%=*}"; v="$(urldecode "${pair#*=}")"
          case "$k" in enabled|token|chat_id|wan|dpi|blockcheck|dns|zapret2|system|commands) set -- "$@" "$k=$v";; esac
        done
        IFS="$oifs"
        /opt/kzsc/bin/kzsc-telegram.sh save "$@" >/tmp/kzsc-tg.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-tg.$$ 2>/dev/null)"; rm -f /tmp/kzsc-tg.$$
        /opt/kzsc/bin/kzsc-telegram.sh publish-status >/dev/null 2>&1 || true
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Telegram ayarlari kaydedilemedi."
        [ "$rc" -eq 0 ] && publish_result "$rid" "telegram_save" true "$ACTION_MSG" || publish_result "$rid" "telegram_save" false "$ACTION_MSG"
        ;;
      telegram_test)
        /opt/kzsc/bin/kzsc-telegram.sh test >/tmp/kzsc-tg.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-tg.$$ 2>/dev/null)"; rm -f /tmp/kzsc-tg.$$
        /opt/kzsc/bin/kzsc-telegram.sh publish-status >/dev/null 2>&1 || true
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Telegram test sonucu alinamadi."
        [ "$rc" -eq 0 ] && publish_result "$rid" "telegram_test" true "$ACTION_MSG" || publish_result "$rid" "telegram_test" false "$ACTION_MSG"
        ;;
      telegram_find_chat)
        /opt/kzsc/bin/kzsc-telegram.sh find-chat >/tmp/kzsc-tg.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-tg.$$ 2>/dev/null)"; rm -f /tmp/kzsc-tg.$$
        /opt/kzsc/bin/kzsc-telegram.sh publish-status >/dev/null 2>&1 || true
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Chat ID bulunamadi."
        [ "$rc" -eq 0 ] && publish_result "$rid" "telegram_find_chat" true "$ACTION_MSG" || publish_result "$rid" "telegram_find_chat" false "$ACTION_MSG"
        ;;
      *)
        rm -f "/tmp/kzsc-telegram-payload.$rid" 2>/dev/null || true
        publish_result "$rid" "telegram" false "Gecersiz Telegram islemi."
        ;;
    esac
  done
}

process_backup_inbox(){
  for bf in /tmp/kzsc-backup-req.*; do
    [ -f "$bf" ] || continue
    rid="${bf##*/kzsc-backup-req.}"
    action="$(cat "$bf" 2>/dev/null | tr -d '\r\n')"
    rm -f "$bf"

    case "$action" in
      backup_create)
        /opt/kzsc/bin/kzsc-backup.sh create >/tmp/kzsc-backup.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-backup.$$ 2>/dev/null)"; rm -f /tmp/kzsc-backup.$$
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Yedek oluşturulamadı."
        [ "$rc" -eq 0 ] && publish_result "$rid" "backup_create" true "$ACTION_MSG" || publish_result "$rid" "backup_create" false "$ACTION_MSG"
        ;;
      backup_telegram:*)
        name="${action#backup_telegram:}"
        valid_backup_name "$name" || { publish_result "$rid" "backup_telegram" false "Geçersiz yedek adı."; continue; }
        /opt/kzsc/bin/kzsc-backup.sh send-telegram "$name" >/tmp/kzsc-backup.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-backup.$$ 2>/dev/null)"; rm -f /tmp/kzsc-backup.$$
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Yedek Telegram'a gönderilemedi."
        [ "$rc" -eq 0 ] && publish_result "$rid" "backup_telegram" true "Telegram'a gönderildi: $name" || publish_result "$rid" "backup_telegram" false "$ACTION_MSG"
        ;;
      backup_restore_saved:*)
        name="${action#backup_restore_saved:}"
        valid_backup_name "$name" || { publish_result "$rid" "backup_restore" false "Geçersiz yedek adı."; continue; }
        saved="/opt/kzsc/var/backups/$name"
        [ -s "$saved" ] || { publish_result "$rid" "backup_restore" false "Kayıtlı yedek bulunamadı: $name"; continue; }
        /opt/kzsc/bin/kzsc-backup.sh restore "$saved" >/tmp/kzsc-backup.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-backup.$$ 2>/dev/null)"; rm -f /tmp/kzsc-backup.$$
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Yedek geri yüklenemedi."
        [ "$rc" -eq 0 ] && publish_result "$rid" "backup_restore" true "Kayıtlı yedek geri yüklendi: $name" || publish_result "$rid" "backup_restore" false "$ACTION_MSG"
        ;;
      backup_restore)
        upload="/tmp/kzsc-backup-upload.$rid"
        if [ ! -s "$upload" ]; then
          rm -f "$upload" 2>/dev/null || true
          publish_result "$rid" "backup_restore" false "Yüklenen yedek dosyası bulunamadı veya boş."
          continue
        fi
        /opt/kzsc/bin/kzsc-backup.sh restore "$upload" >/tmp/kzsc-backup.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-backup.$$ 2>/dev/null)"; rm -f /tmp/kzsc-backup.$$ "$upload"
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Yedek geri yüklenemedi."
        [ "$rc" -eq 0 ] && publish_result "$rid" "backup_restore" true "$ACTION_MSG" || publish_result "$rid" "backup_restore" false "$ACTION_MSG"
        ;;
      backup_delete:*)
        name="${action#backup_delete:}"
        valid_backup_name "$name" || { publish_result "$rid" "backup_delete" false "Geçersiz yedek adı."; continue; }
        /opt/kzsc/bin/kzsc-backup.sh delete "$name" >/tmp/kzsc-backup.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-backup.$$ 2>/dev/null)"; rm -f /tmp/kzsc-backup.$$
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Yedek silinemedi."
        [ "$rc" -eq 0 ] && publish_result "$rid" "backup_delete" true "$ACTION_MSG" || publish_result "$rid" "backup_delete" false "$ACTION_MSG"
        ;;
      backup_download:*)
        name="${action#backup_download:}"
        if valid_backup_name "$name"; then
          publish_result "$rid" "backup_download" true "Yedek indirildi: $name"
        else
          publish_result "$rid" "backup_download" false "Geçersiz yedek adı."
        fi
        ;;
      *)
        rm -f "/tmp/kzsc-backup-upload.$rid" 2>/dev/null || true
        publish_result "$rid" "backup" false "Geçersiz yedekleme işlemi."
        ;;
    esac
  done
}

process_queue(){
  mkdir -p "$QUEUE"
  process_telegram_inbox
  process_backup_inbox
  for f in "$QUEUE"/req.*; do
    [ -f "$f" ] || continue
    line="$(cat "$f" 2>/dev/null | tr -d '\r\n')"
    rm -f "$f"

    case "$line" in
      *'|'*)
        rid="${line%%|*}"
        action="${line#*|}"
        ;;
      *)
        log "maintenance: malformed queue record rejected"
        continue
        ;;
    esac

    publish_progress "$rid" "$action" "processing"

    case "$action" in
      ui_event:*)
        rest="${action#ui_event:}"
        event="${rest%%:*}"
        event_ok="${rest#*:}"
        case "$event:$event_ok" in
          keendns_copy:true) msg='KeenDNS adresi panoya kopyalandı.' ;;
          keendns_copy:false) msg='KeenDNS adresi panoya kopyalanamadı.' ;;
          keendns_open:true) msg='KeenDNS paneli yeni sekmede açıldı.' ;;
          *) write_result "$rid" "ui_event" false "Desteklenmeyen arayüz olayı."; continue ;;
        esac
        if /opt/kzsc/bin/kzsc-oplog.sh append "$event" "$event_ok" "$msg" "$rid" >/dev/null 2>&1; then
          write_result "$rid" "$event" true "Olay Günlüğü kaydı oluşturuldu."
        else
          write_result "$rid" "$event" false "Olay Günlüğü kaydı oluşturulamadı."
        fi
        ;;
      operation_log_clear)
        if /opt/kzsc/bin/kzsc-oplog.sh clear >/dev/null 2>&1 \
          && /opt/kzsc/bin/kzsc-oplog.sh append operation_log_clear true 'Olay Günlüğü temizlendi.' "$rid" >/dev/null 2>&1; then
          write_result "$rid" "operation_log_clear" true "Olay Günlüğü temizlendi."
        else
          write_result "$rid" "operation_log_clear" false "Olay Günlüğü temizlenemedi."
        fi
        ;;
      blockcheck_start:*)
        rest="${action#blockcheck_start:}"
        nd="${rest%%:*}"
        rest2="${rest#*:}"
        scan="${rest2%%:*}"
        domains="${rest2#*:}"

        # v0.11.1.4: one Blockcheck mode. Compatibility mode field is accepted
        # only for request compatibility and is normalized to quick internally.
        case "$scan" in
          quick|standard|force) scan="quick" ;;
          *) domains="$rest2"; scan="quick" ;;
        esac
        [ -n "$domains" ] || domains="pastebin.com"

        /opt/kzsc/bin/kzsc-blockcheck.sh start "$nd" "$domains" "$scan" >/tmp/kzsc-bc.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-bc.$$ 2>/dev/null)"; rm -f /tmp/kzsc-bc.$$
        if [ "$rc" -eq 0 ]; then
          publish_result "$rid" "blockcheck_start:$nd" true "$ACTION_MSG"
        else
          [ -n "$ACTION_MSG" ] || ACTION_MSG="Blockcheck başlatılamadı."
          publish_result "$rid" "blockcheck_start:$nd" false "$ACTION_MSG"
        fi
        ;;
      engine_enable:*)
        nd="${action#engine_enable:}"
        /opt/kzsc/bin/kzsc-engines.sh enable "$nd" >/tmp/kzsc-eng.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-eng.$$ 2>/dev/null)"; rm -f /tmp/kzsc-eng.$$
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Motor başlatma sonucu alınamadı."
        [ "$rc" -eq 0 ] && publish_result "$rid" "engine_enable:$nd" true "$ACTION_MSG" || publish_result "$rid" "engine_enable:$nd" false "$ACTION_MSG"
        ;;
      engine_disable:*)
        nd="${action#engine_disable:}"
        /opt/kzsc/bin/kzsc-engines.sh disable "$nd" >/tmp/kzsc-eng.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-eng.$$ 2>/dev/null)"; rm -f /tmp/kzsc-eng.$$
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Motor durdurma sonucu alınamadı."
        [ "$rc" -eq 0 ] && publish_result "$rid" "engine_disable:$nd" true "$ACTION_MSG" || publish_result "$rid" "engine_disable:$nd" false "$ACTION_MSG"
        ;;
      profile_set:*)
        rest="${action#profile_set:}"
        nd="${rest%%:*}"
        preset="${rest#*:}"
        case "$preset" in
          tt|sol|kablonet) : ;;
          auto_*)
            sid="$(printf '%s' "$nd" | tr ' A-Z/:.' '_a-z___' | tr -cd 'a-z0-9_-')"
            [ "$preset" = "auto_$sid" ] && [ -f "$KZSC_HOME/var/dpi/auto-presets/$preset.conf" ] || {
              publish_result "$rid" "profile_set:$nd" false "Geçersiz veya bu WAN'a ait olmayan AUTO DPI profili."
              continue
            }
            ;;
          *)
            publish_result "$rid" "profile_set:$nd" false "Geçersiz DPI preset."
            continue
            ;;
        esac

        /opt/kzsc/bin/kzsc-engines.sh set-profile "$nd" "$preset" >/tmp/kzsc-prof.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-prof.$$ 2>/dev/null)"; rm -f /tmp/kzsc-prof.$$
        if [ "$rc" -eq 0 ]; then
          pname="$(/opt/kzsc/bin/kzsc-presets.sh name "$preset" 2>/dev/null)"
          [ -n "$pname" ] || pname="$preset"
          publish_result "$rid" "profile_set:$nd" true "$nd → $pname kaydedildi. Motor devralma hâlâ kapalı."
        else
          [ -n "$ACTION_MSG" ] || ACTION_MSG="DPI preset kaydedilemedi."
          publish_result "$rid" "profile_set:$nd" false "$ACTION_MSG"
        fi
        ;;
      blockcheck_stop:*)
        nd="${action#blockcheck_stop:}"
        /opt/kzsc/bin/kzsc-blockcheck.sh stop "$nd" >/tmp/kzsc-bc.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-bc.$$ 2>/dev/null)"; rm -f /tmp/kzsc-bc.$$
        if [ "$rc" -eq 0 ]; then
          publish_result "$rid" "$action" true "$ACTION_MSG"
        else
          [ -n "$ACTION_MSG" ] || ACTION_MSG="Blockcheck durdurulamadı."
          publish_result "$rid" "$action" false "$ACTION_MSG"
        fi
        ;;
      telegram_save:*)
        prid="${action#telegram_save:}"
        payload="$QUEUE/payload.$prid"
        if [ ! -f "$payload" ]; then
          publish_result "$rid" "telegram_save" false "Telegram ayar istegi bulunamadi."
          continue
        fi
        body="$(cat "$payload" 2>/dev/null)"; rm -f "$payload"
        urldecode(){ printf '%b' "$(printf '%s' "$1"|sed 's/+/ /g;s/%/\\x/g')"; }
        set --; oifs="$IFS"; IFS='&'
        for pair in $body; do
          k="${pair%%=*}"; v="$(urldecode "${pair#*=}")"
          case "$k" in enabled|token|chat_id|wan|dpi|blockcheck|dns|zapret2|system|commands) set -- "$@" "$k=$v";; esac
        done
        IFS="$oifs"
        /opt/kzsc/bin/kzsc-telegram.sh save "$@" >/tmp/kzsc-tg.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-tg.$$ 2>/dev/null)"; rm -f /tmp/kzsc-tg.$$
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Telegram ayarlari kaydedilemedi."
        [ "$rc" -eq 0 ] && publish_result "$rid" "telegram_save" true "$ACTION_MSG" || publish_result "$rid" "telegram_save" false "$ACTION_MSG"
        ;;
      telegram_test)
        /opt/kzsc/bin/kzsc-telegram.sh test >/tmp/kzsc-tg.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-tg.$$ 2>/dev/null)"; rm -f /tmp/kzsc-tg.$$
        /opt/kzsc/bin/kzsc-telegram.sh publish-status >/dev/null 2>&1 || true
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Telegram test sonucu alinamadi."
        [ "$rc" -eq 0 ] && publish_result "$rid" "telegram_test" true "$ACTION_MSG" || publish_result "$rid" "telegram_test" false "$ACTION_MSG"
        ;;
      telegram_find_chat)
        /opt/kzsc/bin/kzsc-telegram.sh find-chat >/tmp/kzsc-tg.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-tg.$$ 2>/dev/null)"; rm -f /tmp/kzsc-tg.$$
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Chat ID bulunamadi."
        [ "$rc" -eq 0 ] && publish_result "$rid" "telegram_find_chat" true "$ACTION_MSG" || publish_result "$rid" "telegram_find_chat" false "$ACTION_MSG"
        ;;
      keendns_enable|keendns_disable|refresh|wan_check|dpi_repair|clear_history|clear_logs|zapret2_install|zapret2_update|zapret2_repair|zapret2_remove|kzsc_update_check|kzsc_update_install|kzsc_update_auto_on|kzsc_update_auto_off|restart)
        if run_action "$action"; then
          publish_result "$rid" "$action" true "$ACTION_MSG"
          if [ "$action" = "restart" ]; then
            # Publish confirmation first so browser can read it, then restart.
            ( sleep 2; /opt/etc/init.d/S99kzsc restart >>"$KZSC_HOME/var/log/maintenance.log" 2>&1 ) &
          fi
        else
          publish_result "$rid" "$action" false "$ACTION_MSG"
        fi
        ;;
      *)
        log "maintenance: rejected invalid queued action"
        publish_result "$rid" "$action" false "Geçersiz bakım işlemi reddedildi."
        ;;
    esac
  done
  snapshot
}

case "$1" in
  snapshot) snapshot ;;
  process-queue) process_queue ;;
  action)
    case "$2" in
      telegram_save:*)
        prid="${action#telegram_save:}"
        payload="$QUEUE/payload.$prid"
        if [ ! -f "$payload" ]; then
          publish_result "$rid" "telegram_save" false "Telegram ayar istegi bulunamadi."
          continue
        fi
        body="$(cat "$payload" 2>/dev/null)"; rm -f "$payload"
        urldecode(){ printf '%b' "$(printf '%s' "$1"|sed 's/+/ /g;s/%/\\x/g')"; }
        set --; oifs="$IFS"; IFS='&'
        for pair in $body; do
          k="${pair%%=*}"; v="$(urldecode "${pair#*=}")"
          case "$k" in enabled|token|chat_id|wan|dpi|blockcheck|dns|zapret2|system|commands) set -- "$@" "$k=$v";; esac
        done
        IFS="$oifs"
        /opt/kzsc/bin/kzsc-telegram.sh save "$@" >/tmp/kzsc-tg.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-tg.$$ 2>/dev/null)"; rm -f /tmp/kzsc-tg.$$
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Telegram ayarlari kaydedilemedi."
        [ "$rc" -eq 0 ] && publish_result "$rid" "telegram_save" true "$ACTION_MSG" || publish_result "$rid" "telegram_save" false "$ACTION_MSG"
        ;;
      telegram_test)
        /opt/kzsc/bin/kzsc-telegram.sh test >/tmp/kzsc-tg.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-tg.$$ 2>/dev/null)"; rm -f /tmp/kzsc-tg.$$
        /opt/kzsc/bin/kzsc-telegram.sh publish-status >/dev/null 2>&1 || true
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Telegram test sonucu alinamadi."
        [ "$rc" -eq 0 ] && publish_result "$rid" "telegram_test" true "$ACTION_MSG" || publish_result "$rid" "telegram_test" false "$ACTION_MSG"
        ;;
      telegram_find_chat)
        /opt/kzsc/bin/kzsc-telegram.sh find-chat >/tmp/kzsc-tg.$$ 2>&1
        rc=$?; ACTION_MSG="$(cat /tmp/kzsc-tg.$$ 2>/dev/null)"; rm -f /tmp/kzsc-tg.$$
        [ -n "$ACTION_MSG" ] || ACTION_MSG="Chat ID bulunamadi."
        [ "$rc" -eq 0 ] && publish_result "$rid" "telegram_find_chat" true "$ACTION_MSG" || publish_result "$rid" "telegram_find_chat" false "$ACTION_MSG"
        ;;
      keendns_enable|keendns_disable|refresh|wan_check|dpi_repair|clear_history|clear_logs|zapret2_install|zapret2_update|zapret2_repair|zapret2_remove|kzsc_update_check|kzsc_update_install|kzsc_update_auto_on|kzsc_update_auto_off|restart)
        if run_action "$2"; then
          echo "$ACTION_MSG"
          snapshot
          exit 0
        fi
        echo "$ACTION_MSG" >&2
        snapshot
        exit 1
        ;;
      *) echo "Unsupported action" >&2; exit 1;;
    esac
    ;;
  json)
    [ -f "$OUT" ] || snapshot
    cat "$OUT"
    ;;
  *) echo "Usage: kzsc-maintenance {snapshot|process-queue|json|action ACTION}"; exit 1 ;;
esac
