#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

fail=0
ok(){ echo "OK   $*"; }
bad(){ echo "FAIL $*"; fail=1; }
warn(){ echo "WARN $*"; }
ce(){ [ -x "$1" ] && ok "$2" || bad "$2"; }
has(){ grep -Fq "$2" "$1" 2>/dev/null && ok "$3" || bad "$3"; }
WWW="$KZSC_HOME/www"
CGI="$WWW/cgi-bin"

buttons(){
  echo "=== KZSC BUTTON / UI ACTION AUDIT ==="
  idx="$WWW/index.html"
  [ -f "$idx" ] || { bad "index.html yok"; return; }

  has "$idx" 'class="tabbtn' "Sekme navigasyonu handler kaynağı"
  has "$idx" "document.querySelectorAll('.tabbtn').forEach" "Sekme click handler"
  has "$idx" 'id="langBtn"' "Dil menüsü butonu"
  has "$idx" "const btn=document.getElementById('langBtn')" "Dil menüsü handler kaynağı"
  has "$idx" "btn?.addEventListener('click'" "Dil menüsü click handler"
  has "$idx" "document.querySelectorAll('[data-lang-option]').forEach(b=>b.addEventListener('click'" "TR/EN seçim handler"
  has "$idx" "getElementById('deviceFilter')?.addEventListener('change'" "Cihaz filtresi handler"
  has "$idx" "getElementById('deviceSearch')?.addEventListener('input'" "Cihaz arama handler"
  ce "$CGI/dpi_policy.cgi" "DPI politika CGI"
  ce "$KZSC_HOME/bin/kzsc-dpi-policy.sh" "DPI politika backend"
  has "$idx" "function renderDpiPolicy" "WAN DPI politika görünümü"
  has "$idx" "deviceZapretToggle" "Cihaz Zapret aç/kapat kontrolü"
  has "$idx" "deviceStaticSave" "Keenetic DHCP sabit IP kontrolü"
  grep -Fq 'ip dhcp host $mac $ip' "$KZSC_HOME/bin/kzsc-dpi-policy.sh" \
    && grep -Fq "action:'static'" "$idx" \
    && ok "Keenetic DHCP sabit IP rezervasyonu akışı" || bad "Keenetic DHCP sabit IP rezervasyonu akışı"
  has "$idx" 'compareTabBtn' "WAN Comparison sekmesi dinamik görünürlük"

  for a in install update repair remove; do ce "$CGI/zapret2_${a}.cgi" "Zapret2 $a CGI"; done
  has "$idx" '.z2ActionBtn' "Zapret2 action handler"
  has "$idx" "document.querySelectorAll('.presetApplyBtn').forEach" "DPI profil kaydet handler"
  has "$idx" "document.querySelectorAll('.engineStartBtn').forEach" "DPI motor başlat handler"
  has "$idx" "document.querySelectorAll('.engineStopBtn').forEach" "DPI motor durdur handler"
  has "$idx" "document.querySelectorAll('.bcStartBtn').forEach" "Blockcheck başlat handler"
  has "$idx" "document.querySelectorAll('.bcStopBtn').forEach" "Blockcheck durdur handler"

  ce "$CGI/dns_status.cgi" "DNS status CGI"
  ce "$CGI/dns_disable.cgi" "DNS disable CGI"
  has "$idx" "dnsApplyBtn')?.addEventListener('click',applyDns)" "DNS Apply handler"
  has "$idx" "dnsDisableBtn')?.addEventListener('click',disableDns)" "DNS Disable handler"
  for p in cloudflare google quad9 adguard; do
    for proto in dot doh both; do
      for mode in keep ignore; do
        ce "$CGI/dns_apply_${p}_${proto}_${mode}.cgi" "DNS ${p}/${proto}/${mode}"
        ce "$CGI/dns_clean_${p}_${proto}_${mode}.cgi" "DNS clean ${p}/${proto}/${mode}"
      done
    done
  done

  ce "$CGI/telegram_save.cgi" "Telegram Save CGI"
  ce "$CGI/telegram_test.cgi" "Telegram Test CGI"
  ce "$CGI/telegram_find_chat.cgi" "Telegram Find Chat CGI"
  has "$idx" 'tgSaveBtn.addEventListener' "Telegram Save handler"
  has "$idx" 'tgTestBtn.addEventListener' "Telegram Test handler"
  has "$idx" 'tgFindChatBtn.addEventListener' "Telegram Find Chat handler"

  ce "$CGI/operation_log_clear.cgi" "Event Log Clear CGI"
  grep -Fq '|operation_log_clear' "$CGI/operation_log_clear.cgi" \
    && grep -Fq 'append operation_log_clear true' "$KZSC_HOME/bin/kzsc-maintenance.sh" \
    && ok "Event Log Clear daemon kuyruğu ve audit kaydı" || bad "Event Log Clear audit kuyruğu"
  ! grep -Fq 'data-tab="operationLogPanel"' "$idx" \
    && ! grep -Fq 'id="operationLogPanel"' "$idx" \
    && ! grep -Fq 'id="operationLog"' "$idx" \
    && ok "Olay Günlüğü görünür sekmesi kaldırıldı" || bad "Olay Günlüğü görünür UI kalıntısı"

  ce "$CGI/settings.cgi" "Settings CGI"
  ce "$CGI/restart.cgi" "KZSC Restart CGI"
  ce "$CGI/router_reboot.cgi" "Router Reboot CGI"
  has "$idx" "settingsForm').addEventListener('submit'" "Settings submit handler"
  has "$idx" "kzscRestartBtn')?.addEventListener" "KZSC Restart handler"
  has "$idx" "routerRebootBtn')?.addEventListener" "Router Reboot handler"
  grep -Fq 'waitKzscServiceReady' "$idx" \
    && grep -Fq 'ACTION="restart"' "$CGI/restart.cgi" \
    && grep -Fq '"$RID" "$ACTION"' "$CGI/restart.cgi" \
    && grep -Fq "[ \"\$action\" = \"restart\" ]" "$KZSC_HOME/bin/kzsc-maintenance.sh" \
    && ok "KZSC Restart doğrulanan bakım kuyruğu" || bad "KZSC Restart bakım akışı"
  grep -Fq 'ACTION="router_reboot"' "$CGI/router_reboot.cgi" \
    && grep -Fq '"$RID" "$ACTION"' "$CGI/router_reboot.cgi" \
    && grep -Fq 'REQUEST_METHOD:-GET' "$CGI/router_reboot.cgi" \
    && grep -Fq 'HTTP_X_KZSC_ACTION' "$CGI/router_reboot.cgi" \
    && grep -Fq "'X-KZSC-Action':'router-reboot'" "$idx" \
    && grep -Fq "system reboot 30" "$KZSC_HOME/bin/kzsc-maintenance.sh" \
    && grep -Fq 'for candidate in /bin/ndmc' "$KZSC_HOME/bin/kzsc-maintenance.sh" \
    && grep -Fq "router_reboot) cat=system; title='Router Yeniden Başlatma'" "$KZSC_HOME/bin/kzsc-telegram.sh" \
    && ok "Router Reboot doğrulanan NDMC/Telegram bakım kuyruğu" || bad "Router Reboot bakım akışı"
  grep -Fq 'unset LD_LIBRARY_PATH' "$CGI/settings.cgi" && ok "Settings CGI temiz LD_LIBRARY_PATH" || bad "Settings CGI environment regression"
  grep -Fq 'body="${QUERY_STRING:-}"' "$CGI/settings.cgi" && ok "Settings CGI QUERY_STRING fallback" || bad "Settings CGI QUERY_STRING fallback"
  grep -Fq "settings.cgi?'+body.toString()" "$idx" && ok "Settings POST query mirror" || bad "Settings POST query mirror"
  grep -Fq 'kzsc-keendns.sh audit' "$CGI/settings.cgi" && ok "Settings port change KeenDNS audit" || bad "Settings port change KeenDNS audit"
  grep -Fq 'rollback_port(){' "$CGI/settings.cgi" && ok "Settings port rollback" || bad "Settings port rollback"

  ce "$CGI/keendns_enable.cgi" "KeenDNS Enable CGI"
  ce "$CGI/keendns_disable.cgi" "KeenDNS Disable CGI"
  ce "$CGI/ui_event.cgi" "UI audit event CGI"
  has "$idx" "keendnsEnableBtn')?.addEventListener" "KeenDNS Enable handler"
  has "$idx" "keendnsDisableBtn')?.addEventListener" "KeenDNS Disable handler"
  has "$idx" "keendnsCopyBtn')?.addEventListener" "KeenDNS Copy handler"
  has "$idx" "keendnsOpenBtn')?.addEventListener" "KeenDNS Open handler"
  has "$idx" "logUiEvent('keendns_copy'" "KeenDNS Copy Event Log hook"
  has "$idx" "logUiEvent('keendns_open'" "KeenDNS Open Event Log hook"
  grep -Fq 'ui_event:%s:%s' "$CGI/ui_event.cgi" \
    && grep -Fq 'ui_event:*)' "$KZSC_HOME/bin/kzsc-maintenance.sh" \
    && grep -Fq 'waitMaintenanceResult(queued.request_id,45000)' "$idx" \
    && ok "UI olayları daemon tarafından doğrulanıyor" || bad "UI olay audit kuyruğu/doğrulaması"
  grep -Fq 'kzsc-oplog.sh append settings_save' "$CGI/settings.cgi" && ok "Settings Save Event Log hook" || bad "Settings Save Event Log hook"
  grep -Fq 'kzsc-oplog.sh append "$action"' "$KZSC_HOME/bin/kzsc-maintenance.sh" && ok "Maintenance actions Event Log merkezi hook" || bad "Maintenance actions Event Log merkezi hook"
  grep -Fq 'backup_download:' "$CGI/backup_download.cgi" && ok "Backup Download Event Log queue hook" || bad "Backup Download Event Log queue hook"
  grep -Fq 'safe_backup_name(){' "$KZSC_HOME/bin/kzsc-backup.sh" \
    && grep -Fq 'validate_extracted(){' "$KZSC_HOME/bin/kzsc-backup.sh" \
    && grep -Fq 'MAX_BACKUP_BYTES=5242880' "$KZSC_HOME/bin/kzsc-backup.sh" \
    && grep -Fq 'backup_too_large' "$CGI/backup_restore.cgi" \
    && ok "Yedek adı/boyut/içerik güvenlik doğrulaması" || bad "Yedek restore hardening"
  grep -Fq 'kzsc_lock_acquire oplog' "$KZSC_HOME/bin/kzsc-oplog.sh" \
    && grep -Fq 'publish_unlocked' "$KZSC_HOME/bin/kzsc-oplog.sh" \
    && ok "Olay Günlüğü eşzamanlı yazım kilidi" || bad "Olay Günlüğü yazım kilidi"
  ! grep -Fq 'kzsc-oplog.sh append' "$KZSC_HOME/bin/kzsc-dns-cgi.sh" \
    && grep -Fq 'run_dns_mutation dns_apply' "$KZSC_HOME/bin/kzsc-dns.sh" \
    && ok "DNS olayı backend tarafından tek kez kaydediliyor" || bad "DNS mükerrer Olay Günlüğü kaydı"
  grep -Fq 'const marker=(core.match' "$idx" \
    && grep -Fq 'if(d)setNoticeText(d,text)' "$idx" \
    && ok "TR/EN simgeli ve dinamik bildirim çevirisi" || bad "TR/EN operasyon bildirimi çevirisi"

  for x in create telegram download restore restore_saved delete status; do ce "$CGI/backup_${x}.cgi" "Backup ${x} CGI"; done
  for id in backupCreateBtn backupTelegramBtn backupDownloadBtn backupRestoreSavedBtn backupDeleteBtn backupRestoreBtn; do
    grep -Fq "id=\"$id\"" "$idx" && ok "UI $id" || bad "UI $id"
  done
  for id in backupCreateBtn backupTelegramBtn backupRestoreSavedBtn backupDeleteBtn backupRestoreBtn; do
    grep -Fq "getElementById('$id')?.addEventListener" "$idx" && ok "$id click handler" || bad "$id click handler"
  done
  grep -Fq "dl.href=active?'cgi-bin/backup_download.cgi" "$idx" && ok "Backup Download href handler" || bad "Backup Download href handler"

  /opt/kzsc/bin/kzsc-presets-cgi.sh >/dev/null 2>&1 || true
  /opt/kzsc/bin/kzsc-engine-cgi.sh >/dev/null 2>&1 || true
  /opt/kzsc/bin/kzsc-blockcheck-cgi.sh >/dev/null 2>&1 || true
  for nd in $(internet_wans); do
    id="$(printf '%s' "$nd" | tr ' A-Z/:.' '_a-z___' | tr -cd 'a-z0-9_-')"
    ce "$CGI/engine_enable_${id}.cgi" "$nd engine start endpoint"
    ce "$CGI/engine_disable_${id}.cgi" "$nd engine stop endpoint"
    ce "$CGI/blockcheck_start_${id}.cgi" "$nd Blockcheck start endpoint"
    ce "$CGI/blockcheck_stop_${id}.cgi" "$nd Blockcheck stop endpoint"
    for p in tt sol kablonet; do ce "$CGI/profile_set_${id}_${p}.cgi" "$nd profile $p endpoint"; done
    auto="auto_$id"
    if [ -f "$KZSC_HOME/var/dpi/auto-presets/$auto.conf" ]; then
      ce "$CGI/profile_set_${id}_${auto}.cgi" "$nd AUTO profile endpoint"
    fi
  done
  grep -Fq 'auto_*)' "$KZSC_HOME/bin/kzsc-maintenance.sh" && ok "AUTO profile maintenance acceptance" || bad "AUTO profile maintenance acceptance"
  grep -Fq "document.querySelectorAll('.z2ActionBtn').forEach(b=>b.disabled=true)" "$idx" && ok "Zapret2 busy state yalnız Zapret2 butonlarını kilitliyor" || bad "Global button disabled-state regression koruması"
  grep -Fq 'blockcheckNoticePrimed' "$idx" && ok "Eski Blockcheck sonuçları sayfa açılışında toast olarak tekrarlanmıyor" || bad "Blockcheck historical notice priming"
}

versioncheck(){
  echo "=== KZSC RELEASE VERSION CONSISTENCY AUDIT ==="

  vf="$KZSC_HOME/bin/kzsc-maintenance.sh"
  master="$(sed -n 's/^VERSION="\([^"]*\)"$/\1/p' "$vf" 2>/dev/null | head -n1)"

  case "$master" in
    0.11.2.[0-9]*-generic)
      ok "Canonical release version: $master"
      ;;
    *)
      bad "Canonical release version okunamadi/gecersiz: ${master:-<empty>}"
      return
      ;;
  esac

  expected_v="v$master"

  grep -Fq "=== KZSC $expected_v diagnostics ===" \
    "$KZSC_HOME/bin/kzsc" &&
    ok "CLI diagnostics version" ||
    bad "CLI diagnostics version"

  grep -Fq "version=$master" \
    "$KZSC_HOME/bin/kzsc-backup.sh" &&
    ok "Backup metadata version" ||
    bad "Backup metadata version"

  grep -Fq "KZSC $expected_v" \
    "$KZSC_HOME/bin/kzsc-telegram.sh" &&
    ok "Telegram status version" ||
    bad "Telegram status version"

  grep -Fq "# Keenetic Zapret Smart Control $expected_v" \
    "$KZSC_HOME/etc/kzsc.conf.example" &&
    ok "Config example version" ||
    bad "Config example version"

  foreign=0

  for f in \
    "$KZSC_HOME/bin/kzsc" \
    "$KZSC_HOME/bin/kzsc-backup.sh" \
    "$KZSC_HOME/bin/kzsc-telegram.sh" \
    "$KZSC_HOME/bin/kzsc-maintenance.sh" \
    "$KZSC_HOME/etc/kzsc.conf.example"
  do
    refs="$(
      grep -Eo 'v?0\.11\.2\.[0-9]+-generic' "$f" 2>/dev/null |
      sort -u
    )"

    if [ -z "$refs" ]; then
      echo "FAIL release version ref missing: $f"
      foreign=1
      continue
    fi

    file_bad=0

    for r in $refs
    do
      normalized="${r#v}"

      if [ "$normalized" != "$master" ]; then
        echo "FAIL foreign version: $f -> $r (expected $master)"
        file_bad=1
        foreign=1
      fi
    done

    [ "$file_bad" -eq 0 ] &&
      ok "Release version consistency: ${f##*/}"
  done

  [ "$foreign" -eq 0 ] ||
    bad "Release version consistency"
}

code(){
  echo "=== KZSC CODE / OWNERSHIP AUDIT ==="
  /opt/kzsc/bin/kzsc-purity.sh check || fail=1

  # Release metadata must agree across all active version-bearing files.
  versioncheck

  shell_fail=0
  for f in "$KZSC_HOME"/bin/* "$KZSC_HOME"/www/cgi-bin/* /opt/etc/init.d/S99kzsc; do
    [ -f "$f" ] || continue
    first="$(head -n1 "$f" 2>/dev/null)"
    case "$first" in '#!'*sh*) /opt/bin/sh -n "$f" >/dev/null 2>&1 || { echo "FAIL shell syntax: $f"; shell_fail=1; };; esac
  done
  [ "$shell_fail" -eq 0 ] && ok "Tüm KZSC shell/CGI syntax" || { bad "Shell syntax"; }

  [ -L /opt/bin/kzsc ] && [ "$(readlink /opt/bin/kzsc 2>/dev/null)" = "/opt/kzsc/bin/kzsc" ] && ok "/opt/bin/kzsc doğru standalone symlink" || bad "/opt/bin/kzsc symlink"
  ce /opt/etc/init.d/S99kzsc "KZSC init script"
  grep -Fq 'proxy_port(){' "$KZSC_HOME/bin/kzsc-keendns.sh" && grep -Fq '[ "$actual" != "$want" ]' "$KZSC_HOME/bin/kzsc-keendns.sh" && ok "KeenDNS port-aware sync" || bad "KeenDNS port-aware sync"
  grep -Fq 'audit) audit;;' "$KZSC_HOME/bin/kzsc-keendns.sh" && ok "KeenDNS port audit CLI" || bad "KeenDNS port audit CLI"

  unexpected=0
  for f in "$KZSC_HOME/bin"/*; do
    [ -f "$f" ] || continue
    case "${f##*/}" in
      kzsc|kzsc-audit.sh|kzsc-backup.sh|kzsc-blockcheck-cgi.sh|kzsc-bootstrap.sh|kzsc-dpi-policy.sh|kzsc-keendns.sh|kzsc-blockcheck.sh|kzsc-clients.sh|kzsc-daemon.sh|kzsc-discover.sh|kzsc-dns-cgi.sh|kzsc-dns.sh|kzsc-engine-cgi.sh|kzsc-engines.sh|kzsc-isolation.sh|kzsc-lib.sh|kzsc-maintenance.sh|kzsc-native-dpi.sh|kzsc-oplog.sh|kzsc-preflight.sh|kzsc-presets-cgi.sh|kzsc-presets.sh|kzsc-purity.sh|kzsc-reconcile.sh|kzsc-settings.sh|kzsc-telegram.sh|kzsc-ui-selftest.sh|kzsc-uninstall.sh|kzsc-updater.sh|kzsc-wan-registry.sh|kzsc-wan.sh|kzsc-zapret2.sh) :;;
      *) echo "FAIL unexpected KZSC bin: $f"; unexpected=1;;
    esac
  done
  [ "$unexpected" -eq 0 ] && ok "KZSC bin allow-list temiz" || bad "KZSC bin allow-list"

  unexpected_cgi=0
  for f in "$KZSC_HOME/www/cgi-bin"/*; do
    [ -f "$f" ] || continue
    b="${f##*/}"
    case "$b" in
      clients|health.cgi|operation_log_clear.cgi|ui_event.cgi|settings.cgi|restart.cgi|router_reboot.cgi|dpi_policy.cgi|refresh.cgi|keendns_enable.cgi|keendns_disable.cgi|state|topology|wan_check.cgi|zapret2_install.cgi|zapret2_update.cgi|zapret2_repair.cgi|zapret2_remove.cgi|kzsc_update_check.cgi|kzsc_update_install.cgi|kzsc_update_auto_on.cgi|kzsc_update_auto_off.cgi) :;;
      engine_enable_*.cgi|engine_disable_*.cgi|profile_set_*.cgi|blockcheck_start_*.cgi|blockcheck_stop_*.cgi|dns_*.cgi|telegram_*.cgi|backup_*.cgi) :;;
      *) echo "FAIL unexpected KZSC CGI: $f"; unexpected_cgi=1;;
    esac
  done
  [ "$unexpected_cgi" -eq 0 ] && ok "KZSC CGI allow-list temiz" || bad "KZSC CGI allow-list"

  unexpected_root=0
  for f in "$KZSC_HOME"/*; do
    [ -e "$f" ] || continue
    case "${f##*/}" in bin|etc|share|var|www|zapret2) :;; *) echo "FAIL unexpected KZSC root entry: $f"; unexpected_root=1;; esac
  done
  [ "$unexpected_root" -eq 0 ] && ok "KZSC root allow-list temiz" || bad "KZSC root allow-list"

  unexpected_www=0
  for f in "$KZSC_HOME/www"/*; do
    [ -e "$f" ] || continue
    case "${f##*/}" in index.html|cgi-bin|data) :;; *) echo "FAIL unexpected KZSC www entry: $f"; unexpected_www=1;; esac
  done
  [ "$unexpected_www" -eq 0 ] && ok "KZSC www allow-list temiz" || bad "KZSC www allow-list"

  unexpected_etc=0
  for f in "$KZSC_HOME/etc"/*; do
    [ -f "$f" ] || continue
    case "${f##*/}" in kzsc.conf|kzsc.conf.example|isp-map.conf|isp-map.conf.example|dpi-map.conf|dpi-map.conf.example|telegram.conf|lighttpd.conf) :;; *) echo "FAIL unexpected KZSC etc file: $f"; unexpected_etc=1;; esac
  done
  [ "$unexpected_etc" -eq 0 ] && ok "KZSC etc allow-list temiz" || bad "KZSC etc allow-list"

  unexpected_share=0
  for f in "$KZSC_HOME/share"/dpi-presets/*; do
    [ -f "$f" ] || continue
    case "${f##*/}" in tt.conf|sol.conf|kablonet.conf) :;; *) echo "FAIL unexpected KZSC share preset: $f"; unexpected_share=1;; esac
  done
  for f in "$KZSC_HOME/share"/*; do
    [ -e "$f" ] || continue
    case "${f##*/}" in dpi-presets) :;; *) echo "FAIL unexpected KZSC share entry: $f"; unexpected_share=1;; esac
  done
  [ "$unexpected_share" -eq 0 ] && ok "KZSC share allow-list temiz" || bad "KZSC share allow-list"

  # Runtime uses a small, explicit set of symlinks. Validate both path and target
  # instead of treating every symlink as foreign product residue.
  unsafe_links=""
  while IFS= read -r link; do
    [ -n "$link" ] || continue
    target="$(readlink "$link" 2>/dev/null)"
    case "$link" in
      "$KZSC_HOME/www/data/status.json") [ "$target" = "$KZSC_HOME/var/status.json" ] || unsafe_links="$unsafe_links\n$link -> $target" ;;
      "$KZSC_HOME/www/data/clients.json") [ "$target" = "$KZSC_HOME/var/clients.json" ] || unsafe_links="$unsafe_links\n$link -> $target" ;;
      "$KZSC_HOME/www/data/topology.json") [ "$target" = "$KZSC_HOME/var/topology.json" ] || unsafe_links="$unsafe_links\n$link -> $target" ;;
      "$KZSC_HOME"/var/blockcheck/*/run/mdig/mdig|"$KZSC_HOME"/var/blockcheck/*/run/nfq2/nfqws2|"$KZSC_HOME"/var/blockcheck/*/run/ip2net/ip2net)
        case "$target" in
          "$KZSC_HOME/zapret2/"*|../binaries/*) : ;;
          *) unsafe_links="$unsafe_links\n$link -> $target" ;;
        esac
        ;;
      *) unsafe_links="$unsafe_links\n$link -> $target" ;;
    esac
  done <<EOF
$(find "$KZSC_HOME" -path "$KZSC_HOME/zapret2" -prune -o -type l -print 2>/dev/null)
EOF
  unsafe_links="$(printf '%b' "$unsafe_links" | sed '/^$/d' | head -n 20)"
  if [ -n "$unsafe_links" ]; then
    echo "FAIL unexpected/unsafe KZSC-owned symlink(s):"
    printf '%s\n' "$unsafe_links"
    bad "KZSC-owned symlink target audit"
  else
    ok "KZSC-owned symlink target audit temiz"
  fi

  old_mgr="k""zm2"
  old_cli="k""sc"
  name_hits="$(find /opt \( -iname "*${old_mgr}*" -o -iname "*${old_cli}*" \) 2>/dev/null | grep -v '^/opt/kzsc/zapret2/' | head -n 20)"
  if [ -n "$name_hits" ]; then
    echo "FAIL retired product filesystem names bulundu:"
    printf '%s\n' "$name_hits"
    bad "Retired product filesystem name scan"
  else
    ok "Retired product filesystem name scan boş"
  fi
}

httpcheck(){
  echo "=== KZSC HTTP / CGI RUNTIME AUDIT ==="

  if ! command -v curl >/dev/null 2>&1; then
    bad "curl mevcut degil; HTTP runtime audit yapilamadi"
    return
  fi

  expected="$(/opt/kzsc/bin/kzsc-settings.sh json 2>/dev/null)"
  if [ -z "$expected" ]; then
    bad "Settings backend JSON"
    return
  fi

  port="$(printf '%s' "$expected" | sed -n 's/.*"port":\([0-9][0-9]*\).*/\1/p')"
  lan="$(printf '%s' "$expected" | sed -n 's/.*"lan_ip":"\([^"]*\)".*/\1/p')"

  [ -n "$port" ] || port="${KZSC_PORT:-9090}"
  [ -n "$lan" ] || lan="$(detect_lan_ip | head -n1)"

  if [ -z "$lan" ]; then
    bad "HTTP audit LAN IP tespit edilemedi"
    return
  fi

  local_url="http://$lan:$port/cgi-bin/settings.cgi"
  actual="$(curl -fsS --max-time 5 "$local_url" 2>/dev/null)"

  if [ "$actual" = "$expected" ]; then
    ok "Settings CGI local HTTP GET + CGI environment"
  else
    echo "Expected: $expected"
    echo "Actual:   ${actual:-<empty>}"
    bad "Settings CGI local HTTP runtime"
  fi

  health_url="http://$lan:$port/cgi-bin/health.cgi"
  health="$(curl -fsS --max-time 5 "$health_url" 2>/dev/null)"
  if printf '%s' "$health" | grep -q '"ok":true' \
    && printf '%s' "$health" | grep -q '"maintenance_queue":true'; then
    ok "CGI maintenance queue yazma/geçiş izinleri"
  else
    echo "Health: ${health:-<empty>}"
    bad "CGI maintenance queue runtime"
  fi

  kd="$(/opt/kzsc/bin/kzsc-keendns.sh status 2>/dev/null)"
  kd_enabled="$(printf '%s' "$kd" | sed -n 's/.*"enabled":\(true\|false\).*/\1/p')"

  if [ "$kd_enabled" = true ]; then
    if /opt/kzsc/bin/kzsc-keendns.sh audit >/tmp/kzsc-http-kd.$$ 2>&1; then
      cat /tmp/kzsc-http-kd.$$
      ok "KeenDNS proxy port runtime audit"
    else
      cat /tmp/kzsc-http-kd.$$
      bad "KeenDNS proxy port runtime audit"
    fi
    rm -f /tmp/kzsc-http-kd.$$

    kdurl="$(printf '%s' "$kd" | sed -n 's/.*"url":"\([^"]*\)".*/\1/p')"
    if [ -n "$kdurl" ]; then
      remote="$(curl -k -fsS --max-time 10 "$kdurl/cgi-bin/settings.cgi" 2>/dev/null)"
      if [ "$remote" = "$expected" ]; then
        ok "Settings CGI KeenDNS HTTPS GET"
      else
        warn "KeenDNS HTTPS GET router icinden dogrulanamadi (hairpin/DNS olabilir)"
      fi
    fi
  else
    ok "KeenDNS kapali; external HTTP testi atlandi"
  fi
}

runtime(){
  echo "=== KZSC RUNTIME AUDIT ==="
  /opt/etc/init.d/S99kzsc status >/tmp/kzsc-audit-status.$$ 2>&1
  rc=$?; cat /tmp/kzsc-audit-status.$$; rm -f /tmp/kzsc-audit-status.$$
  [ "$rc" -eq 0 ] && ok "KZSC service status" || bad "KZSC service status"

  # Real lighttpd/CGI regression check.
  httpcheck

  /opt/kzsc/bin/kzsc-native-dpi.sh check-all >/tmp/kzsc-audit-dpi.$$ 2>&1
  rc=$?; cat /tmp/kzsc-audit-dpi.$$; rm -f /tmp/kzsc-audit-dpi.$$
  [ "$rc" -eq 0 ] && ok "Enabled DPI process + datapath" || bad "Enabled DPI process + datapath"

  rec="$(/opt/kzsc/bin/kzsc-reconcile.sh status 2>/dev/null)"
  printf '%s\n' "$rec"
  printf '%s' "$rec" | grep -q '"pending":0' && ok "WAN reconcile pending=0" || bad "WAN reconcile pending"

  bc="$(/opt/kzsc/bin/kzsc-blockcheck.sh status 2>/dev/null)"
  printf '%s\n' "$bc"
  printf '%s' "$bc" | grep -q '"running":0' && ok "Blockcheck idle" || warn "Blockcheck aktif; stale-process denetimi test sonrası tekrar edilmeli"

  stale="$(ps w 2>/dev/null | grep -E 'blockcheck2|/opt/kzsc/var/blockcheck/.*/run/' | grep -v grep)"
  if [ -n "$stale" ]; then printf '%s\n' "$stale"; bad "Stale Blockcheck process"; else ok "Stale Blockcheck process yok"; fi

  chains="$(iptables-save -t mangle 2>/dev/null | grep '^:blockcheck_' || true)"
  if [ -n "$chains" ]; then printf '%s\n' "$chains"; bad "Stale upstream blockcheck chain"; else ok "Stale upstream blockcheck chain yok"; fi

  # Runtime state belonging to a WAN that no longer exists must not accumulate.
  valid_ids=" "
  for nd in $(internet_wans); do
    sid="$(printf '%s' "$nd" | tr ' A-Z/:.' '_a-z___' | tr -cd 'a-z0-9_-')"
    [ -n "$sid" ] && valid_ids="$valid_ids$sid "
  done
  orphan=0
  for d in "$KZSC_HOME"/var/dpi/engines/* "$KZSC_HOME"/var/blockcheck/*; do
    [ -d "$d" ] || continue
    sid="${d##*/}"
    case "$d" in
      "$KZSC_HOME/var/blockcheck/_global"|"$KZSC_HOME/var/blockcheck/queue"|"$KZSC_HOME/var/blockcheck/scheduler") continue ;;
    esac
    case "$valid_ids" in *" $sid "*) :;; *) echo "FAIL orphan WAN runtime dir: $d"; orphan=1;; esac
  done
  for f in "$KZSC_HOME"/var/reconcile/validated/*.tsv "$KZSC_HOME"/var/dpi/wan-registry/*.queue "$KZSC_HOME"/var/dpi/wan-registry/*.profile; do
    [ -f "$f" ] || continue
    sid="${f##*/}"; sid="${sid%.*}"
    case "$valid_ids" in *" $sid "*) :;; *) echo "FAIL orphan WAN runtime file: $f"; orphan=1;; esac
  done
  for f in "$KZSC_HOME"/var/dpi/auto-presets/auto_*.conf; do
    [ -f "$f" ] || continue
    sid="${f##*/}"; sid="${sid#auto_}"; sid="${sid%.conf}"
    case "$valid_ids" in *" $sid "*) :;; *) echo "FAIL orphan AUTO profile: $f"; orphan=1;; esac
  done
  for f in "$CGI"/blockcheck_start_*.cgi "$CGI"/blockcheck_stop_*.cgi "$CGI"/engine_enable_*.cgi "$CGI"/engine_disable_*.cgi; do
    [ -f "$f" ] || continue
    sid="${f##*/}"; sid="${sid%.cgi}"
    case "$sid" in blockcheck_start_*) sid="${sid#blockcheck_start_}";; blockcheck_stop_*) sid="${sid#blockcheck_stop_}";; engine_enable_*) sid="${sid#engine_enable_}";; engine_disable_*) sid="${sid#engine_disable_}";; esac
    case "$valid_ids" in *" $sid "*) :;; *) echo "FAIL orphan WAN CGI endpoint: $f"; orphan=1;; esac
  done
  [ "$orphan" -eq 0 ] && ok "Orphan WAN runtime/CGI state yok" || bad "Orphan WAN runtime/CGI state"

  # KZSC queue chains must belong to a currently registered queue.
  regqs="$(for qf in "$KZSC_HOME"/var/dpi/wan-registry/*.queue; do [ -f "$qf" ] && cat "$qf"; done | sort -nu)"
  staleq=0
  for q in $(iptables-save -t mangle 2>/dev/null | sed -n 's/^:KZSC\([0-9][0-9]*\)[IO] .*/\1/p' | sort -nu); do
    printf '%s\n' "$regqs" | grep -qx "$q" || { echo "FAIL stale KZSC queue chain: $q"; staleq=1; }
  done
  [ "$staleq" -eq 0 ] && ok "KZSC queue chain registry eşleşmesi" || bad "KZSC queue chain registry"

  [ ! -f "$KZSC_HOME/etc/telegram.conf" ] || {
    perm_text="$(ls -l "$KZSC_HOME/etc/telegram.conf" 2>/dev/null | awk '{print $1}')"
    [ "$perm_text" = "-rw-------" ] && ok "Telegram config permission 600" || bad "Telegram config permission=$perm_text"
  }

  # Telegram user configuration and mutable runtime state must stay separate.
  tg_conf="$KZSC_HOME/etc/telegram.conf"
  tg_state="$KZSC_HOME/var/lib/telegram-state.conf"

  if [ -f "$tg_conf" ]; then
    if grep -q '^TG_LAST_' "$tg_conf" 2>/dev/null; then
      bad "Telegram config runtime state ayrimi"
    else
      ok "Telegram config runtime state ayrimi"
    fi
  fi

  if [ -f "$tg_state" ]; then
    state_perm="$(ls -l "$tg_state" 2>/dev/null | awk '{print $1}')"
    [ "$state_perm" = "-rw-------" ] &&
      ok "Telegram state permission 600" ||
      bad "Telegram state permission=$state_perm"

    state_bad=0
    for k in TG_LAST_UPDATE_ID TG_LAST_SENT TG_LAST_ERROR; do
      grep -q "^${k}=" "$tg_state" 2>/dev/null || {
        echo "FAIL Telegram state key missing: $k"
        state_bad=1
      }
    done

    unexpected_state_keys="$(
      sed -n 's/^\([A-Za-z0-9_][A-Za-z0-9_]*\)=.*/\1/p' "$tg_state" 2>/dev/null |
      grep -Ev '^(TG_LAST_UPDATE_ID|TG_LAST_SENT|TG_LAST_ERROR)$'
    )"

    if [ -n "$unexpected_state_keys" ]; then
      printf '%s\n' "$unexpected_state_keys"
      state_bad=1
    fi

    [ "$state_bad" -eq 0 ] &&
      ok "Telegram state key allow-list" ||
      bad "Telegram state key allow-list"
  else
    bad "Telegram runtime state dosyasi yok"
  fi

  /opt/kzsc/bin/kzsc-oplog.sh selfcheck >/dev/null 2>&1 && ok "Operation Log selfcheck" || bad "Operation Log selfcheck"
  /opt/kzsc/bin/kzsc-zapret2.sh status 2>/dev/null | grep -q '"failed_tree":false' && ok "Zapret2 tree status" || bad "Zapret2 tree status"
  update_json="$(/opt/kzsc/bin/kzsc-updater.sh status 2>/dev/null)"
  printf '%s' "$update_json" | grep -q '"repo":"ssy1979/keenetic-zapret-smart-control"' && \
    printf '%s' "$update_json" | grep -q '"current":"0.11.2.31-generic"' && \
    ok "KZSC updater status/trusted channel" || bad "KZSC updater status/trusted channel"
}

full(){
  buttons
  code
  runtime
  echo "=== KZSC EXISTING SELFTEST ==="
  /opt/kzsc/bin/kzsc-ui-selftest.sh || fail=1
}

case "${1:-full}" in
  buttons) buttons ;;
  code) code ;;
  version) versioncheck ;;
  http) httpcheck ;;
  runtime) runtime ;;
  full) full ;;
  *) echo "Usage: kzsc-audit {buttons|code|version|http|runtime|full}"; exit 1;;
esac

if [ "$fail" -eq 0 ]; then
  echo "=== AUDIT RESULT: OK ==="
  exit 0
fi
echo "=== AUDIT RESULT: FAIL ==="
exit 1
