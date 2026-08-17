#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh
fail=0
ok(){ echo "OK   $*"; }; bad(){ echo "FAIL $*"; fail=1; }
ce(){ [ -x "$1" ] && ok "$2" || bad "$2"; }
WWW="$KZSC_HOME/www"; CGI="$WWW/cgi-bin"
echo "=== KZSC UI Self-Test ==="
ce "$CGI/zapret2_install.cgi" "Zapret2 Kur"
ce "$CGI/zapret2_update.cgi" "Zapret2 Güncelle"
ce "$CGI/zapret2_repair.cgi" "Zapret2 Onar"
ce "$CGI/zapret2_remove.cgi" "Zapret2 Kaldır"
ce "$CGI/settings.cgi" "Ayarları Kaydet"
grep -Fq 'unset LD_LIBRARY_PATH' "$CGI/settings.cgi" && grep -Fq 'body="${QUERY_STRING:-}"' "$CGI/settings.cgi" && ok "Settings CGI Keenetic POST/env fix" || bad "Settings CGI Keenetic POST/env fix"
grep -Fq "settings.cgi?'+body.toString()" "$WWW/index.html" && ok "Settings frontend query mirror" || bad "Settings frontend query mirror"
ce "$CGI/operation_log_clear.cgi" "Olay Günlüğü Temizle"
ce "$CGI/dns_status.cgi" "DNS Durum"
ce "$CGI/dns_diag.cgi" "DNS CGI Tanı"
ce "$CGI/dns_disable.cgi" "DNS Devre Dışı"
ce /opt/kzsc/bin/kzsc-dns.sh "DNS backend"
grep -Fq "printf '%s\\n' \"\$out\"" /opt/kzsc/bin/kzsc-dns.sh && ok "DNS NDMC çıktı passthrough" || bad "DNS NDMC çıktı passthrough"
grep -q "configured_secure_dns_commands" /opt/kzsc/bin/kzsc-dns.sh && grep -q '^  running_config |' /opt/kzsc/bin/kzsc-dns.sh && ok "DNS secure discovery running-config" || bad "DNS secure discovery running-config"
grep -q 'audit) audit' /opt/kzsc/bin/kzsc-dns.sh && ok "DNS audit" || bad "DNS audit"
/opt/kzsc/bin/kzsc-presets-cgi.sh >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-engine-cgi.sh >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-blockcheck-cgi.sh >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-dns-cgi.sh >/dev/null 2>&1 || true
n=0
for nd in $(internet_wans); do
 n=$((n+1)); id="$(printf '%s' "$nd"|tr ' A-Z/:.' '_a-z___'|tr -cd 'a-z0-9_-')"
 ce "$CGI/engine_enable_${id}.cgi" "$nd Motoru Başlat"
 ce "$CGI/engine_disable_${id}.cgi" "$nd Motoru Durdur"
 ce "$CGI/blockcheck_start_${id}.cgi" "$nd Blockcheck Başlat"
 ce "$CGI/blockcheck_stop_${id}.cgi" "$nd Blockcheck Durdur"
 for q in tt sol kablonet; do ce "$CGI/profile_set_${id}_${q}.cgi" "$nd Profil $q"; done
done
[ "$n" -gt 0 ] && ok "WAN keşfi: $n" || bad "WAN keşfi"
for p in cloudflare google quad9 adguard; do
 for proto in dot doh; do
  for mode in keep ignore; do
   ce "$CGI/dns_apply_${p}_${proto}_${mode}.cgi" "DNS ${p} ${proto} ${mode}"
   ce "$CGI/dns_clean_${p}_${proto}_${mode}.cgi" "DNS CLEAN ${p} ${proto} ${mode}"
  done
 done
done
ce /opt/kzsc/bin/kzsc-telegram.sh "Telegram backend"
ce "$CGI/telegram_status.cgi" "Telegram Durum"
ce "$CGI/telegram_save.cgi" "Telegram Kaydet"
ce "$CGI/telegram_test.cgi" "Telegram Test"
ce "$CGI/telegram_find_chat.cgi" "Telegram Chat ID"
ce /opt/kzsc/bin/kzsc-oplog.sh "Olay Günlüğü"
ce /opt/kzsc/bin/kzsc-purity.sh "KZSC bağımsızlık denetimi"
/opt/kzsc/bin/kzsc-purity.sh check >/dev/null 2>&1 && ok "KZSC-owned tree bağımsız/temiz" || bad "KZSC-owned tree kalıntı içeriyor"
/opt/kzsc/bin/kzsc-oplog.sh selfcheck >/dev/null 2>&1 && ok "Olay Günlüğü depolama/yayın" || bad "Olay Günlüğü depolama/yayın"
[ -d "$KZSC_HOME/www/data/maintenance-results" ] && ok "Result dizini" || bad "Result dizini"
[ -d "$KZSC_HOME/www/data/maintenance-progress" ] && ok "Progress dizini" || bad "Progress dizini"
grep -q 'install_release "$current_tag"' /opt/kzsc/bin/kzsc-zapret2.sh && ok "Zapret2 Onar" || bad "Zapret2 Onar"
grep -q 'zapret2_ready_postcondition' /opt/kzsc/bin/kzsc-maintenance.sh && ok "Zapret2 durum doğrulaması" || bad "Zapret2 durum doğrulaması"
grep -q 'curl -fsSL' /opt/kzsc/bin/kzsc-zapret2.sh && ok "Zapret2 indirme" || bad "Zapret2 indirme"
for x in z2ActionBtn presetApplyBtn engineStartBtn engineStopBtn bcStartBtn bcStopBtn dnsApplyBtn dnsDisableBtn dnsCleanInstall settingsForm clearOperationLogBtn; do
 grep -q "$x" "$WWW/index.html" && ok "JS $x" || bad "JS $x"
done
grep -q 'id="langBtn"' "$WWW/index.html" && ok "Dil seçici" || bad "Dil seçici"
grep -q 'KZSC_FLAG_TR' "$WWW/index.html" && ok "Türkçe SVG bayrak" || bad "Türkçe SVG bayrak"
grep -q 'KZSC_FLAG_GB' "$WWW/index.html" && ok "English SVG bayrak" || bad "English SVG bayrak"
grep -q "localStorage.getItem('kzsc.lang')" "$WWW/index.html" && ok "Dil tercihi kalıcı" || bad "Dil tercihi"
grep -q 'function setKzscLanguage' "$WWW/index.html" && ok "TR/EN dil motoru" || bad "TR/EN dil motoru"
grep -q 'WAN DPI Engines' "$WWW/index.html" && ok "English DPI çevirileri" || bad "English DPI çevirileri"
grep -q 'KZSC Zapret2 Management' "$WWW/index.html" && ok "English Zapret2 çevirileri" || bad "English Zapret2 çevirileri"
grep -q 'WAN Comparison — Last 1 Hour' "$WWW/index.html" && ok "English WAN çevirileri" || bad "English WAN çevirileri"
grep -q 'History capacity (rows)' "$WWW/index.html" && ok "English Settings çevirileri" || bad "English Settings çevirileri"
grep -q 'Secure DNS' "$WWW/index.html" && ok "English DNS çevirileri" || bad "English DNS çevirileri"
grep -q 'clean_apply()' /opt/kzsc/bin/kzsc-dns.sh && ok "DNS temiz kurulum backend" || bad "DNS temiz kurulum backend"
grep -q 'save_state(){' /opt/kzsc/bin/kzsc-dns.sh && ok "DNS state save" || bad "DNS state save"
grep -q 'load_state(){' /opt/kzsc/bin/kzsc-dns.sh && ok "DNS state load" || bad "DNS state load"
grep -q 'add_selected_dns(){' /opt/kzsc/bin/kzsc-dns.sh && ok "DNS provider backend" || bad "DNS provider backend"
if grep -A3 'add_selected_dns(){' /opt/kzsc/bin/kzsc-dns.sh | grep -q 'add_selected_dns "\$provider"'; then bad "DNS recursive provider bug"; else ok "DNS recursive provider bug yok"; fi
grep -q 'backup_configured_dns()' /opt/kzsc/bin/kzsc-dns.sh && ok "DNS temiz kurulum snapshot" || bad "DNS temiz kurulum snapshot"
grep -q 'PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin' /opt/kzsc/bin/kzsc-dns.sh && ok "DNS CGI PATH sabit" || bad "DNS CGI PATH"
grep -q 'NDMC_BIN' /opt/kzsc/bin/kzsc-dns.sh && ok "DNS ndmc mutlak yol" || bad "DNS ndmc mutlak yol"
grep -q 'id="notificationsPanel"' "$WWW/index.html" && ok "Bildirimler sekmesi" || bad "Bildirimler sekmesi"
grep -q 'id="tgSaveBtn"' "$WWW/index.html" && ok "JS Telegram Kaydet" || bad "JS Telegram Kaydet"
grep -q 'tgFormDirty' "$WWW/index.html" && grep -q 'loadTelegram(forceForm=false)' "$WWW/index.html" && ok "Telegram form taslagi korunuyor" || bad "Telegram form taslagi korunuyor"
grep -q "data/telegram-status.json?ts=" "$WWW/index.html" && ok "Telegram durum cache-bypass" || bad "Telegram durum cache-bypass"
grep -q 'notify-event' /opt/kzsc/bin/kzsc-oplog.sh && ok "Telegram Olay hook" || bad "Telegram Olay hook"
grep -q 'notify-wan' /opt/kzsc/bin/kzsc-wan.sh && ok "Telegram WAN hook" || bad "Telegram WAN hook"
grep -q 'append-local wan_state_change' /opt/kzsc/bin/kzsc-telegram.sh && ok "WAN olayı Olay Günlüğü" || bad "WAN olayı Olay Günlüğü"
grep -q 'append-local system_event' /opt/kzsc/bin/kzsc-telegram.sh && ok "KZSC sistem olayı Olay Günlüğü" || bad "KZSC sistem olayı Olay Günlüğü"

grep -q 'data-tab="notificationsPanel">Telegram Bot</button>' "$WWW/index.html" && ok "Telegram Bot sekme adı" || bad "Telegram Bot sekme adı"
grep -q 'append-local telegram_delivery' /opt/kzsc/bin/kzsc-telegram.sh && grep -q 'append-local)' /opt/kzsc/bin/kzsc-oplog.sh && ok "Telegram gönderimleri Olay Günlüğü" || bad "Telegram gönderimleri Olay Günlüğü"
ce /opt/kzsc/bin/kzsc-backup.sh "Yedekleme backend"
ce "$CGI/backup_create.cgi" "Yedek Al"
ce "$CGI/backup_telegram.cgi" "Yedeği Telegrama Gönder"
ce "$CGI/backup_restore.cgi" "Yedekten Geri Yükle"
ce "$CGI/backup_status.cgi" "Yedek Durum"
grep -q 'id="backupCreateBtn"' "$WWW/index.html" && ok "JS Yedek Al" || bad "JS Yedek Al"
grep -q 'id="backupDownloadBtn"' "$WWW/index.html" && ok "JS Yedek İndir" || bad "JS Yedek İndir"
grep -q 'id="backupRestoreBtn"' "$WWW/index.html" && ok "JS Yedek Geri Yükle" || bad "JS Yedek Geri Yükle"
grep -q 'send-file' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram dosya gönderimi" || bad "Telegram dosya gönderimi"
# v0.10.0.2: DNS tab must be immediately before Zapret2 and DNS mutations must enter Event Log.
if awk '/data-tab="dnsPanel"/{d=NR} /data-tab="zapret2Panel"/{z=NR} END{exit !(d && z && d<z)}' "$KZSC_HOME/www/index.html"; then
  ok "DNS sekmesi Zapret2 solunda"
else
  bad "DNS sekmesi Zapret2 solunda"
fi
if grep -F 'run_dns_mutation dns_apply' "$KZSC_HOME/bin/kzsc-dns.sh" >/dev/null 2>&1 \
  && grep -F 'run_dns_mutation dns_clean_apply' "$KZSC_HOME/bin/kzsc-dns.sh" >/dev/null 2>&1 \
  && grep -F 'run_dns_mutation dns_disable' "$KZSC_HOME/bin/kzsc-dns.sh" >/dev/null 2>&1 \
  && grep -F 'kzsc-oplog.sh append' "$KZSC_HOME/bin/kzsc-dns.sh" >/dev/null 2>&1; then
  ok "DNS işlemleri Olay Günlüğü"
else
  bad "DNS işlemleri Olay Günlüğü"
fi
grep -q "eski/bozuk NDJSON satırını atla" /opt/kzsc/www/index.html && ok "Olay Günlüğü bozuk satır toleransı" || bad "Olay Günlüğü bozuk satır toleransı"
grep -q "sanitize_log" /opt/kzsc/bin/kzsc-oplog.sh && ok "Olay Günlüğü sanitize" || bad "Olay Günlüğü sanitize"
grep -q "Telegram Mesaj Gönderimi" /opt/kzsc/www/index.html && ok "Telegram Olay Günlüğü etiketleri" || bad "Telegram Olay Günlüğü etiketleri"
ce "$CGI/backup_download.cgi" "Yedek İndir"
ce "$CGI/backup_delete.cgi" "Yedek Sil"
grep -q 'process_backup_inbox' /opt/kzsc/bin/kzsc-maintenance.sh && ok "Yedek istek kuyruğu işleniyor" || bad "Yedek istek kuyruğu işleniyor"
grep -q 'backup_create)' /opt/kzsc/bin/kzsc-maintenance.sh && grep -q 'backup_restore)' /opt/kzsc/bin/kzsc-maintenance.sh && grep -Fq 'backup_telegram:*)' /opt/kzsc/bin/kzsc-maintenance.sh && ok "Yedek işlemleri maintenance backend" || bad "Yedek işlemleri maintenance backend"
grep -q 'backup_download' /opt/kzsc/bin/kzsc-maintenance.sh && ok "Yedek indirme Olay Günlüğü" || bad "Yedek indirme Olay Günlüğü"
grep -q 'backup_delete' /opt/kzsc/bin/kzsc-maintenance.sh && ok "Yedek silme Olay Günlüğü" || bad "Yedek silme Olay Günlüğü"
grep -q 'id="backupDeleteBtn"' "$WWW/index.html" && ok "JS Yedek Sil" || bad "JS Yedek Sil"
grep -q 'iface_config_description' /opt/kzsc/bin/kzsc-dns.sh && ok "DNS WAN bağlantı adı running-config" || bad "DNS WAN bağlantı adı running-config"
grep -q 'kzsc-backup-\*.tar.gz' "$CGI/backup_status.cgi" && ok "Yedek durum dinamik keşif" || bad "Yedek durum dinamik keşif"
grep -q '^resolve_restore_file(){' /opt/kzsc/bin/kzsc-backup.sh && grep -Fq '"$BDIR/$f"' /opt/kzsc/bin/kzsc-backup.sh && ok "Yedek restore dosya adı çözümleme" || bad "Yedek restore dosya adı çözümleme"
grep -q 'dispatch_queue' /opt/kzsc/bin/kzsc-blockcheck.sh && grep -q 'upstream_blockcheck_rules_active' /opt/kzsc/bin/kzsc-blockcheck.sh && ok "Blockcheck seri WAN kuyruğu" || bad "Blockcheck seri WAN kuyruğu"
grep -q 'auto_apply_result' /opt/kzsc/bin/kzsc-blockcheck.sh && grep -q 'auto_\*)' /opt/kzsc/bin/kzsc-native-dpi.sh && ok "Blockcheck otomatik profil uygulama" || bad "Blockcheck otomatik profil uygulama"
grep -q '^KZSC_BLOCKCHECK_NIGHTLY="0"' /opt/kzsc/etc/kzsc.conf && grep -q 'schedule_tick' /opt/kzsc/bin/kzsc-blockcheck.sh && ok "Blockcheck gece otomatik tarama kapalı" || bad "Blockcheck gece otomatik tarama kapalı"
[ -x /opt/kzsc/bin/kzsc-keendns.sh ] && ok "KeenDNS backend" || bad "KeenDNS backend"
grep -q 'keendnsEnableBtn' /opt/kzsc/www/index.html && ok "KeenDNS Ayarlar UI" || bad "KeenDNS Ayarlar UI"
grep -q 'completed_tests' /opt/kzsc/bin/kzsc-blockcheck.sh && ok "Blockcheck test ilerleme sayacı" || bad "Blockcheck test ilerleme sayacı"
grep -q 'KZSC_BLOCKCHECK_MAX_SECONDS="1800"' /opt/kzsc/etc/kzsc.conf && grep -q 'worker_rc=124' /opt/kzsc/bin/kzsc-blockcheck.sh && ok "Blockcheck 30 dakika hard timeout" || bad "Blockcheck 30 dakika hard timeout"
! grep -q 'class="bcModeSelect"' /opt/kzsc/www/index.html && ok "Blockcheck tek test modu" || bad "Blockcheck tek test modu"
grep -q 'closest valid position' /opt/kzsc/bin/kzsc-isolation.sh && ok "NFQUEUE idempotent restore" || bad "NFQUEUE idempotent restore"
grep -Fq 'id="auto_$(safe_id "$nd")"' /opt/kzsc/bin/kzsc-blockcheck.sh && ok "AUTO profil sabit isim/üzerine yazma" || bad "AUTO profil sabit isim/üzerine yazma"
grep -q 'resolve_wan_name' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram bağlantı adı dinamik çözümleme" || bad "Telegram bağlantı adı dinamik çözümleme"
grep -q 'Kullanım: /dpi_start BAĞLANTI_ADI' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram PPPoE yerine bağlantı adı" || bad "Telegram PPPoE yerine bağlantı adı"
grep -q "queued?'—':fmtElapsed(j.elapsed)" /opt/kzsc/www/index.html && ok "Sıradaki Blockcheck süre sayacı pasif" || bad "Sıradaki Blockcheck süre sayacı pasif"

grep -q 'preset_first_probe' /opt/kzsc/bin/kzsc-blockcheck.sh && grep -q 'KZSC PRESET-FIRST' /opt/kzsc/bin/kzsc-blockcheck.sh && ok "Blockcheck preset-first öncelik" || bad "Blockcheck preset-first öncelik"
grep -q 'Broad Blockcheck scan skipped' /opt/kzsc/bin/kzsc-blockcheck.sh && grep -q 'preset_verified' /opt/kzsc/bin/kzsc-blockcheck.sh && ok "Blockcheck preset yeterliyse erken bitiş" || bad "Blockcheck preset yeterliyse erken bitiş"
grep -q 'cleanup_job_children' /opt/kzsc/bin/kzsc-blockcheck.sh && grep -q 'cleanup_temp_chains' /opt/kzsc/bin/kzsc-blockcheck.sh && ok "Blockcheck stop/timeout process-tree temizliği" || bad "Blockcheck stop/timeout process-tree temizliği"
grep -q 'datapath_ok' /opt/kzsc/bin/kzsc-native-dpi.sh && grep -q 'recover-all' /opt/kzsc/bin/kzsc-native-dpi.sh && ok "Native DPI runtime datapath reconcile" || bad "Native DPI runtime datapath reconcile"
grep -q '^poll_commands(){' /opt/kzsc/bin/kzsc-telegram.sh && grep -q 'getUpdates' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram command listener" || bad "Telegram command listener"
grep -q 'TG_LAST_UPDATE_ID' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram update offset" || bad "Telegram update offset"

# Telegram mutable runtime state must be separate from user configuration.
grep -Fq 'STATE="$KZSC_HOME/var/lib/telegram-state.conf"' /opt/kzsc/bin/kzsc-telegram.sh &&
grep -q '^is_state_key(){' /opt/kzsc/bin/kzsc-telegram.sh &&
ok "Telegram runtime state ayrı dosya" ||
bad "Telegram runtime state ayrı dosya"

! grep -q '^TG_LAST_' /opt/kzsc/etc/telegram.conf 2>/dev/null &&
ok "Telegram config TG_LAST_* içermiyor" ||
bad "Telegram config TG_LAST_* içeriyor"

tg_state="/opt/kzsc/var/lib/telegram-state.conf"
tg_state_missing=0

for k in TG_LAST_UPDATE_ID TG_LAST_SENT TG_LAST_ERROR
do
  grep -q "^${k}=" "$tg_state" 2>/dev/null || tg_state_missing=1
done

[ "$tg_state_missing" -eq 0 ] &&
ok "Telegram state üç gerekli key içeriyor" ||
bad "Telegram state gerekli key eksik"

tg_state_extra="$(
  sed -n 's/^\([A-Za-z0-9_][A-Za-z0-9_]*\)=.*/\1/p' "$tg_state" 2>/dev/null |
  grep -Ev '^(TG_LAST_UPDATE_ID|TG_LAST_SENT|TG_LAST_ERROR)$'
)"

[ -z "$tg_state_extra" ] &&
ok "Telegram state yalnız izinli keyleri içeriyor" ||
bad "Telegram state izin verilmeyen key içeriyor"

grep -Fq '^TG_LAST_UPDATE_ID=|^TG_LAST_SENT=|^TG_LAST_ERROR=' \
  /opt/kzsc/bin/kzsc-backup.sh &&
ok "Telegram backup runtime state dışlıyor" ||
bad "Telegram backup runtime state filtresi"

grep -Fq '!/^TG_LAST_UPDATE_ID=/ && !/^TG_LAST_SENT=/ && !/^TG_LAST_ERROR=/' \
  /opt/kzsc/bin/kzsc-backup.sh &&
ok "Telegram legacy restore sanitize" ||
bad "Telegram legacy restore sanitize"
grep -q "ndmc -c 'show ndns'" /opt/kzsc/bin/kzsc-keendns.sh && grep -q 'booked:' /opt/kzsc/bin/kzsc-keendns.sh && ok "KeenDNS show ndns discovery" || bad "KeenDNS show ndns discovery"
grep -q 'upstream http \$lan \$p' /opt/kzsc/bin/kzsc-keendns.sh && grep -q "ip http proxy kzsc allow public" /opt/kzsc/bin/kzsc-keendns.sh && ok "KeenDNS Titan proxy commands" || bad "KeenDNS Titan proxy commands"
grep -Fq 'proxy_port(){' /opt/kzsc/bin/kzsc-keendns.sh && grep -Fq '[ "$actual" != "$want" ]' /opt/kzsc/bin/kzsc-keendns.sh && grep -Fq 'audit) audit;;' /opt/kzsc/bin/kzsc-keendns.sh && ok "KeenDNS port sync/audit" || bad "KeenDNS port sync/audit"
grep -q 'send_markup(){' /opt/kzsc/bin/kzsc-telegram.sh && grep -q 'callback_query' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram inline yönetim butonları" || bad "Telegram inline yönetim butonları"
grep -q 'z_inst=' /opt/kzsc/bin/kzsc-telegram.sh && grep -q 'dns_state=' /opt/kzsc/bin/kzsc-telegram.sh && grep -q 'kd_state=' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram temiz durum özeti" || bad "Telegram temiz durum özeti"
! grep -q 'KZSC WAN · \$label (\$ndmc)' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram WAN teknik ID gizli" || bad "Telegram WAN teknik ID gizli"

grep -q "btn='⏹ Durdur'" /opt/kzsc/bin/kzsc-telegram.sh && grep -q "btn='▶️ Başlat'" /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram kısa aksiyon butonları" || bad "Telegram kısa aksiyon butonları"
grep -q "preset_verified) echo 'Preset doğrulandı'" /opt/kzsc/bin/kzsc-telegram.sh && grep -q "success) echo 'Başarılı'" /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram Blockcheck Türkçe durumları" || bad "Telegram Blockcheck Türkçe durumları"
grep -q '^valid_wan(){' /opt/kzsc/bin/kzsc-telegram.sh && grep -q 'for w in $(internet_wans' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram callback WAN doğrulaması" || bad "Telegram callback WAN doğrulaması"
grep -q 'cbchat=' /opt/kzsc/bin/kzsc-telegram.sh && grep -q 'callback update=.*chat=' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram callback chat-id yetkilendirme/log" || bad "Telegram callback chat-id yetkilendirme/log"

ce /opt/kzsc/bin/kzsc-reconcile.sh "WAN topology reconcile backend"
grep -q 'kzsc-reconcile.sh tick' /opt/kzsc/bin/kzsc-daemon.sh && ok "Daemon WAN değişiklik reconcile" || bad "Daemon WAN değişiklik reconcile"
grep -q 'ip -4 -o addr show' /opt/kzsc/bin/kzsc-lib.sh && grep -q '^internet_wan_kind(){' /opt/kzsc/bin/kzsc-lib.sh && grep -q 'WifiStation' /opt/kzsc/bin/kzsc-lib.sh && ok "PPPoE/IPoE/WISP canlı Linux eşleme" || bad "PPPoE/IPoE/WISP canlı Linux eşleme"
grep -q 'deadline=$((worker_started+MAX_SECONDS))' /opt/kzsc/bin/kzsc-blockcheck.sh && ! grep -Fq 'deadline=$(( $(date +%s) + MAX_SECONDS ))' /opt/kzsc/bin/kzsc-blockcheck.sh && ok "Blockcheck mutlak işçi süresi sınırı" || bad "Blockcheck mutlak işçi süresi sınırı"
grep -q 'iface_config_description' /opt/kzsc/bin/kzsc-lib.sh && grep -q 'Manual map is retained only as a fallback' /opt/kzsc/bin/kzsc-lib.sh && ok "WAN canlı bağlantı adı önceliği" || bad "WAN canlı bağlantı adı önceliği"
grep -q 'auto-start)' /opt/kzsc/bin/kzsc-blockcheck.sh && grep -q 'wan_reconcile' /opt/kzsc/bin/kzsc-blockcheck.sh && ok "Yeni WAN otomatik Blockcheck" || bad "Yeni WAN otomatik Blockcheck"
grep -q 'purge-binding)' /opt/kzsc/bin/kzsc-native-dpi.sh && grep -q '^purge_binding(){' /opt/kzsc/bin/kzsc-native-dpi.sh && ok "Eski WAN DPI binding temizliği" || bad "Eski WAN DPI binding temizliği"
grep -q '^KZSC_WAN_AUTO_VALIDATE="1"' /opt/kzsc/etc/kzsc.conf && grep -q '^KZSC_WAN_AUTO_ENABLE_NEW="1"' /opt/kzsc/etc/kzsc.conf && ok "WAN otomatik DPI doğrulama varsayılanı" || bad "WAN otomatik DPI doğrulama varsayılanı"
grep -q '^preset_first_probe(){' /opt/kzsc/bin/kzsc-blockcheck.sh && grep -q 'force_enable="${5:-0}"' /opt/kzsc/bin/kzsc-blockcheck.sh && grep -q '^auto_apply_result(){' /opt/kzsc/bin/kzsc-blockcheck.sh && grep -q 'force_enable="${3:-0}"' /opt/kzsc/bin/kzsc-blockcheck.sh && ok "Otomatik doğrulama sonrası DPI motor devamı" || bad "Otomatik doğrulama sonrası DPI motor devamı"
grep -q 'No preset was sufficient; continuing with broad Blockcheck scan' /opt/kzsc/bin/kzsc-blockcheck.sh && grep -q 'build_auto_profile' /opt/kzsc/bin/kzsc-blockcheck.sh && ok "Preset başarısızsa broad Blockcheck + AUTO profil" || bad "Preset başarısızsa broad Blockcheck + AUTO profil"

grep -q 'LAST_CHANGE=' /opt/kzsc/bin/kzsc-reconcile.sh && grep -q 'LAST_VALIDATION=' /opt/kzsc/bin/kzsc-reconcile.sh && grep -q '"last_change"' /opt/kzsc/bin/kzsc-reconcile.sh && ok "Reconcile görünürlük geçmişi" || bad "Reconcile görünürlük geçmişi"
grep -q 'data/reconcile.json?' /opt/kzsc/www/index.html && grep -q 'kzsc-reconcile.sh tick' /opt/kzsc/bin/kzsc-daemon.sh && ! grep -Fq ')+reconcileCard()+core;' /opt/kzsc/www/index.html && ok "Genel Bakış WAN Reconcile kartı gizli / backend aktif" || bad "Genel Bakış WAN Reconcile kartı gizli / backend aktif"
grep -q "WAN Profili Doğrulandı" /opt/kzsc/bin/kzsc-telegram.sh && grep -q "WAN Değişikliği Algılandı" /opt/kzsc/bin/kzsc-telegram.sh && grep -q 'wan_reconcile)' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram WAN reconcile bildirimleri" || bad "Telegram WAN reconcile bildirimleri"
grep -q '"Teknik Profil":"Technical Profile"' /opt/kzsc/www/index.html && grep -q '"Son Blockcheck":"Last Blockcheck"' /opt/kzsc/www/index.html && grep -q '"KeenDNS Uzaktan Erişim":"KeenDNS Remote Access"' /opt/kzsc/www/index.html && grep -q '"Dosyadan Geri Yükle":"Restore from File"' /opt/kzsc/www/index.html && ok "TR/EN final translation audit" || bad "TR/EN final translation audit"
grep -q 'function refreshGlobalNotices()' /opt/kzsc/www/index.html && grep -q 'data-kzsc-notice-raw' /opt/kzsc/www/index.html && grep -q "setNoticeText(titleEl" /opt/kzsc/www/index.html && ok "English global operation notices" || bad "English global operation notices"
grep -q "noticeTranslatedText(x.message" /opt/kzsc/www/index.html && grep -q "localeDate(x.timestamp)" /opt/kzsc/www/index.html && ok "Event Log bilingual messages/date" || bad "Event Log bilingual messages/date"
grep -Fq 'const marker=(core.match' /opt/kzsc/www/index.html && grep -Fq 'if(d)setNoticeText(d,text)' /opt/kzsc/www/index.html && ok "Simgeli/dinamik global bildirimler TR/EN" || bad "Simgeli/dinamik global bildirimler TR/EN"
grep -Fq 'tg_text="$(printf' /opt/kzsc/bin/kzsc-telegram.sh && ! grep -Fq 'send "$icon KZSC · $title\n$msg"' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram bildirim gerçek satır sonu" || bad "Telegram bildirim gerçek satır sonu"
grep -Fq 'n_old_label="$(isp_label "$n_old")"' /opt/kzsc/bin/kzsc-telegram.sh && grep -Fq 'n_new_label="$(isp_label "$n_new")"' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram reconcile kullanıcı dostu WAN adı" || bad "Telegram reconcile kullanıcı dostu WAN adı"
grep -q 'WAN/default-route changes can briefly make DNS unavailable' /opt/kzsc/bin/kzsc-telegram.sh && grep -q 'sleep 3' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram WAN geçişi ağ retry" || bad "Telegram WAN geçişi ağ retry"
grep -q 'async function copyTextCompat' /opt/kzsc/www/index.html && grep -Fq "document.execCommand('copy')" /opt/kzsc/www/index.html && grep -q 'window.isSecureContext' /opt/kzsc/www/index.html && ok "KeenDNS Copy Address HTTP fallback" || bad "KeenDNS Copy Address HTTP fallback"
grep -q '"Adres kopyalanamadı\.":"Address could not be copied\."' /opt/kzsc/www/index.html && grep -q '"Kopyalanacak adres bulunamadı\.":"No address is available to copy\."' /opt/kzsc/www/index.html && ok "KeenDNS clipboard TR/EN notices" || bad "KeenDNS clipboard TR/EN notices"
ce "$CGI/ui_event.cgi" "KeenDNS UI olay audit endpoint"
grep -Fq "logUiEvent('keendns_copy'" /opt/kzsc/www/index.html && grep -Fq "logUiEvent('keendns_open'" /opt/kzsc/www/index.html && grep -Fq 'waitMaintenanceResult(queued.request_id,45000)' /opt/kzsc/www/index.html && grep -Fq 'ui_event:*)' /opt/kzsc/bin/kzsc-maintenance.sh && ok "KeenDNS Copy/Open doğrulanan Olay Günlüğü hook" || bad "KeenDNS Copy/Open Olay Günlüğü hook"
grep -Fq '|operation_log_clear' "$CGI/operation_log_clear.cgi" && grep -Fq 'append operation_log_clear true' /opt/kzsc/bin/kzsc-maintenance.sh && ok "Olay Günlüğü temizleme daemon kuyruğu/kaydı" || bad "Olay Günlüğü temizleme daemon kuyruğu/kaydı"
grep -Fq 'kzsc_lock_acquire oplog' /opt/kzsc/bin/kzsc-oplog.sh && grep -Fq 'publish_unlocked' /opt/kzsc/bin/kzsc-oplog.sh && ok "Olay Günlüğü atomik yazım kilidi" || bad "Olay Günlüğü atomik yazım kilidi"
grep -Fq 'safe_backup_name(){' /opt/kzsc/bin/kzsc-backup.sh && grep -Fq 'validate_extracted(){' /opt/kzsc/bin/kzsc-backup.sh && grep -Fq 'MAX_BACKUP_BYTES=5242880' /opt/kzsc/bin/kzsc-backup.sh && grep -Fq 'backup_too_large' "$CGI/backup_restore.cgi" && ok "Yedek güvenlik doğrulaması" || bad "Yedek güvenlik doğrulaması"
! grep -Fq 'kzsc-oplog.sh append' /opt/kzsc/bin/kzsc-dns-cgi.sh && grep -Fq 'run_dns_mutation dns_apply' /opt/kzsc/bin/kzsc-dns.sh && ok "DNS olayı tek backend kaydı" || bad "DNS mükerrer olay kaydı"
grep -Fq 'auto_*)' /opt/kzsc/bin/kzsc-maintenance.sh && grep -Fq 'Geçersiz veya bu WAN' /opt/kzsc/bin/kzsc-maintenance.sh && ok "AUTO profil maintenance doğrulaması" || bad "AUTO profil maintenance doğrulaması"
ce /opt/kzsc/bin/kzsc-audit.sh "KZSC kapsamlı audit backend"
grep -q 'check-all)' /opt/kzsc/bin/kzsc-native-dpi.sh && grep -q '^check_all(){' /opt/kzsc/bin/kzsc-native-dpi.sh && ok "Native DPI read-only check-all" || bad "Native DPI read-only check-all"
grep -q '^source_retired_scan(){' /opt/kzsc/bin/kzsc-purity.sh && grep -q 'retired-product identifier/path' /opt/kzsc/bin/kzsc-purity.sh && ok "Standalone source retired-product taraması" || bad "Standalone source retired-product taraması"
grep -Fq "document.querySelectorAll('.z2ActionBtn').forEach(b=>b.disabled=true)" /opt/kzsc/www/index.html && ! grep -Fq "document.querySelectorAll('.actionBtn').forEach(b=>b.disabled=true)" /opt/kzsc/www/index.html && ok "Zapret2 busy state diğer butonları bozmuyor" || bad "Zapret2 busy state diğer butonları bozmuyor"
grep -q 'blockcheckNoticePrimed=false' /opt/kzsc/www/index.html && grep -q 'blockcheckNoticePrimed=true' /opt/kzsc/www/index.html && ok "Eski Blockcheck toast tekrarını önleme" || bad "Eski Blockcheck toast tekrarını önleme"
grep -Fq "return t('Genişletici')" /opt/kzsc/www/index.html && grep -q '"Genişletici":"Extender"' /opt/kzsc/www/index.html && ok "Cihaz rolü TR/EN Genişletici" || bad "Cihaz rolü TR/EN Genişletici"
grep -q 'audit)' /opt/kzsc/bin/kzsc && grep -q 'kzsc-audit.sh' /opt/kzsc/bin/kzsc && ok "CLI kzsc audit" || bad "CLI kzsc audit"
grep -Fq 'kzsc_lock_acquire "$LOCK_NAME"' /opt/kzsc/bin/kzsc-blockcheck-cgi.sh \
 && grep -Fq 'mv -f "$tmp" "$path"' /opt/kzsc/bin/kzsc-blockcheck-cgi.sh \
 && grep -Fq 'Remove only endpoints' /opt/kzsc/bin/kzsc-blockcheck-cgi.sh \
 && ! grep -Fq 'rm -f "$CGI"/blockcheck_start_*.cgi "$CGI"/blockcheck_stop_*.cgi' /opt/kzsc/bin/kzsc-blockcheck-cgi.sh \
 && ok "Blockcheck CGI atomik yenileme/stale temizliği" || bad "Blockcheck CGI atomik yenileme/stale temizliği"
grep -Fq 'zapret2-status.json' /opt/kzsc/bin/kzsc-zapret2.sh && grep -Fq 'zapret2-status.json?' /opt/kzsc/www/index.html && ! grep -Fq 'zapret2-manager.json' /opt/kzsc/www/index.html && ok "KZSC-native Zapret2 status artifact" || bad "KZSC-native Zapret2 status artifact"
grep -Fq 'rm -f "$VALIDATED/$id.tsv"' /opt/kzsc/bin/kzsc-reconcile.sh && grep -Fq 'rm -rf "$KZSC_HOME/var/dpi/engines/$id" "$KZSC_HOME/var/blockcheck/$id"' /opt/kzsc/bin/kzsc-reconcile.sh && ok "Kaldırılan/değişen WAN runtime state temizliği" || bad "Kaldırılan/değişen WAN runtime state temizliği"

grep -Fq 'lighttpd.conf)' /opt/kzsc/bin/kzsc-audit.sh && ok "Audit lighttpd runtime config allow-list" || bad "Audit lighttpd runtime config allow-list"
grep -Fq 'blockcheck/_global' /opt/kzsc/bin/kzsc-audit.sh && grep -Fq 'blockcheck/queue' /opt/kzsc/bin/kzsc-audit.sh && grep -Fq 'blockcheck/scheduler' /opt/kzsc/bin/kzsc-audit.sh && ok "Audit Blockcheck ortak runtime dizinleri" || bad "Audit Blockcheck ortak runtime dizinleri"
grep -Fq 'perm_text=' /opt/kzsc/bin/kzsc-audit.sh && ok "Audit BusyBox Telegram permission" || bad "Audit BusyBox Telegram permission"
grep -Fq 'symlink target audit' /opt/kzsc/bin/kzsc-audit.sh && ok "Audit güvenli runtime symlink hedefleri" || bad "Audit güvenli runtime symlink hedefleri"
grep -Fq 'legacy_log="$ROOT/var/log/k""sc.log"' /opt/kzsc/bin/kzsc-purity.sh && ok "Retired log residue sanitizer" || bad "Retired log residue sanitizer"
grep -q 'data-tab="updatePanel">Güncelleme</button>' "$WWW/index.html" && grep -q 'id="kzscUpdateStatus"' "$WWW/index.html" && ok "KZSC Güncelleme sekmesi" || bad "KZSC Güncelleme sekmesi"
grep -q '"KZSC Güncellemeleri":"KZSC Updates"' "$WWW/index.html" && grep -q '"Güncellemeleri Kontrol Et":"Check for Updates"' "$WWW/index.html" && ok "KZSC Güncelleme TR/EN" || bad "KZSC Güncelleme TR/EN"
grep -q 'function notifyKzscUpdateTransition' "$WWW/index.html" && grep -q "showGlobalNotice('success'.*KZSC güncellemesi başarıyla kuruldu" "$WWW/index.html" && ok "KZSC Güncelleme üst bildirimleri" || bad "KZSC Güncelleme üst bildirimleri"
for x in check install auto_on auto_off; do ce "$CGI/kzsc_update_${x}.cgi" "KZSC Update CGI $x"; done
grep -q 'kzsc-updater.sh tick' /opt/kzsc/bin/kzsc-daemon.sh && grep -q 'KZSC_UPDATE_CHECK_INTERVAL="1800"' /opt/kzsc/etc/kzsc.conf.example && ok "30 dakika güncelleme kontrolü" || bad "30 dakika güncelleme kontrolü"
grep -q 'kzsc_update_available' /opt/kzsc/bin/kzsc-updater.sh && grep -q "kzsc_update_\*) cat=system; title='KZSC Güncelleme'" /opt/kzsc/bin/kzsc-telegram.sh && ok "KZSC Güncelleme Telegram senkronizasyonu" || bad "KZSC Güncelleme Telegram senkronizasyonu"
grep -q '/kzsc_update_check' /opt/kzsc/bin/kzsc-telegram.sh && grep -q 'ku_confirm:install' /opt/kzsc/bin/kzsc-telegram.sh && grep -q 'ku_install:yes' /opt/kzsc/bin/kzsc-telegram.sh && grep -q 'ku_auto)' /opt/kzsc/bin/kzsc-telegram.sh && ok "Telegram KZSC güncelleme yönetimi" || bad "Telegram KZSC güncelleme yönetimi"

[ "$fail" -eq 0 ] && { echo "=== SONUÇ: TÜM KZSC KONTROLLERİ OK ==="; exit 0; }
echo "=== SONUÇ: HATA ==="

exit 1
