#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

CONF="$KZSC_HOME/etc/telegram.conf"
STATE="$KZSC_HOME/var/lib/telegram-state.conf"
RUN="$KZSC_HOME/var/run"
PUBLIC_STATUS="$KZSC_HOME/www/data/telegram-status.json"

mkdir -p \
  "$KZSC_HOME/etc" \
  "$KZSC_HOME/var/log" \
  "$KZSC_HOME/var/lib" \
  "$RUN"

readv_file(){
  f="$1"
  k="$2"
  d="$3"

  v="$(
    sed -n "s/^${k}=\"\(.*\)\"$/\1/p" "$f" 2>/dev/null |
    tail -n1
  )"

  [ -n "$v" ] || v="$d"
  printf '%s' "$v"
}

writev_file(){
  f="$1"
  k="$2"
  v="$3"
  t="$f.tmp.$$"

  umask 077

  awk -v k="$k" -v v="$v" '''
    BEGIN { d=0 }
    $0 ~ "^" k "=" {
      print k "=\"" v "\""
      d=1
      next
    }
    { print }
    END {
      if (!d)
        print k "=\"" v "\""
    }
  ''' "$f" > "$t" || {
    rm -f "$t"
    return 1
  }

  mv "$t" "$f" || {
    rm -f "$t"
    return 1
  }

  chmod 600 "$f" 2>/dev/null || return 1
}

is_state_key(){
  case "$1" in
    TG_LAST_UPDATE_ID|TG_LAST_SENT|TG_LAST_ERROR)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ensure_conf_base(){
  [ -f "$CONF" ] || {
    umask 077

    cat > "$CONF" <<'EOC'
TG_ENABLED="0"
TG_TOKEN=""
TG_CHAT_ID=""
TG_NOTIFY_WAN="1"
TG_NOTIFY_DPI="1"
TG_NOTIFY_BLOCKCHECK="1"
TG_NOTIFY_DNS="1"
TG_NOTIFY_ZAPRET2="1"
TG_NOTIFY_SYSTEM="1"
TG_COMMANDS_ENABLED="0"
EOC
  }

  chmod 600 "$CONF" 2>/dev/null || return 1
}

ensure_state(){
  ensure_conf_base || return 1

  mkdir -p "$KZSC_HOME/var/lib" || return 1

  if [ ! -f "$STATE" ]; then
    legacy_update="$(readv_file "$CONF" TG_LAST_UPDATE_ID 0)"
    legacy_sent="$(readv_file "$CONF" TG_LAST_SENT 0)"
    legacy_error="$(readv_file "$CONF" TG_LAST_ERROR '')"

    st="$STATE.tmp.$$"
    umask 077

    {
      printf 'TG_LAST_UPDATE_ID="%s"\n' "$legacy_update"
      printf 'TG_LAST_SENT="%s"\n' "$legacy_sent"
      printf 'TG_LAST_ERROR="%s"\n' "$legacy_error"
    } > "$st" || {
      rm -f "$st"
      return 1
    }

    mv "$st" "$STATE" || {
      rm -f "$st"
      return 1
    }

    chmod 600 "$STATE" 2>/dev/null || return 1
  fi

  grep -q '^TG_LAST_UPDATE_ID=' "$STATE" 2>/dev/null ||
    writev_file "$STATE" TG_LAST_UPDATE_ID 0 ||
    return 1

  grep -q '^TG_LAST_SENT=' "$STATE" 2>/dev/null ||
    writev_file "$STATE" TG_LAST_SENT 0 ||
    return 1

  grep -q '^TG_LAST_ERROR=' "$STATE" 2>/dev/null ||
    writev_file "$STATE" TG_LAST_ERROR '' ||
    return 1

  # Eski sürüm/yedek restore işlemi TG_LAST_* alanlarını tekrar
  # telegram.conf içine getirirse config'i otomatik normalize et.
  if grep -q '^TG_LAST_' "$CONF" 2>/dev/null; then
    ct="$CONF.tmp.$$"
    umask 077

    awk '''
      !/^TG_LAST_UPDATE_ID=/ &&
      !/^TG_LAST_SENT=/ &&
      !/^TG_LAST_ERROR=/
    ''' "$CONF" > "$ct" || {
      rm -f "$ct"
      return 1
    }

    mv "$ct" "$CONF" || {
      rm -f "$ct"
      return 1
    }

    chmod 600 "$CONF" 2>/dev/null || return 1
  fi

  chmod 600 "$STATE" 2>/dev/null || return 1
}

ensure_conf(){
  ensure_conf_base &&
  ensure_state
}

getv(){
  ensure_conf || return 1

  k="$1"
  d="$2"

  if is_state_key "$k"; then
    readv_file "$STATE" "$k" "$d"
  else
    readv_file "$CONF" "$k" "$d"
  fi
}

setv(){
  ensure_conf || return 1

  k="$1"
  v="$2"

  if is_state_key "$k"; then
    writev_file "$STATE" "$k" "$v"
  else
    writev_file "$CONF" "$k" "$v"
  fi
}

boolv(){ case "$1" in 1|true|yes|on) echo 1;;*) echo 0;;esac; }
valid_token(){ printf '%s' "$1"|grep -Eq '^[0-9]+:[A-Za-z0-9_-]+$'; }
valid_chat(){ printf '%s' "$1"|grep -Eq '^(-?[0-9]+|@[A-Za-z0-9_]+)$'; }
configured(){ [ -n "$(getv TG_TOKEN '')" ]&&[ -n "$(getv TG_CHAT_ID '')" ]; }
enabled_for(){ [ "$(getv TG_ENABLED 0)" = 1 ]||return 1; case "$1" in wan) k=TG_NOTIFY_WAN;;dpi) k=TG_NOTIFY_DPI;;blockcheck) k=TG_NOTIFY_BLOCKCHECK;;dns) k=TG_NOTIFY_DNS;;zapret2) k=TG_NOTIFY_ZAPRET2;;system) k=TG_NOTIFY_SYSTEM;;*) return 1;;esac; [ "$(getv "$k" 1)" = 1 ]; }
api(){ m="$1";shift; tok="$(getv TG_TOKEN '')"; [ -n "$tok" ]||{ echo '{"ok":false,"description":"Bot token kayitli degil."}';return 1;}; cfg="$RUN/tg-curl.$$"; umask 077; printf 'url = "https://api.telegram.org/bot%s/%s"\n' "$tok" "$m">"$cfg"; out="$(curl -sS --connect-timeout 4 --max-time 10 --config "$cfg" "$@" 2>&1)";rc=$?;rm -f "$cfg";printf '%s' "$out";return $rc; }
record(){ if [ "$1" = 1 ];then setv TG_LAST_SENT "$(date +%s)";setv TG_LAST_ERROR '';else setv TG_LAST_ERROR "$(printf '%s' "$2"|tr '\r\n' '  '|cut -c1-240)";fi; }
send(){
  msg="$1"
  rid="telegram-delivery-$(date +%s)-$$"
  configured||{
    err='Telegram bot token veya Chat ID eksik.'
    /opt/kzsc/bin/kzsc-oplog.sh append-local telegram_delivery false "$err" "$rid" >/dev/null 2>&1 || true
    echo "$err" >&2
    return 2
  }
  chat="$(getv TG_CHAT_ID '')"
  out="$(api sendMessage --data-urlencode "chat_id=$chat" --data-urlencode "text=$msg")";rc=$?
  # WAN/default-route changes can briefly make DNS unavailable. Retry one
  # transport-level curl failure after a short delay; API-level errors are not
  # retried to avoid duplicate or invalid requests.
  if [ $rc -ne 0 ]; then
    sleep 3
    out="$(api sendMessage --data-urlencode "chat_id=$chat" --data-urlencode "text=$msg")";rc=$?
  fi
  if [ $rc -eq 0 ]&&printf '%s' "$out"|grep -q '"ok":true';then
    record 1 ''
    /opt/kzsc/bin/kzsc-oplog.sh append-local telegram_delivery true 'Telegram mesajı gönderildi.' "$rid" >/dev/null 2>&1 || true
    echo 'Telegram mesaji gonderildi.'
    return 0
  fi
  record 0 "$out"
  err="Telegram gönderim hatası: $(printf '%s' "$out" | tr '
' '  ' | cut -c1-220)"
  /opt/kzsc/bin/kzsc-oplog.sh append-local telegram_delivery false "$err" "$rid" >/dev/null 2>&1 || true
  echo "Telegram gonderim hatasi: $out" >&2
  return 1
}

send_file(){
  file="$1"; caption="$2"
  [ -f "$file" ] || { echo 'Telegram dosyası bulunamadı.' >&2; return 1; }
  configured || { echo 'Telegram bot token veya Chat ID eksik.' >&2; return 2; }
  chat="$(getv TG_CHAT_ID '')"; tok="$(getv TG_TOKEN '')"; cfg="$RUN/tg-curl-file.$$"; umask 077
  printf 'url = "https://api.telegram.org/bot%s/sendDocument"\n' "$tok" >"$cfg"
  out="$(curl -sS --connect-timeout 5 --max-time 60 --config "$cfg" -F "chat_id=$chat" -F "document=@$file" -F "caption=$caption" 2>&1)"; rc=$?; rm -f "$cfg"
  if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q '"ok":true'; then record 1 ''; echo 'Yedek dosyası Telegrama gönderildi.'; return 0; fi
  record 0 "$out"; echo "Telegram dosya gönderim hatası: $out" >&2; return 1
}
status_json(){ tok="$(getv TG_TOKEN '')";chat="$(getv TG_CHAT_ID '')"; [ -n "$tok" ]&&ht=true||ht=false; [ -n "$tok" ]&&[ -n "$chat" ]&&cf=true||cf=false; printf '{"enabled":%s,"configured":%s,"has_token":%s,"chat_id":"%s","notify":{"wan":%s,"dpi":%s,"blockcheck":%s,"dns":%s,"zapret2":%s,"system":%s},"commands_enabled":%s,"last_sent":%s,"last_error":"%s"}\n' "$( [ "$(getv TG_ENABLED 0)" = 1 ]&&echo true||echo false)" "$cf" "$ht" "$(json_escape "$chat")" "$( [ "$(getv TG_NOTIFY_WAN 1)" = 1 ]&&echo true||echo false)" "$( [ "$(getv TG_NOTIFY_DPI 1)" = 1 ]&&echo true||echo false)" "$( [ "$(getv TG_NOTIFY_BLOCKCHECK 1)" = 1 ]&&echo true||echo false)" "$( [ "$(getv TG_NOTIFY_DNS 1)" = 1 ]&&echo true||echo false)" "$( [ "$(getv TG_NOTIFY_ZAPRET2 1)" = 1 ]&&echo true||echo false)" "$( [ "$(getv TG_NOTIFY_SYSTEM 1)" = 1 ]&&echo true||echo false)" "$( [ "$(getv TG_COMMANDS_ENABLED 0)" = 1 ]&&echo true||echo false)" "$(getv TG_LAST_SENT 0)" "$(json_escape "$(getv TG_LAST_ERROR '')")"; }
publish_status(){ mkdir -p "$KZSC_HOME/www/data"; t="$PUBLIC_STATUS.tmp.$$"; status_json >"$t" || { rm -f "$t"; return 1; }; mv "$t" "$PUBLIC_STATUS" || { rm -f "$t"; return 1; }; chmod 644 "$PUBLIC_STATUS" 2>/dev/null || true; }
status(){ status_json; }
save(){
  while [ $# -gt 0 ];do
    kv="$1";shift;k="${kv%%=*}";v="${kv#*=}"
    case "$k" in
      enabled) setv TG_ENABLED "$(boolv "$v")" || { echo 'Telegram ayari yazilamadi: enabled' >&2; return 1; };;
      token) [ -z "$v" ]||{ valid_token "$v"||{ echo 'Gecersiz bot token.'>&2;return 1;};setv TG_TOKEN "$v" || { echo 'Bot token kaydedilemedi.' >&2; return 1; };};;
      chat_id) [ -z "$v" ]||valid_chat "$v"||{ echo 'Gecersiz Chat ID.'>&2;return 1;};setv TG_CHAT_ID "$v" || { echo 'Chat ID kaydedilemedi.' >&2; return 1; };;
      wan) setv TG_NOTIFY_WAN "$(boolv "$v")" || return 1;;
      dpi) setv TG_NOTIFY_DPI "$(boolv "$v")" || return 1;;
      blockcheck) setv TG_NOTIFY_BLOCKCHECK "$(boolv "$v")" || return 1;;
      dns) setv TG_NOTIFY_DNS "$(boolv "$v")" || return 1;;
      zapret2) setv TG_NOTIFY_ZAPRET2 "$(boolv "$v")" || return 1;;
      system) setv TG_NOTIFY_SYSTEM "$(boolv "$v")" || return 1;;
      commands) setv TG_COMMANDS_ENABLED "$(boolv "$v")" || return 1;;
      *) echo "Desteklenmeyen Telegram ayari: $k">&2;return 1;;
    esac
  done
  publish_status || { echo 'Telegram durum dosyasi yayinlanamadi.' >&2; return 1; }
  echo 'Telegram ayarlari kaydedildi.'
}
testmsg(){
  test_text="$(printf '✅ KZSC Telegram bağlantısı çalışıyor.\nRouter: %s\nKeeneticOS: %s' "$(router_model)" "$(keenetic_version)")"
  send "$test_text"
}
findchat(){ [ -n "$(getv TG_TOKEN '')" ]||{ echo 'Önce Bot Token kaydet.'>&2;return 1;};out="$(api getUpdates)";rc=$?;[ $rc -eq 0 ]||{ echo "$out">&2;return 1;};printf '%s' "$out"|grep -q '"ok":true'||{ echo "$out">&2;return 1;}; id="$(printf '%s' "$out"|grep -oE '"chat"[[:space:]]*:[[:space:]]*\{[^}]*"id"[[:space:]]*:[[:space:]]*-?[0-9]+'|tail -n1|sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\(-*[0-9][0-9]*\).*/\1/p')";[ -n "$id" ]||{ echo 'Chat bulunamadi. Telegramda bota /start gönderip tekrar dene.'>&2;return 1;};echo "$id"; }

command_key(){
  # Human-friendly command key derived from the live Keenetic connection label.
  # Keep spaces supported, but also accept underscore form for easier typing.
  printf '%s' "$1" | tr '[:upper:] ' '[:lower:]_' | sed 's/[^a-z0-9_-]/_/g;s/__*/_/g;s/^_//;s/_$//'
}

resolve_wan_name(){
  # Resolve a Telegram-visible connection name back to the current NDMC WAN id.
  # Backward-compatible: NDMC and Linux interface names are accepted too, but
  # they are intentionally not shown to the user in /help.
  wanted="$1"; [ -n "$wanted" ] || return 1
  wk="$(command_key "$wanted")"
  for nd in $(internet_wans); do
    label="$(isp_label "$nd")"; [ -n "$label" ] || label="$nd"
    lin="$(linux_if_for_ndmc "$nd")"
    [ "$(command_key "$label")" = "$wk" ] && { printf '%s\n' "$nd"; return 0; }
    [ "$(command_key "$nd")" = "$wk" ] && { printf '%s\n' "$nd"; return 0; }
    [ -n "$lin" ] && [ "$(command_key "$lin")" = "$wk" ] && { printf '%s\n' "$nd"; return 0; }
  done
  return 1
}

wan_name_list(){
  for nd in $(internet_wans); do
    label="$(isp_label "$nd")"; [ -n "$label" ] || label="$nd"
    printf '%s\n' "$label"
  done
}

command_help(){
  cat <<'EOF'
KZSC Telegram komutları:
/status - genel durum
/wan - WAN bağlantıları
/dpi - DPI motorları ve yönetim butonları
/blockcheck - Blockcheck durumları ve yönetim butonları
/zapret2 - Zapret2 durumu
/zapret2_update - Zapret2 güncelle
/zapret2_repair - Zapret2 onar
/dns - DNS durumu
/kzsc_update - KZSC güncelleme durumu ve yönetim butonları
/kzsc_update_check - yeni KZSC sürümünü kontrol et
/kzsc_update_install - bulunan KZSC sürümünü güvenli biçimde kur
/kzsc_update_auto_on - 30 dakikalık otomatik güncellemeyi aç
/kzsc_update_auto_off - otomatik güncellemeyi kapat
/help - bu liste

DPI ve Blockcheck ekranlarında bağlantılar Keenetic'teki canlı bağlantı adlarıyla gösterilir ve yönetim butonları kullanılabilir.

Metin komutları da desteklenir:
EOF
  for nd in $(internet_wans); do
    label="$(isp_label "$nd")"; [ -n "$label" ] || label="$nd"
    printf '/dpi_start %s\n' "$label"
    printf '/dpi_stop %s\n' "$label"
    printf '/blockcheck_start %s\n' "$label"
    printf '/blockcheck_stop %s\n' "$label"
  done
}

human_engine_state(){
  case "$1" in
    running) echo 'Çalışıyor';;
    prepared) echo 'Hazır';;
    stopped|disabled) echo 'Durduruldu';;
    *) [ -n "$1" ] && echo "$1" || echo 'Bilinmiyor';;
  esac
}

human_bc_state(){
  case "$1" in
    success) echo 'Başarılı';;
    running) echo 'Çalışıyor';;
    queued) echo 'Sırada';;
    idle) echo 'Hazır';;
    timeout) echo 'Zaman aşımı';;
    stopped) echo 'Durduruldu';;
    failed|error) echo 'Başarısız';;
    restore_failed) echo 'Geri yükleme hatası';;
    *) [ -n "$1" ] && echo "$1" || echo 'Hazır';;
  esac
}

human_bc_result(){
  case "$1" in
    preset_verified) echo 'Preset doğrulandı';;
    profile_found) echo 'Profil bulundu';;
    none|'') echo '';;
    *) echo "$1";;
  esac
}

command_status(){
  z="$(/opt/kzsc/bin/kzsc-zapret2.sh status 2>/dev/null)"
  z_inst="$(printf '%s' "$z" | sed -n 's/.*"installed":\(true\|false\).*/\1/p' | head -n1)"
  z_ver="$(printf '%s' "$z" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p' | head -n1)"
  [ -n "$z_ver" ] || z_ver='-'
  if [ "$z_inst" = true ]; then z_state="${z_ver} · Hazır"; else z_state='Kurulu değil'; fi

  e="$(/opt/kzsc/bin/kzsc-engines.sh status 2>/dev/null)"
  total="$(printf '%s' "$e"|sed -n 's/.*"count":\([0-9][0-9]*\).*/\1/p'|head -n1)"; [ -n "$total" ]||total=0
  running="$(printf '%s' "$e"|grep -o '"state":"running"'|wc -l|tr -d ' ')"

  b="$(/opt/kzsc/bin/kzsc-blockcheck.sh status 2>/dev/null)"
  br="$(printf '%s' "$b"|sed -n 's/.*"running":\([0-9][0-9]*\).*/\1/p'|head -n1)"; [ -n "$br" ]||br=0

  d="$(/opt/kzsc/bin/kzsc-dns.sh status 2>/dev/null)"
  d_enabled="$(printf '%s' "$d" | sed -n 's/.*"enabled":\(true\|false\).*/\1/p' | head -n1)"
  d_name="$(printf '%s' "$d" | sed -n 's/.*"provider_name":"\([^"]*\)".*/\1/p' | head -n1)"
  d_proto="$(printf '%s' "$d" | sed -n 's/.*"protocol":"\([^"]*\)".*/\1/p' | head -n1 | tr '[:lower:]' '[:upper:]')"
  if [ "$d_enabled" = true ]; then dns_state="${d_name:-DNS} · ${d_proto:-Aktif}"; else dns_state='Devre dışı'; fi

  kd="$(/opt/kzsc/bin/kzsc-keendns.sh status 2>/dev/null)"
  kd_enabled="$(printf '%s' "$kd" | sed -n 's/.*"enabled":\(true\|false\).*/\1/p' | head -n1)"
  kd_domain="$(printf '%s' "$kd" | sed -n 's/.*"domain":"\([^"]*\)".*/\1/p' | head -n1)"
  if [ "$kd_enabled" = true ]; then kd_state="Aktif${kd_domain:+ · $kd_domain}"; else kd_state='Devre dışı'; fi

  printf 'KZSC v0.11.2.27-generic\nRouter: %s\nKeeneticOS: %s\n\nWAN: %s\nDPI: %s/%s aktif\nBlockcheck çalışan: %s\n\nZapret2: %s\nDNS: %s\nKeenDNS: %s\n' \
    "$(router_model)" "$(keenetic_version)" "$total" "$running" "$total" "$br" "$z_state" "$dns_state" "$kd_state"
}

command_wan(){
  for nd in $(internet_wans); do
    label="$(isp_label "$nd")"; [ -n "$label" ] || label="$nd"
    lin="$(linux_if_for_ndmc "$nd")"
    if ip link show "$lin" >/dev/null 2>&1; then st='🟢 Bağlı'; else st='🔴 Bağlı değil'; fi
    printf '%s\nDurum: %s\n\n' "$label" "$st"
  done
}

command_dpi(){
  e="$(/opt/kzsc/bin/kzsc-engines.sh status 2>/dev/null)"
  for nd in $(internet_wans); do
    label="$(isp_label "$nd")"; [ -n "$label" ] || label="$nd"
    line="$(printf '%s\n' "$e" | grep -F '"ndmc":"'"$nd"'"' | head -n1)"
    state="$(printf '%s' "$line" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')"
    profile="$(printf '%s' "$line" | sed -n 's/.*"profile":"\([^"]*\)".*/\1/p')"
    queue="$(printf '%s' "$line" | sed -n 's/.*"queue":\([0-9][0-9]*\).*/\1/p')"
    [ -n "$state" ] || state='bilinmiyor'; [ -n "$profile" ] || profile='-'; [ -n "$queue" ] || queue='-'
    case "$state" in running) icon='🟢';; *) icon='⚪';; esac
    state_label="$(human_engine_state "$state")"
    printf '%s\n%s Motor: %s\nProfil: %s\nQueue: %s\n\n' "$label" "$icon" "$state_label" "$profile" "$queue"
  done
}

command_bc(){
  b="$(/opt/kzsc/bin/kzsc-blockcheck.sh status 2>/dev/null)"
  for nd in $(internet_wans); do
    label="$(isp_label "$nd")"; [ -n "$label" ] || label="$nd"
    line="$(printf '%s\n' "$b" | grep -F '"ndmc":"'"$nd"'"' | head -n1)"
    state="$(printf '%s' "$line" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')"
    elapsed="$(printf '%s' "$line" | sed -n 's/.*"elapsed":\([0-9][0-9]*\).*/\1/p')"
    applied="$(printf '%s' "$line" | sed -n 's/.*"applied_profile":"\([^"]*\)".*/\1/p')"
    result="$(printf '%s' "$line" | sed -n 's/.*"result_type":"\([^"]*\)".*/\1/p')"
    [ -n "$state" ] || state='idle'; [ -n "$elapsed" ] || elapsed=0
    state_label="$(human_bc_state "$state")"
    result_label="$(human_bc_result "$result")"
    printf '%s\nDurum: %s\nGeçen: %ss' "$label" "$state_label" "$elapsed"
    [ -n "$applied" ] && printf '\nUygulanan profil: %s' "$applied"
    [ -n "$result_label" ] && printf '\nSonuç: %s' "$result_label"
    printf '\n\n'
  done
}
command_dns(){ /opt/kzsc/bin/kzsc-dns.sh status 2>/dev/null | cut -c1-3500; }

command_update(){
  uj="$(/opt/kzsc/bin/kzsc-updater.sh status 2>/dev/null)"
  ucur="$(printf '%s' "$uj" | sed -n 's/.*"current":"\([^"]*\)".*/\1/p')"
  ulatest="$(printf '%s' "$uj" | sed -n 's/.*"latest":"\([^"]*\)".*/\1/p')"
  uavailable="$(printf '%s' "$uj" | sed -n 's/.*"available":\(true\|false\).*/\1/p')"
  uauto="$(printf '%s' "$uj" | sed -n 's/.*"auto":\(true\|false\).*/\1/p')"
  uapplying="$(printf '%s' "$uj" | sed -n 's/.*"applying":\(true\|false\).*/\1/p')"
  ustate="$(printf '%s' "$uj" | sed -n 's/.*"apply_state":"\([^"]*\)".*/\1/p')"
  uerror="$(printf '%s' "$uj" | sed -n 's/.*"last_error":"\([^"]*\)".*/\1/p')"
  [ -n "$ucur" ] || ucur='Bilinmiyor'
  [ -n "$ulatest" ] || ulatest='Henüz kontrol edilmedi'
  [ "$uavailable" = true ] && ustatus='🟡 Güncelleme mevcut' || ustatus='🟢 KZSC güncel'
  [ "$uauto" = true ] && uauto_label='Etkin' || uauto_label='Devre dışı'
  if [ "$uapplying" = true ]; then uoperation="Çalışıyor · ${ustate:-bilinmiyor}"; else uoperation="${ustate:-bekliyor}"; fi
  printf 'KZSC Güncelleme\n\nMevcut: %s\nSon sürüm: %s\nDurum: %s\nOtomatik güncelleme: %s\nİşlem: %s' \
    "$ucur" "$ulatest" "$ustatus" "$uauto_label" "$uoperation"
  [ -n "$uerror" ] && printf '\nSon hata: %s' "$uerror"
}

send_markup(){
  msg="$1"; markup="$2"
  configured || return 2
  chat="$(getv TG_CHAT_ID '')"
  out="$(api sendMessage --data-urlencode "chat_id=$chat" --data-urlencode "text=$msg" --data-urlencode "reply_markup=$markup")"; rc=$?
  if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q '"ok":true'; then record 1 ''; return 0; fi
  record 0 "$out"; return 1
}

menu_keyboard(){
  printf '%s' '{"inline_keyboard":[[{"text":"📡 WAN","callback_data":"view:wan"},{"text":"🧩 DPI","callback_data":"view:dpi"}],[{"text":"🧪 Blockcheck","callback_data":"view:blockcheck"},{"text":"📊 Durum","callback_data":"view:status"}],[{"text":"⬆️ KZSC Güncelleme","callback_data":"view:update"}]]}'
}

dpi_keyboard(){
  e="$(/opt/kzsc/bin/kzsc-engines.sh status 2>/dev/null)"; rows=''; first=1
  for nd in $(internet_wans); do
    label="$(isp_label "$nd")"; [ -n "$label" ] || label="$nd"
    line="$(printf '%s\n' "$e" | grep -F '"ndmc":"'"$nd"'"' | head -n1)"
    state="$(printf '%s' "$line" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')"
    jl="$(json_escape "$label")"
    if [ "$state" = running ]; then btn='⏹ Durdur'; data="dpi_stop:$nd"; else btn='▶️ Başlat'; data="dpi_start:$nd"; fi
    row="[{\"text\":\"$jl\",\"callback_data\":\"view:dpi\"}],[{\"text\":\"$btn\",\"callback_data\":\"$data\"},{\"text\":\"🧪 Blockcheck\",\"callback_data\":\"bc_start:$nd\"}]"
    [ $first -eq 1 ] || rows="$rows,"
    rows="$rows$row"; first=0
  done
  printf '{"inline_keyboard":[%s,[{"text":"🔄 Yenile","callback_data":"view:dpi"},{"text":"⬅️ Menü","callback_data":"view:menu"}]]}' "$rows"
}

blockcheck_keyboard(){
  b="$(/opt/kzsc/bin/kzsc-blockcheck.sh status 2>/dev/null)"; rows=''; first=1
  for nd in $(internet_wans); do
    label="$(isp_label "$nd")"; [ -n "$label" ] || label="$nd"
    line="$(printf '%s\n' "$b" | grep -F '"ndmc":"'"$nd"'"' | head -n1)"
    state="$(printf '%s' "$line" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')"
    jl="$(json_escape "$label")"
    case "$state" in running|queued) btn='⏹ Durdur'; data="bc_stop:$nd";; *) btn='▶️ Başlat'; data="bc_start:$nd";; esac
    row="[{\"text\":\"$jl\",\"callback_data\":\"view:blockcheck\"}],[{\"text\":\"$btn\",\"callback_data\":\"$data\"}]"
    [ $first -eq 1 ] || rows="$rows,"
    rows="$rows$row"; first=0
  done
  printf '{"inline_keyboard":[%s,[{"text":"🔄 Yenile","callback_data":"view:blockcheck"},{"text":"⬅️ Menü","callback_data":"view:menu"}]]}' "$rows"
}

update_keyboard(){
  uj="$(/opt/kzsc/bin/kzsc-updater.sh status 2>/dev/null)"
  uavailable="$(printf '%s' "$uj" | sed -n 's/.*"available":\(true\|false\).*/\1/p')"
  uauto="$(printf '%s' "$uj" | sed -n 's/.*"auto":\(true\|false\).*/\1/p')"
  if [ "$uauto" = true ]; then
    auto_text='⏸ Otomatiği Kapat'; auto_data='ku_auto:off'
  else
    auto_text='▶️ Otomatiği Aç'; auto_data='ku_auto:on'
  fi
  if [ "$uavailable" = true ]; then
    install_row=',[{"text":"📦 Güncellemeyi Kur","callback_data":"ku_confirm:install"}]'
  else
    install_row=''
  fi
  printf '{"inline_keyboard":[[{"text":"🔍 Kontrol Et","callback_data":"ku_check:now"}]%s,[{"text":"%s","callback_data":"%s"}],[{"text":"🔄 Yenile","callback_data":"view:update"},{"text":"⬅️ Menü","callback_data":"view:menu"}]]}' \
    "$install_row" "$auto_text" "$auto_data"
}

update_confirm_keyboard(){
  printf '%s' '{"inline_keyboard":[[{"text":"✅ Evet, Güncellemeyi Kur","callback_data":"ku_install:yes"}],[{"text":"❌ Vazgeç","callback_data":"view:update"}]]}'
}

send_view(){
  view="$1"
  case "$view" in
    menu) send_markup "$(command_status)" "$(menu_keyboard)";;
    status) send_markup "$(command_status)" "$(menu_keyboard)";;
    wan) send_markup "$(command_wan)" "$(menu_keyboard)";;
    dpi) send_markup "$(command_dpi)" "$(dpi_keyboard)";;
    blockcheck) send_markup "$(command_bc)" "$(blockcheck_keyboard)";;
    update) send_markup "$(command_update)" "$(update_keyboard)";;
    *) return 1;;
  esac
}

run_command(){
  text="$1"
  cmd="${text%% *}"; arg="${text#* }"; [ "$arg" = "$text" ] && arg=''
  cmd="${cmd%%@*}"
  case "$cmd" in
    /start|/help) command_help;;
    /status) command_status;;
    /wan) command_wan;;
    /dpi) command_dpi;;
    /dpi_start)
      [ -n "$arg" ] || { echo 'Kullanım: /dpi_start BAĞLANTI_ADI'; return; }
      nd="$(resolve_wan_name "$arg")" || { echo "Bağlantı bulunamadı: $arg. /help ile güncel adları gör."; return; }
      label="$(isp_label "$nd")"; /opt/kzsc/bin/kzsc-engines.sh enable "$nd" >/dev/null 2>&1 && echo "$label DPI motoru başlatıldı." || echo "$label DPI motoru başlatılamadı.";;
    /dpi_stop)
      [ -n "$arg" ] || { echo 'Kullanım: /dpi_stop BAĞLANTI_ADI'; return; }
      nd="$(resolve_wan_name "$arg")" || { echo "Bağlantı bulunamadı: $arg. /help ile güncel adları gör."; return; }
      label="$(isp_label "$nd")"; /opt/kzsc/bin/kzsc-engines.sh disable "$nd" >/dev/null 2>&1 && echo "$label DPI motoru durduruldu." || echo "$label DPI motoru durdurulamadı.";;
    /blockcheck) command_bc;;
    /blockcheck_start)
      [ -n "$arg" ] || { echo 'Kullanım: /blockcheck_start BAĞLANTI_ADI'; return; }
      nd="$(resolve_wan_name "$arg")" || { echo "Bağlantı bulunamadı: $arg. /help ile güncel adları gör."; return; }
      /opt/kzsc/bin/kzsc-blockcheck.sh start "$nd" 'pastebin.com' quick 2>&1 | sed "s/$nd/$(isp_label "$nd")/g";;
    /blockcheck_stop)
      [ -n "$arg" ] || { echo 'Kullanım: /blockcheck_stop BAĞLANTI_ADI'; return; }
      nd="$(resolve_wan_name "$arg")" || { echo "Bağlantı bulunamadı: $arg. /help ile güncel adları gör."; return; }
      /opt/kzsc/bin/kzsc-blockcheck.sh stop "$nd" 2>&1 | sed "s/$nd/$(isp_label "$nd")/g";;
    /zapret2) /opt/kzsc/bin/kzsc-zapret2.sh status 2>&1 | cut -c1-3500;;
    /zapret2_update) /opt/kzsc/bin/kzsc-zapret2.sh update 2>&1 | cut -c1-3500;;
    /zapret2_repair) /opt/kzsc/bin/kzsc-zapret2.sh repair 2>&1 | cut -c1-3500;;
    /dns) command_dns;;
    /kzsc_update) command_update;;
    /kzsc_update_check)
      /opt/kzsc/bin/kzsc-updater.sh check 2>&1
      command_update;;
    /kzsc_update_install) /opt/kzsc/bin/kzsc-updater.sh install 2>&1;;
    /kzsc_update_auto_on) /opt/kzsc/bin/kzsc-updater.sh auto 1 2>&1;;
    /kzsc_update_auto_off) /opt/kzsc/bin/kzsc-updater.sh auto 0 2>&1;;
    *) echo 'Bilinmeyen komut. /help yaz.';;
  esac
}

valid_wan(){
  want="$1"
  for w in $(internet_wans 2>/dev/null); do [ "$w" = "$want" ] && return 0; done
  return 1
}

telegram_debug(){
  printf '%s telegram: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$KZSC_HOME/var/log/daemon.log" 2>/dev/null || true
}

handle_callback(){
  data="$1"
  action="${data%%:*}"; nd="${data#*:}"
  telegram_debug "callback received action=$action target=$nd"
  case "$action" in
    view)
      send_view "$nd"; rc=$?
      telegram_debug "callback view=$nd rc=$rc"
      return $rc;;
    ku_check)
      msg="$(/opt/kzsc/bin/kzsc-updater.sh check 2>&1)"; rc=$?
      [ -n "$msg" ] && send "$msg" >/dev/null 2>&1
      send_view update >/dev/null 2>&1 || true
      telegram_debug "callback kzsc_update_check rc=$rc"
      return $rc;;
    ku_auto)
      case "$nd" in on) uv=1;; off) uv=0;; *) return 1;; esac
      msg="$(/opt/kzsc/bin/kzsc-updater.sh auto "$uv" 2>&1)"; rc=$?
      [ -n "$msg" ] && send "$msg" >/dev/null 2>&1
      send_view update >/dev/null 2>&1 || true
      telegram_debug "callback kzsc_update_auto value=$nd rc=$rc"
      return $rc;;
    ku_confirm)
      [ "$nd" = install ] || return 1
      send_markup 'Bulunan KZSC sürümü SHA-256 ve iç manifest doğrulamasından sonra kurulacak. Blockcheck çalışıyorsa işlem reddedilir. Devam edilsin mi?' "$(update_confirm_keyboard)"
      return $?;;
    ku_install)
      [ "$nd" = yes ] || return 1
      msg="$(/opt/kzsc/bin/kzsc-updater.sh install 2>&1)"; rc=$?
      [ -n "$msg" ] && send "$msg" >/dev/null 2>&1
      send_view update >/dev/null 2>&1 || true
      telegram_debug "callback kzsc_update_install rc=$rc"
      return $rc;;
    dpi_start|dpi_stop|bc_start|bc_stop)
      if ! valid_wan "$nd"; then
        telegram_debug "callback rejected unknown_wan=$nd"
        send 'Bağlantı artık mevcut değil. /wan ile güncel bağlantıları kontrol et.' >/dev/null 2>&1
        return 1
      fi
      label="$(isp_label "$nd")"; [ -n "$label" ] || label="$nd"
      case "$action" in
        dpi_start)
          /opt/kzsc/bin/kzsc-engines.sh enable "$nd" >/dev/null 2>&1; rc=$?
          [ $rc -eq 0 ] && msg="$label DPI motoru başlatıldı." || msg="$label DPI motoru başlatılamadı."
          send "$msg" >/dev/null 2>&1; send_view dpi >/dev/null 2>&1 || true;;
        dpi_stop)
          /opt/kzsc/bin/kzsc-engines.sh disable "$nd" >/dev/null 2>&1; rc=$?
          [ $rc -eq 0 ] && msg="$label DPI motoru durduruldu." || msg="$label DPI motoru durdurulamadı."
          send "$msg" >/dev/null 2>&1; send_view dpi >/dev/null 2>&1 || true;;
        bc_start)
          msg="$(/opt/kzsc/bin/kzsc-blockcheck.sh start "$nd" 'pastebin.com' quick 2>&1 | sed "s/$nd/$label/g")"; rc=$?
          [ -n "$msg" ] && send "$msg" >/dev/null 2>&1
          send_view blockcheck >/dev/null 2>&1 || true;;
        bc_stop)
          msg="$(/opt/kzsc/bin/kzsc-blockcheck.sh stop "$nd" 2>&1 | sed "s/$nd/$label/g")"; rc=$?
          [ -n "$msg" ] && send "$msg" >/dev/null 2>&1
          send_view blockcheck >/dev/null 2>&1 || true;;
      esac
      telegram_debug "callback action=$action target=$nd rc=$rc"
      return $rc;;
    *)
      telegram_debug "callback rejected unknown_action=$action data=$data"
      return 1;;
  esac
}

poll_commands(){
  [ "$(getv TG_ENABLED 0)" = 1 ] || return 0
  [ "$(getv TG_COMMANDS_ENABLED 0)" = 1 ] || return 0
  configured || return 0

  last="$(getv TG_LAST_UPDATE_ID 0)"
  case "$last" in ''|*[!0-9]*) last=0;; esac
  offset=$((last + 1))
  out="$(api getUpdates --data-urlencode "offset=$offset" --data-urlencode 'limit=20' --data-urlencode 'timeout=0')" || return 1
  printf '%s' "$out" | grep -q '"ok"[[:space:]]*:[[:space:]]*true' || { record 0 "$out"; return 1; }

  compact="$(printf '%s' "$out" | tr '\r\n' '  ')"
  printf '%s\n' "$compact" | sed 's/},{"update_id"/}\n{"update_id"/g' | while IFS= read -r obj; do
    uid="$(printf '%s' "$obj" | sed -n 's/.*"update_id"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n1)"
    [ -n "$uid" ] || continue
    setv TG_LAST_UPDATE_ID "$uid" || true

    allowed="$(getv TG_CHAT_ID '')"

    if printf '%s' "$obj" | grep -q '"callback_query"'; then
      # Authorize callbacks by the chat that received the bot message.
      # callback_query.from.id is the clicking user's ID and can legitimately
      # differ from TG_CHAT_ID (for example when TG_CHAT_ID is a group/chat).
      cbpart="${obj#*\"callback_query\"}"
      cbid="$(printf '%s' "$cbpart" | sed -n 's/^[^{]*{[[:space:]]*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
      sender="$(printf '%s' "$cbpart" | sed -n 's/.*"from"[[:space:]]*:[[:space:]]*{[[:space:]]*"id"[[:space:]]*:[[:space:]]*\(-*[0-9][0-9]*\).*/\1/p' | head -n1)"
      cbchat="$(printf '%s' "$cbpart" | grep -oE '"chat"[[:space:]]*:[[:space:]]*\{[^}]*"id"[[:space:]]*:[[:space:]]*-?[0-9]+' | head -n1 | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\(-*[0-9][0-9]*\).*/\1/p')"
      data="$(printf '%s' "$cbpart" | sed -n 's/.*"data"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
      telegram_debug "callback update=$uid chat=${cbchat:-missing} sender=${sender:-missing} data=${data:-missing}"
      if [ -z "$cbchat" ] || [ "$cbchat" != "$allowed" ]; then
        telegram_debug "callback unauthorized update=$uid chat=${cbchat:-missing} sender=${sender:-missing}"
        continue
      fi
      [ -n "$cbid" ] && api answerCallbackQuery --data-urlencode "callback_query_id=$cbid" >/dev/null 2>&1 || true
      if [ -n "$data" ]; then
        if handle_callback "$data" >/dev/null 2>&1; then ok=true; else ok=false; fi
        /opt/kzsc/bin/kzsc-oplog.sh append-local telegram_command "$ok" "Telegram butonu işlendi: ${data%%:*}" "telegram-command-$uid" >/dev/null 2>&1 || true
      else
        telegram_debug "callback missing_data update=$uid"
      fi
      continue
    fi

    chat="$(printf '%s' "$obj" | sed -n 's/.*"chat"[[:space:]]*:[[:space:]]*{[^}]*"id"[[:space:]]*:[[:space:]]*\(-*[0-9][0-9]*\).*/\1/p' | head -n1)"
    [ -n "$chat" ] && [ "$chat" = "$allowed" ] || continue

    text="$(printf '%s' "$obj" | sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\([^"\\]*\)".*/\1/p' | head -n1)"
    [ -n "$text" ] || continue
    case "$text" in /*) :;; *) continue;; esac
    cmd="${text%% *}"; cmd="${cmd%%@*}"
    case "$cmd" in
      /start) send_markup "$(command_help)" "$(menu_keyboard)" >/dev/null 2>&1 || true;;
      /help) send_markup "$(command_help)" "$(menu_keyboard)" >/dev/null 2>&1 || true;;
      /status) send_view status >/dev/null 2>&1 || true;;
      /wan) send_view wan >/dev/null 2>&1 || true;;
      /dpi) send_view dpi >/dev/null 2>&1 || true;;
      /blockcheck) send_view blockcheck >/dev/null 2>&1 || true;;
      /kzsc_update) send_view update >/dev/null 2>&1 || true;;
      *) reply="$(run_command "$text" 2>&1)"; [ -n "$reply" ] || reply='Komut işlendi.'; send "$reply" >/dev/null 2>&1 || true;;
    esac
    /opt/kzsc/bin/kzsc-oplog.sh append-local telegram_command true "Telegram komutu işlendi: $cmd" "telegram-command-$uid" >/dev/null 2>&1 || true
  done
  publish_status >/dev/null 2>&1 || true
  return 0
}

human_reconcile_reason(){
  case "$1" in
    new_wan) echo 'Yeni WAN algılandı' ;;
    binding_changed) echo 'WAN bağlantı eşlemesi değişti' ;;
    profile_missing) echo 'DPI profili eksik' ;;
    *) [ -n "$1" ] && echo "$1" || echo 'WAN değişikliği' ;;
  esac
}

human_reconcile_result(){
  case "$1" in
    preset_verified) echo 'Preset doğrulandı' ;;
    profile_found) echo 'Yeni AUTO profil bulundu' ;;
    no_bypass_needed) echo 'DPI bypass gerekmiyor' ;;
    *) [ -n "$1" ] && echo "$1" || echo 'Tamamlandı' ;;
  esac
}

notify_event(){
  a="$1"; ok="$2"; msg="$3"; icon=""; body="$msg"
  case "$a" in
    telegram_*) return 0 ;;
    wan_reconcile)
      cat=wan
      case "$msg" in
        *"otomatik WAN doğrulaması tamamlandı"*)
          title='WAN Profili Doğrulandı'; icon='✅'
          n_isp="${msg%% otomatik WAN doğrulaması tamamlandı*}"
          n_profile="$(printf '%s' "$msg" | sed -n 's/.*profil=\([^ ·]*\).*/\1/p')"
          n_result="$(printf '%s' "$msg" | sed -n 's/.*sonuç=\([^ ·]*\).*/\1/p')"
          n_result_h="$(human_reconcile_result "$n_result")"
          body="$(printf '%s\nProfil: %s\nSonuç: %s' "${n_isp:-WAN}" "${n_profile:-'-'}" "$n_result_h")"
          ;;
        *"Varsayılan internet bağlantısı değişti"*)
          title='Varsayılan WAN Değişti'; icon='🔁'
          n_old="$(printf '%s' "$msg" | sed -n 's/.*değişti: \([^ ]*\) → \([^ .]*\).*/\1/p')"
          n_new="$(printf '%s' "$msg" | sed -n 's/.*değişti: \([^ ]*\) → \([^ .]*\).*/\2/p')"
          n_old_label="$(isp_label "$n_old")"; [ -n "$n_old_label" ] || n_old_label="$n_old"
          n_new_label="$(isp_label "$n_new")"; [ -n "$n_new_label" ] || n_new_label="$n_new"
          body="$(printf '%s → %s\nCihaz WAN eşlemeleri yenilendi.' "${n_old_label:-Bilinmiyor}" "${n_new_label:-Bilinmiyor}")"
          ;;
        *"bağlantısı değişti/yeni algılandı"*)
          title='WAN Değişikliği Algılandı'; icon='🔄'
          n_isp="${msg%% bağlantısı değişti/yeni algılandı*}"
          n_reason="${msg##*neden=}"
          n_reason_h="$(human_reconcile_reason "$n_reason")"
          body="$(printf '%s\nOtomatik preset doğrulaması başlatıldı.\nNeden: %s' "${n_isp:-WAN}" "$n_reason_h")"
          ;;
        *"bağlantısı kaldırıldı"*)
          title='WAN Bağı Güncellendi'; icon='🧹'
          n_isp="${msg%% bağlantısı kaldırıldı*}"
          body="$(printf '%s\nEski KZSC DPI bağlantısı temizlendi.' "${n_isp:-WAN}")"
          ;;
        *) title='WAN Otomatik Reconcile' ;;
      esac
      ;;
    wan_*) cat=wan; title='WAN' ;;
    zapret2_*) cat=zapret2; title='Zapret2' ;;
    engine_*|dpi_*) cat=dpi; title='DPI' ;;
    blockcheck_*) cat=blockcheck; title='Blockcheck' ;;
    dns_*) cat=dns; title='DNS' ;;
    kzsc_update_*) cat=system; title='KZSC Güncelleme' ;;
    restart) cat=system; title='KZSC Servisi Yeniden Başlatma' ;;
    router_reboot) cat=system; title='Router Yeniden Başlatma' ;;
    *) cat=system; title='KZSC' ;;
  esac
  enabled_for "$cat" || return 0
  if [ -z "$icon" ]; then case "$ok" in true|1) icon='✅';; *) icon='❌';; esac; fi
  tg_text="$(printf '%s KZSC · %s\n%s' "$icon" "$title" "$body")"
  send "$tg_text" >/dev/null 2>&1 || true
}

notify_wan(){
  ndmc="$1"; label="$2"; from="$3"; to="$4"
  rid="wan-event-$(date +%s)-$$"
  case "$to" in up)icon='🟢'; msg="$label bağlantısı aktif: $from → $to";;*)icon='🔴'; msg="$label bağlantısı koptu: $from → $to";;esac
  /opt/kzsc/bin/kzsc-oplog.sh append-local wan_state_change true "$msg" "$rid" >/dev/null 2>&1 || true
  enabled_for wan||return 0
  tg_text="$(printf '%s KZSC WAN · %s\n%s → %s' "$icon" "$label" "$from" "$to")"
  send "$tg_text" >/dev/null 2>&1||true
}
notify_system(){
  msg="$*"; rid="system-event-$(date +%s)-$$"
  /opt/kzsc/bin/kzsc-oplog.sh append-local system_event true "$msg" "$rid" >/dev/null 2>&1 || true
  enabled_for system||return 0
  send "ℹ️ KZSC · $msg" >/dev/null 2>&1||true
}
case "${1:-status}" in status)status;;publish-status)publish_status;;save)shift;save "$@";;test)testmsg;;find-chat)findchat;;send)shift;send "$*";;send-file)shift;send_file "$1" "$2";;poll-commands)poll_commands;;notify-event)shift;notify_event "$@";;notify-wan)shift;notify_wan "$@";;notify-system)shift;notify_system "$@";;*)echo 'Usage: kzsc-telegram {status|save|test|find-chat|send|send-file|poll-commands|notify-event|notify-wan|notify-system}';exit 1;;esac
