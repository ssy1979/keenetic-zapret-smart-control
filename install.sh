#!/bin/sh
set -eu
SRC="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
[ -x /opt/bin/sh ] || { echo "HATA: Entware/OPKG hazır değil."; exit 1; }

REMOVE_RETIRED=0
for arg in "$@"; do
  case "$arg" in
    --remove-retired) REMOVE_RETIRED=1 ;;
    --resume) : ;;
    *) echo "Kullanım: sh install.sh [--remove-retired]"; exit 1 ;;
  esac
done

# Validate every shipped shell/CGI source before touching a working install.
for f in "$SRC/install.sh" "$SRC/opt/etc/init.d/S99kzsc" "$SRC"/opt/kzsc/bin/* "$SRC"/opt/kzsc/www/cgi-bin/*; do
  [ -f "$f" ] || continue
  first="$(head -n1 "$f" 2>/dev/null || true)"
  case "$first" in '#!'*sh*) /opt/bin/sh -n "$f" || { echo "HATA: Shell sözdizimi geçersiz: $f"; exit 1; } ;; esac
done

# A truncated local archive must fail before it stops the working service.
# The daemon depends on these backends every cycle; starting with only a
# subset leaves stale PID/lock files and can trigger repeated ndm activity.
for required in \
  kzsc-daemon.sh kzsc-discover.sh kzsc-reconcile.sh kzsc-clients.sh \
  kzsc-isolation.sh kzsc-wan-registry.sh kzsc-native-dpi.sh \
  kzsc-maintenance.sh kzsc-updater.sh; do
  [ -f "$SRC/opt/kzsc/bin/$required" ] || {
    echo "HATA: KZSC paketi eksik backend içeriyor: $required"
    exit 1
  }
done

# A manual install can complete its own router prerequisites.  KeeneticOS
# component commits may reboot the router, so leave a narrowly scoped Entware
# init hook that resumes this exact, already verified installer afterwards.
BOOTSTRAP="$SRC/opt/kzsc/bin/kzsc-bootstrap.sh"
missing_components="$(/opt/bin/sh "$BOOTSTRAP" missing-components)" || exit 1
if [ -n "$missing_components" ]; then
  mkdir -p /opt/etc/init.d /opt/tmp /opt/kzsc/var/update
  RESUME_STATE=/opt/kzsc/var/update/kzsc-bootstrap-resume.state
  RESUME_INIT=/opt/etc/init.d/S98kzsc-bootstrap-resume
  RESUME_LOG=/opt/kzsc/var/update/kzsc-bootstrap-resume.log
  RESUME_PACKAGE=/opt/kzsc/var/update/kzsc-bootstrap-resume-package
  # The secure updater extracts releases into a disposable directory.  Keep a
  # private copy of only the router installer payload so it survives updater
  # cleanup and the component reboot.
  # On reboot the resume installer runs from RESUME_PACKAGE itself. Never
  # delete that source before copying it, otherwise the first retry empties
  # the durable payload and all later retries fail with "install.sh missing".
  case "$SRC" in
    "$RESUME_PACKAGE")
      [ -f "$SRC/install.sh" ] || exit 1
      ;;
    *)
      rm -rf "$RESUME_PACKAGE"
      mkdir -p "$RESUME_PACKAGE"
      cp "$SRC/install.sh" "$RESUME_PACKAGE/install.sh" || exit 1
      cp -R "$SRC/opt" "$RESUME_PACKAGE/opt" || exit 1
      [ ! -f "$SRC/SHA256SUMS" ] || cp "$SRC/SHA256SUMS" "$RESUME_PACKAGE/SHA256SUMS" || exit 1
      ;;
  esac
  # Source files are intentionally stored as non-executable Git files and
  # invoked with /opt/bin/sh.  Validate readability, not its mode, otherwise
  # a perfectly valid resume package is rejected before components are checked.
  [ -r "$RESUME_PACKAGE/opt/kzsc/bin/kzsc-bootstrap.sh" ] || {
    echo 'HATA: Yeniden başlatma sonrası kurulum kopyası hazırlanamadı.'
    rm -rf "$RESUME_PACKAGE"
    exit 1
  }
  printf '%s\n%s\n' "$RESUME_PACKAGE" "$REMOVE_RETIRED" >"$RESUME_STATE"
  chmod 600 "$RESUME_STATE"
  cat >"$RESUME_INIT" <<'EOF'
#!/opt/bin/sh
STATE=/opt/kzsc/var/update/kzsc-bootstrap-resume.state
LOG=/opt/kzsc/var/update/kzsc-bootstrap-resume.log
start(){
  [ -f "$STATE" ] || { rm -f "$0"; return 0; }
  (
    sleep 5
    src="$(sed -n '1p' "$STATE" 2>/dev/null)"
    retired="$(sed -n '2p' "$STATE" 2>/dev/null)"
    [ -f "$src/install.sh" ] || { echo 'KZSC otomatik devam kaynağı bulunamadı.' >>"$LOG"; exit 1; }
    attempt=1
    while [ "$attempt" -le 3 ]; do
      echo "KZSC otomatik kurulum devam denemesi: $attempt" >>"$LOG"
      if [ "$retired" = 1 ]; then
        /opt/bin/sh "$src/install.sh" --resume --remove-retired >>"$LOG" 2>&1
      else
        /opt/bin/sh "$src/install.sh" --resume >>"$LOG" 2>&1
      fi
      rc=$?
      if [ "$rc" -eq 0 ]; then
        rm -f "$STATE" "$0"
        rm -rf "$src"
        exit 0
      fi
      # An unavailable KeeneticOS component is a permanent device/catalogue
      # condition, not a transient reboot failure. Stop retrying and preserve
      # the router admin service instead of creating a reboot loop.
      if grep -Eqi 'component .*unavailable|bileşen.*kullanılamıyor|unavailable' "$LOG" 2>/dev/null; then
        echo 'KZSC otomatik devamı durduruldu: KeeneticOS bileşeni bu cihazda kullanılamıyor.' >>"$LOG"
        rm -f "$STATE" "$0"
        rm -rf "$src"
        exit 1
      fi
      [ "$rc" -eq 75 ] && exit 0
      attempt=$((attempt+1))
      sleep 60
    done
    echo 'KZSC otomatik kurulum üç denemede tamamlanamadı.' >>"$LOG"
  ) &
}
case "${1:-}" in start) start;; stop) :;; *) exit 0;; esac
EOF
  chmod 755 "$RESUME_INIT"
  echo "Eksik KeeneticOS bileşenleri otomatik kurulacak: $missing_components"
  if ! /opt/bin/sh "$BOOTSTRAP" install-components $missing_components; then
    rm -f "$RESUME_STATE" "$RESUME_INIT"
    rm -rf "$RESUME_PACKAGE"
    exit 1
  fi
  echo 'Router yeniden başladıktan sonra KZSC kurulumu otomatik devam edecek.'
  echo "Devam günlüğü: $RESUME_LOG"
  exit 75
fi

# Install only missing Entware dependencies, then run the complete read-only
# compatibility gate before stopping services or replacing KZSC files.
/opt/bin/sh "$BOOTSTRAP" ensure-packages
/opt/bin/sh "$SRC/opt/kzsc/bin/kzsc-preflight.sh" install

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
PIDS="$(ps w 2>/dev/null | awk '/\/opt\/kzsc\/bin\/kzsc-daemon\.sh|kzsc-daemon\.sh/ && $0 !~ /awk/ {print $1}')"
for x in $PIDS; do kill "$x" 2>/dev/null || true; done
sleep 1
PIDS="$(ps w 2>/dev/null | awk '/\/opt\/kzsc\/bin\/kzsc-daemon\.sh|kzsc-daemon\.sh/ && $0 !~ /awk/ {print $1}')"
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

# Keep only binaries shipped by the current standalone distribution.  Using
# the package itself as the allowlist prevents a newly added backend from
# being copied and then accidentally removed by a stale hand-maintained list.
for f in /opt/kzsc/bin/*; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"
  [ -f "$SRC/opt/kzsc/bin/$b" ] || rm -f "$f"
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
  case "$rel" in dpi-presets/kablonet.conf|dpi-presets/sol.conf|dpi-presets/tt-fiber.conf|dpi-presets/vodafone.conf|dpi-presets/vodafone-tt.conf|dpi-presets/vodafone-tt2.conf) : ;; *) rm -f "$x" ;; esac
done
# Fail-safe for archives assembled by third-party/local staging tools: every
# built-in preset allowed above must actually be present in the extracted
# package.  A partial preset set makes existing engine profiles appear valid
# while the UI cannot offer them.
for preset in kablonet sol tt-fiber vodafone vodafone-tt vodafone-tt2; do
  [ -f "$SRC/opt/kzsc/share/dpi-presets/$preset.conf" ] || {
    echo "HATA: eksik yerleşik DPI preset pakette yok: $preset.conf" >&2
    exit 1
  }
  cp -f "$SRC/opt/kzsc/share/dpi-presets/$preset.conf" "/opt/kzsc/share/dpi-presets/$preset.conf"
done
find /opt/kzsc/share -depth -type d -empty -delete 2>/dev/null || true

# Keep every static CGI endpoint shipped by this package, plus the generated
# per-WAN endpoints.  The source-tree check is deliberately the authoritative
# allowlist so a new endpoint cannot disappear during installation.
for f in /opt/kzsc/www/cgi-bin/*; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"
  [ -f "$SRC/opt/kzsc/www/cgi-bin/$b" ] && continue
  case "$b" in
    engine_enable_*.cgi|engine_disable_*.cgi|profile_set_*.cgi|blockcheck_start_*.cgi|blockcheck_stop_*.cgi|dns_*.cgi|telegram_*.cgi|backup_*.cgi) : ;;
    *) rm -f "$f" ;;
  esac
done

chmod 755 /opt/kzsc/bin/* /opt/kzsc/www/cgi-bin/* /opt/etc/init.d/S99kzsc
for f in "$SRC"/opt/kzsc/bin/*; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"
  [ -x "/opt/kzsc/bin/$b" ] || { echo "HATA: KZSC backend kurulamadı: $b"; exit 1; }
done
for f in "$SRC"/opt/kzsc/www/cgi-bin/*; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"
  [ -x "/opt/kzsc/www/cgi-bin/$b" ] || { echo "HATA: KZSC CGI kurulamadı: $b"; exit 1; }
done

[ -f /opt/kzsc/etc/kzsc.conf ] || cp /opt/kzsc/etc/kzsc.conf.example /opt/kzsc/etc/kzsc.conf
for kv in \
  'KZSC_FAST_INTERVAL="15"' \
  'KZSC_HEAVY_REFRESH_INTERVAL="60"' \
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
printf '%s\n' '0.11.2.42-generic' >/opt/kzsc/var/update/latest
printf '%s\n' 'https://github.com/ssy1979/keenetic-zapret-smart-control/releases/tag/v0.11.2.42-generic' >/opt/kzsc/var/update/release_url
date +%s >/opt/kzsc/var/update/last_check
[ -f /opt/kzsc/var/log/operation-log.ndjson ] || : > /opt/kzsc/var/log/operation-log.ndjson
[ -x /opt/kzsc/bin/kzsc-oplog.sh ] && /opt/kzsc/bin/kzsc-oplog.sh sanitize >/dev/null 2>&1 || true
/opt/kzsc/bin/kzsc-oplog.sh publish >/dev/null 2>&1 || true
# The preset and IPv6 implementations may include upstream-compatible
# adaptations. Purity remains available as an audit command, but it must not
# block an otherwise valid installation.
if ! /opt/kzsc/bin/kzsc-purity.sh check >/dev/null 2>&1; then
  echo "UYARI: KZSC kaynak denetimi eşleşmeyen uyarlama notları bildirdi; kurulum sürdürülüyor."
fi

# Prevent an existing opt-in auto-update setting from starting a nested
# installer while this installation is still completing its postconditions.
: > /opt/kzsc/var/run/installing
# Entware's package init script otherwise binds port 80 and masks Keenetic's
# own admin UI (403). KZSC uses its isolated lighttpd instance on 9090.
if [ -x /opt/etc/init.d/S80lighttpd ]; then
  /opt/etc/init.d/S80lighttpd stop >/dev/null 2>&1 || true
  mv /opt/etc/init.d/S80lighttpd /opt/etc/init.d/disabled-S80lighttpd 2>/dev/null || true
fi
# Older local builds used S80lighttpd.disabled; rc.unslung still matches that
# name because it starts every executable S* file. Rename it out of the scan.
if [ -x /opt/etc/init.d/S80lighttpd.disabled ]; then
  mv /opt/etc/init.d/S80lighttpd.disabled /opt/etc/init.d/disabled-S80lighttpd 2>/dev/null || true
fi
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
# A legacy updater may have been terminated before it could observe exit 75.
# The resumed installer is authoritative and closes that staged state cleanly.
if [ -f /opt/kzsc/var/update/apply_state ] &&
   grep -Eq '^(installing|reboot_pending)$' /opt/kzsc/var/update/apply_state 2>/dev/null; then
  printf '%s\n' success >/opt/kzsc/var/update/apply_state
  rm -f /opt/kzsc/var/update/apply_pid /opt/kzsc/var/update/apply_boot_id \
    /opt/kzsc/var/update/apply_queued_at /opt/kzsc/var/update/last_error
fi
/opt/kzsc/bin/kzsc-updater.sh publish >/dev/null 2>&1 || true
ROLLBACK_ARMED=0
[ -z "$UPGRADE_BACKUP" ] || rm -rf "$UPGRADE_BACKUP"
echo "Keenetic Zapret Smart Control v0.11.2.42-generic kuruldu."
PORT="$(sed -n 's/^KZSC_PORT="\([0-9][0-9]*\)"/\1/p' /opt/kzsc/etc/kzsc.conf | tail -n1)"
[ -n "$PORT" ] || PORT=9090
echo "Panel: http://${LAN:-ROUTER_IP}:${PORT}/"
rm -f /tmp/kzsc-telegram-req.* /tmp/kzsc-telegram-payload.* /tmp/kzsc-telegram-payload.*.tmp /tmp/kzsc-backup-req.* /tmp/kzsc-backup-upload.* 2>/dev/null || true
rm -f /opt/kzsc/var/update/kzsc-bootstrap-resume.state /opt/etc/init.d/S98kzsc-bootstrap-resume 2>/dev/null || true
case "$SRC" in /opt/kzsc/var/update/kzsc-bootstrap-resume-package) : ;; *) rm -rf /opt/kzsc/var/update/kzsc-bootstrap-resume-package 2>/dev/null || true ;; esac
