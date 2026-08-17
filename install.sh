#!/bin/sh
set -eu
SRC="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
[ -x /opt/bin/sh ] || { echo "HATA: Entware/OPKG hazır değil."; exit 1; }

# Fail before stopping services or changing /opt.  BusyBox httpd/nginx are not
# accepted because the KZSC runtime is deliberately lighttpd + CGI only.
/opt/bin/sh "$SRC/opt/kzsc/bin/kzsc-preflight.sh" install

# Validate every shipped shell/CGI source before touching a working install.
for f in "$SRC/install.sh" "$SRC/opt/etc/init.d/S99kzsc" "$SRC"/opt/kzsc/bin/* "$SRC"/opt/kzsc/www/cgi-bin/*; do
  [ -f "$f" ] || continue
  first="$(head -n1 "$f" 2>/dev/null || true)"
  case "$first" in '#!'*sh*) /opt/bin/sh -n "$f" || { echo "HATA: Shell sözdizimi geçersiz: $f"; exit 1; } ;; esac
done

REMOVE_RETIRED=0
case "${1:-}" in
  '') ;;
  --remove-retired) REMOVE_RETIRED=1 ;;
  *) echo "Kullanım: sh install.sh [--remove-retired]"; exit 1 ;;
esac

# A separate retired manager or standalone Zapret2 tree can own the same
# firewall/process resources. Refuse the default install; removal requires the
# operator's explicit --remove-retired choice.
OLD_Z2_ROOT="/opt/zap""ret2"
retired_found=0
for x in "$OLD_Z2_ROOT" /opt/kzm* /opt/bin/kzm* /opt/etc/init.d/S??kzm*; do
  [ -e "$x" ] || continue
  echo "Eski ürün kalıntısı: $x"
  retired_found=1
done
if [ "$retired_found" -eq 1 ] && [ "$REMOVE_RETIRED" -ne 1 ]; then
  echo "HATA: Eski manager/Zapret2 kalıntıları bulundu. Bunları bilerek kaldırmak için kurulumu --remove-retired ile yeniden çalıştırın."
  exit 1
fi
if [ "$REMOVE_RETIRED" -eq 1 ]; then
  for init in /opt/etc/init.d/S??kzm*; do [ -x "$init" ] && "$init" stop >/dev/null 2>&1 || true; done
  for p in $(ps w 2>/dev/null | awk '/\/opt\/(kzm[^/]*|zapret2)\// && $0 !~ /awk/ {print $1}'); do kill "$p" 2>/dev/null || true; done
  sleep 1
  for p in $(ps w 2>/dev/null | awk '/\/opt\/(kzm[^/]*|zapret2)\// && $0 !~ /awk/ {print $1}'); do kill -9 "$p" 2>/dev/null || true; done
  for x in "$OLD_Z2_ROOT" /opt/kzm*; do [ -e "$x" ] && rm -rf "$x"; done
  for x in /opt/bin/kzm* /opt/etc/init.d/S??kzm*; do [ -e "$x" ] && rm -f "$x"; done
fi

# A failed upgrade must not strand a previously working KZSC installation.
# Back up only the code/config surfaces this installer replaces; mutable var/
# state and the large Zapret2 tree remain in place.
UPGRADE_BACKUP=""
ROLLBACK_ARMED=0
OLD_INIT_PRESENT=0
if [ -d /opt/kzsc ]; then
  UPGRADE_BACKUP="/opt/tmp/kzsc-upgrade-backup.$$"
  mkdir -p "$UPGRADE_BACKUP/kzsc/www" || exit 1
  chmod 700 "$UPGRADE_BACKUP" 2>/dev/null || true
  for d in bin etc share; do [ ! -e "/opt/kzsc/$d" ] || cp -R "/opt/kzsc/$d" "$UPGRADE_BACKUP/kzsc/"; done
  [ ! -f /opt/kzsc/www/index.html ] || cp /opt/kzsc/www/index.html "$UPGRADE_BACKUP/kzsc/www/"
  [ ! -d /opt/kzsc/www/cgi-bin ] || cp -R /opt/kzsc/www/cgi-bin "$UPGRADE_BACKUP/kzsc/www/"
  if [ -e /opt/etc/init.d/S99kzsc ]; then
    cp -R /opt/etc/init.d/S99kzsc "$UPGRADE_BACKUP/S99kzsc"
    OLD_INIT_PRESENT=1
  fi
  ROLLBACK_ARMED=1
fi

finish_install(){
  rc="$1"
  trap - EXIT INT TERM HUP
  rm -f /opt/kzsc/var/run/installing 2>/dev/null || true
  if [ "$rc" -ne 0 ] && [ "$ROLLBACK_ARMED" -eq 1 ] && [ -d "$UPGRADE_BACKUP/kzsc" ]; then
    echo "HATA: Yükseltme tamamlanamadı; önceki çalışan KZSC sürümü geri yükleniyor."
    [ -x /opt/etc/init.d/S99kzsc ] && /opt/etc/init.d/S99kzsc stop >/dev/null 2>&1 || true
    rm -rf /opt/kzsc/bin /opt/kzsc/etc /opt/kzsc/share /opt/kzsc/www/cgi-bin
    rm -f /opt/kzsc/www/index.html
    for d in bin etc share; do [ ! -e "$UPGRADE_BACKUP/kzsc/$d" ] || cp -R "$UPGRADE_BACKUP/kzsc/$d" /opt/kzsc/; done
    [ ! -f "$UPGRADE_BACKUP/kzsc/www/index.html" ] || cp "$UPGRADE_BACKUP/kzsc/www/index.html" /opt/kzsc/www/
    [ ! -d "$UPGRADE_BACKUP/kzsc/www/cgi-bin" ] || cp -R "$UPGRADE_BACKUP/kzsc/www/cgi-bin" /opt/kzsc/www/
    if [ "$OLD_INIT_PRESENT" -eq 1 ] && [ -e "$UPGRADE_BACKUP/S99kzsc" ]; then
      cp -R "$UPGRADE_BACKUP/S99kzsc" /opt/etc/init.d/S99kzsc
    else
      rm -f /opt/etc/init.d/S99kzsc
    fi
    ln -sf /opt/kzsc/bin/kzsc /opt/bin/kzsc
    [ -x /opt/etc/init.d/S99kzsc ] && /opt/etc/init.d/S99kzsc restart >/dev/null 2>&1 || true
    echo "Önceki KZSC sürümü geri yüklendi."
  fi
  [ -z "$UPGRADE_BACKUP" ] || rm -rf "$UPGRADE_BACKUP"
  exit "$rc"
}
trap 'finish_install $?' EXIT
trap 'exit 130' INT TERM HUP

# Standalone KZSC must not coexist with the retired product tree from old builds.
OLD_ROOT="/opt/k""sc"; OLD_BIN="/opt/bin/k""sc"; OLD_INIT="/opt/etc/init.d/S99k""sc"
[ -x "$OLD_INIT" ] && "$OLD_INIT" stop >/dev/null 2>&1 || true
rm -rf "$OLD_ROOT" 2>/dev/null || true
rm -f "$OLD_BIN" "$OLD_INIT" 2>/dev/null || true

if [ -x /opt/kzsc/bin/kzsc-blockcheck.sh ] && [ -f /opt/kzsc/bin/kzsc-lib.sh ]; then
  /opt/bin/sh -c '. /opt/kzsc/bin/kzsc-lib.sh; for w in $(internet_wans); do /opt/kzsc/bin/kzsc-blockcheck.sh stop "$w" >/dev/null 2>&1 || true; done' || true
  [ -x /opt/kzsc/bin/kzsc-isolation.sh ] && /opt/kzsc/bin/kzsc-isolation.sh recover-all >/dev/null 2>&1 || true
fi
[ -x /opt/etc/init.d/S99kzsc ] && /opt/etc/init.d/S99kzsc stop >/dev/null 2>&1 || true
PIDS="$(ps w 2>/dev/null | awk '/\/opt\/kzsc\/bin\/kzsc-daemon\.sh/ && $0 !~ /awk/ {print $1}')"
for x in $PIDS; do kill "$x" 2>/dev/null || true; done
sleep 1
PIDS="$(ps w 2>/dev/null | awk '/\/opt\/kzsc\/bin\/kzsc-daemon\.sh/ && $0 !~ /awk/ {print $1}')"
for x in $PIDS; do kill -9 "$x" 2>/dev/null || true; done
rm -f /opt/kzsc/var/run/daemon.pid 2>/dev/null || true
rm -rf /opt/kzsc/var/run/daemon.lock 2>/dev/null || true

# v0.11.1.4: clean orphaned upstream Blockcheck children left by older builds.
for p in $(ps w 2>/dev/null | awk '/\/opt\/kzsc\/var\/blockcheck\/[^ ]*\/run\/(nfq2\/nfqws2|blockcheck2\.sh)/ && $0 !~ /awk/ {print $1}'); do
  kill "$p" 2>/dev/null || true
done
for p in $(ps w 2>/dev/null | awk '/sh \.\/blockcheck2\.sh/ && $0 !~ /awk/ {print $1}'); do
  kill "$p" 2>/dev/null || true
done
sleep 1
for p in $(ps w 2>/dev/null | awk '/\/opt\/kzsc\/var\/blockcheck\/[^ ]*\/run\/(nfq2\/nfqws2|blockcheck2\.sh)/ && $0 !~ /awk/ {print $1}'); do
  kill -9 "$p" 2>/dev/null || true
done
# Remove only upstream blockcheck temporary mangle chains; KZSC chains are untouched.
for c in $(iptables-save -t mangle 2>/dev/null | awk '/^:blockcheck_(input|output)_[0-9]+ / {sub(/^:/,"",$1); print $1}'); do
  for h in INPUT OUTPUT FORWARD PREROUTING POSTROUTING; do
    while iptables -t mangle -D "$h" -j "$c" 2>/dev/null; do :; done
  done
  iptables -t mangle -F "$c" 2>/dev/null || true
  iptables -t mangle -X "$c" 2>/dev/null || true
done

mkdir -p /opt/kzsc /opt/etc/init.d /opt/bin
cp -R "$SRC/opt/kzsc/"* /opt/kzsc/
cp "$SRC/opt/etc/init.d/S99kzsc" /opt/etc/init.d/S99kzsc

# Keep only binaries in the current standalone distribution.
for f in /opt/kzsc/bin/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in
    kzsc|kzsc-audit.sh|kzsc-backup.sh|kzsc-blockcheck-cgi.sh|kzsc-keendns.sh|kzsc-blockcheck.sh|kzsc-clients.sh|kzsc-daemon.sh|kzsc-discover.sh|kzsc-dns-cgi.sh|kzsc-dns.sh|kzsc-engine-cgi.sh|kzsc-engines.sh|kzsc-isolation.sh|kzsc-lib.sh|kzsc-maintenance.sh|kzsc-native-dpi.sh|kzsc-oplog.sh|kzsc-preflight.sh|kzsc-presets-cgi.sh|kzsc-presets.sh|kzsc-purity.sh|kzsc-reconcile.sh|kzsc-settings.sh|kzsc-telegram.sh|kzsc-ui-selftest.sh|kzsc-uninstall.sh|kzsc-updater.sh|kzsc-wan-registry.sh|kzsc-wan.sh|kzsc-zapret2.sh) : ;;
    *) rm -f "$f" ;;
  esac
done
rm -rf /opt/kzsc/adapters 2>/dev/null || true
rm -f /opt/kzsc/www/data/zapret2-manager.json /opt/kzsc/var/log/zapret2-manager.log 2>/dev/null || true
LEGACY_LOG="/opt/kzsc/var/log/k""sc.log"
rm -f "$LEGACY_LOG" 2>/dev/null || true

# Enforce the standalone top-level layout. Runtime state under var/ and the
# official upstream Zapret2 tree are preserved; unknown old product trees are not.
for x in /opt/kzsc/*; do
  [ -e "$x" ] || continue
  case "${x##*/}" in bin|etc|share|var|www|zapret2) : ;; *) rm -rf "$x" ;; esac
done

# Keep only current KZSC-owned web roots; www/data is runtime/public state.
for x in /opt/kzsc/www/*; do
  [ -e "$x" ] || continue
  case "${x##*/}" in index.html|cgi-bin|data) : ;; *) rm -rf "$x" ;; esac
done

# Configuration files: preserve current runtime configs and shipped examples only.
for x in /opt/kzsc/etc/*; do
  [ -f "$x" ] || continue
  case "${x##*/}" in kzsc.conf|kzsc.conf.example|isp-map.conf|isp-map.conf.example|dpi-map.conf|dpi-map.conf.example|telegram.conf|lighttpd.conf) : ;; *) rm -f "$x" ;; esac
done

# KZSC share currently contains only its built-in DPI presets.
find /opt/kzsc/share -type f 2>/dev/null | while IFS= read -r x; do
  rel="${x#/opt/kzsc/share/}"
  case "$rel" in dpi-presets/tt.conf|dpi-presets/sol.conf|dpi-presets/kablonet.conf) : ;; *) rm -f "$x" ;; esac
done
find /opt/kzsc/share -depth -type d -empty -delete 2>/dev/null || true

# Keep only CGI endpoints used by the current standalone application.
for f in /opt/kzsc/www/cgi-bin/*; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"
  case "$b" in
    clients|health.cgi|operation_log_clear.cgi|ui_event.cgi|settings.cgi|restart.cgi|router_reboot.cgi|keendns_enable.cgi|keendns_disable.cgi|state|topology|wan_check.cgi|zapret2_install.cgi|zapret2_update.cgi|zapret2_repair.cgi|zapret2_remove.cgi|kzsc_update_check.cgi|kzsc_update_install.cgi|kzsc_update_auto_on.cgi|kzsc_update_auto_off.cgi) : ;;
    engine_enable_*.cgi|engine_disable_*.cgi|profile_set_*.cgi|blockcheck_start_*.cgi|blockcheck_stop_*.cgi|dns_*.cgi|telegram_*.cgi|backup_*.cgi) : ;;
    *) rm -f "$f" ;;
  esac
done

chmod 755 /opt/kzsc/bin/* /opt/kzsc/www/cgi-bin/* /opt/etc/init.d/S99kzsc

[ -f /opt/kzsc/etc/kzsc.conf ] || cp /opt/kzsc/etc/kzsc.conf.example /opt/kzsc/etc/kzsc.conf
for kv in \
  'KZSC_WAN_AUTO_VALIDATE="1"' \
  'KZSC_WAN_AUTO_ENABLE_NEW="1"' \
  'KZSC_WAN_REVALIDATE_RETRY_SECONDS="21600"' \
  'KZSC_BLOCKCHECK_AUTO_APPLY="1"' \
  'KZSC_BLOCKCHECK_MAX_SECONDS="1800"' \
  'KZSC_BLOCKCHECK_NIGHTLY="0"' \
  'KZSC_BLOCKCHECK_NIGHTLY_HOUR="04"' \
  'KZSC_BLOCKCHECK_NIGHTLY_MODE="quick"' \
  'KZSC_UPDATE_CHECK_INTERVAL="1800"' \
  'KZSC_UPDATE_AUTO="0"'; do
  key="${kv%%=*}"
  grep -q "^${key}=" /opt/kzsc/etc/kzsc.conf 2>/dev/null || printf '%s\n' "$kv" >> /opt/kzsc/etc/kzsc.conf
done
# v0.11.1.4: scheduled nightly Blockcheck is disabled by default. Manual Blockcheck + auto-apply remains enabled.
# Preserve the selected mode for future use, but disable the scheduler on upgrade.
if grep -q '^KZSC_BLOCKCHECK_NIGHTLY=' /opt/kzsc/etc/kzsc.conf 2>/dev/null; then
  sed -i 's/^KZSC_BLOCKCHECK_NIGHTLY=.*/KZSC_BLOCKCHECK_NIGHTLY="0"/' /opt/kzsc/etc/kzsc.conf
else
  printf '%s\n' 'KZSC_BLOCKCHECK_NIGHTLY="0"' >> /opt/kzsc/etc/kzsc.conf
fi
if grep -q '^KZSC_BLOCKCHECK_NIGHTLY_MODE=' /opt/kzsc/etc/kzsc.conf 2>/dev/null; then
  sed -i 's/^KZSC_BLOCKCHECK_NIGHTLY_MODE=.*/KZSC_BLOCKCHECK_NIGHTLY_MODE="quick"/' /opt/kzsc/etc/kzsc.conf
else
  printf '%s\n' 'KZSC_BLOCKCHECK_NIGHTLY_MODE="quick"' >> /opt/kzsc/etc/kzsc.conf
fi
[ -f /opt/kzsc/etc/isp-map.conf ] || cp /opt/kzsc/etc/isp-map.conf.example /opt/kzsc/etc/isp-map.conf
[ -f /opt/kzsc/etc/dpi-map.conf ] || cp /opt/kzsc/etc/dpi-map.conf.example /opt/kzsc/etc/dpi-map.conf
# KZSC accepts directory settings only when they point inside its own tree.
awk '/^KZSC_[A-Z0-9_]*_DIR=/{if($0 ~ /\/opt\/kzsc/) print; next} {print}' /opt/kzsc/etc/kzsc.conf > /opt/kzsc/etc/kzsc.conf.tmp
mv /opt/kzsc/etc/kzsc.conf.tmp /opt/kzsc/etc/kzsc.conf

ln -sf /opt/kzsc/bin/kzsc /opt/bin/kzsc
/opt/kzsc/bin/kzsc-purity.sh sanitize >/dev/null 2>&1 || true
if ! /opt/kzsc/bin/kzsc-discover.sh >/dev/null; then
  echo "HATA: Uyarlamalı sistem profili üretilemedi."
  exit 1
fi
if ! /opt/kzsc/bin/kzsc-wan-registry.sh refresh >/dev/null; then
  echo "HATA: WAN registry veya benzersiz NFQUEUE tahsisi oluşturulamadı."
  exit 1
fi
/opt/kzsc/bin/kzsc-clients.sh >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-wan.sh check >/dev/null 2>&1 || true
rm -f /opt/kzsc/www/cgi-bin/engines_prepare.cgi 2>/dev/null || true
/opt/kzsc/bin/kzsc-blockcheck-cgi.sh >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-dns-cgi.sh >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-dns.sh refresh >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-presets.sh refresh >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-presets-cgi.sh >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-engines.sh refresh >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-engine-cgi.sh >/dev/null 2>&1 || true
# First v0.11.2 installation adopts the already-working WANs as baseline so an
# upgrade itself does not trigger unnecessary Blockchecks.
[ -s /opt/kzsc/var/reconcile/wan-bindings.tsv ] || /opt/kzsc/bin/kzsc-reconcile.sh baseline >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-native-dpi.sh dedupe-all >/dev/null 2>&1 || true
mkdir -p /opt/kzsc/var/log /opt/kzsc/var/lib /opt/kzsc/var/backups /opt/kzsc/www/data/backups /opt/kzsc/www/data/maintenance-results /opt/kzsc/www/data/maintenance-progress
[ -x /opt/kzsc/bin/kzsc-lib.sh ] || { echo "HATA: KZSC ortak kitaplığı çalıştırılabilir değil."; exit 1; }
/opt/bin/sh -c '. /opt/kzsc/bin/kzsc-lib.sh; kzsc_prepare_maintenance_queue' || {
  echo "HATA: Web bakım kuyruğu izinleri hazırlanamadı."
  exit 1
}
# Normalize status left by a failed older updater. A successful manual install
# must open the Update tab in an idle, current state without deleting the user's
# automatic-update preference.
mkdir -p /opt/kzsc/var/update
rm -f /opt/kzsc/var/update/apply_pid /opt/kzsc/var/update/apply_boot_id \
  /opt/kzsc/var/update/apply_queued_at /opt/kzsc/var/update/last_error \
  /opt/kzsc/var/update/asset_url /opt/kzsc/var/update/sha_url
printf '%s\n' 'idle' >/opt/kzsc/var/update/apply_state
printf '%s\n' '0.11.2.18-generic' >/opt/kzsc/var/update/latest
printf '%s\n' 'https://github.com/ssy1979/keenetic-zapret-smart-control/releases/tag/v0.11.2.18-generic' >/opt/kzsc/var/update/release_url
date +%s >/opt/kzsc/var/update/last_check
[ -f /opt/kzsc/var/log/operation-log.ndjson ] || : > /opt/kzsc/var/log/operation-log.ndjson
[ -x /opt/kzsc/bin/kzsc-oplog.sh ] && /opt/kzsc/bin/kzsc-oplog.sh sanitize >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-oplog.sh publish >/dev/null 2>&1 || true
if ! /opt/kzsc/bin/kzsc-purity.sh check >/dev/null 2>&1; then
  echo "HATA: KZSC-owned tree bağımsızlık kontrolü başarısız."
  /opt/kzsc/bin/kzsc-purity.sh check || true
  exit 1
fi

# Prevent an existing opt-in auto-update setting from starting a nested
# installer while this installation is still completing its postconditions.
: > /opt/kzsc/var/run/installing
/opt/etc/init.d/S99kzsc restart
# A successful process start is insufficient: prove that the exact CGI backend
# is reachable before reporting the installation as complete.
if ! /opt/kzsc/bin/kzsc-audit.sh http; then
  echo "HATA: lighttpd/CGI çalışma sonrası doğrulaması başarısız."
  exit 1
fi
# Runtime postcondition: every enabled engine must regain its KZSC datapath after upgrade cleanup.
/opt/kzsc/bin/kzsc-native-dpi.sh ensure-all >/dev/null 2>&1 || true
/opt/etc/init.d/S99kzsc status
LAN="$(/opt/bin/sh -c '. /opt/kzsc/bin/kzsc-lib.sh; detect_lan_ip' 2>/dev/null || true)"
/opt/kzsc/bin/kzsc-maintenance.sh snapshot >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-reconcile.sh status >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-telegram.sh publish-status >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-backup.sh status >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-keendns.sh sync >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-updater.sh publish >/dev/null 2>&1 || true
ROLLBACK_ARMED=0
[ -z "$UPGRADE_BACKUP" ] || rm -rf "$UPGRADE_BACKUP"
echo "Keenetic Zapret Smart Control v0.11.2.18-generic kuruldu."
PORT="$(sed -n 's/^KZSC_PORT="\([0-9][0-9]*\)"/\1/p' /opt/kzsc/etc/kzsc.conf | tail -n1)"
[ -n "$PORT" ] || PORT=9090
echo "Panel: http://${LAN:-ROUTER_IP}:${PORT}/"
rm -f /tmp/kzsc-telegram-req.* /tmp/kzsc-telegram-payload.* /tmp/kzsc-telegram-payload.*.tmp /tmp/kzsc-backup-req.* /tmp/kzsc-backup-upload.* 2>/dev/null || true
