#!/bin/sh
set -eu

SRC="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LIB="$SRC/opt/kzsc/bin/kzsc-lib.sh"
UPDATER="$SRC/opt/kzsc/bin/kzsc-updater.sh"
TMP="${TMPDIR:-/tmp}/kzsc-updater-test.$$"
HOME_DIR="$TMP/home"
FIXTURE="$TMP/fixture"
trap 'rm -rf "$TMP"' EXIT INT TERM HUP
mkdir -p "$HOME_DIR/bin" "$HOME_DIR/etc" "$FIXTURE"

fail(){ echo "FAIL: $*" >&2; exit 1; }
ok(){ echo "OK: $*"; }

cat >"$HOME_DIR/bin/kzsc-maintenance.sh" <<'EOF'
VERSION="0.11.2.17-generic"
EOF
cat >"$HOME_DIR/etc/kzsc.conf" <<'EOF'
KZSC_UPDATE_CHECK_INTERVAL="1800"
KZSC_UPDATE_AUTO="0"
EOF

write_release(){
  tag="$1"; owner="${2:-ssy1979}"
  archive="keenetic-zapret-smart-control-$tag.tar.gz"
  cat >"$FIXTURE/release.json" <<EOF
{
  "tag_name": "$tag",
  "html_url": "https://github.com/ssy1979/keenetic-zapret-smart-control/releases/tag/$tag",
  "assets": [
    {"browser_download_url": "https://github.com/$owner/keenetic-zapret-smart-control/releases/download/$tag/$archive"},
    {"browser_download_url": "https://github.com/$owner/keenetic-zapret-smart-control/releases/download/$tag/$archive.sha256"}
  ]
}
EOF
}

run_updater(){
  KZSC_HOME="$HOME_DIR" KZSC_LIB="$LIB" KZSC_UPDATE_FIXTURE_DIR="$FIXTURE" \
    KZSC_UPDATER_SELF="$UPDATER" KZSC_UPDATE_SHELL=/bin/sh \
    KZSC_UPDATE_TMP_BASE="$TMP/apply-tmp" sh "$UPDATER" "$@"
}

mkdir -p "$HOME_DIR/var/update"
printf '%s\n' failed >"$HOME_DIR/var/update/apply_state"
printf '%s\n' 'old update failure' >"$HOME_DIR/var/update/last_error"
write_release v0.11.2.18-generic
out="$(run_updater check)" || fail "valid release check failed"
printf '%s' "$out" | grep -q '0.11.2.18-generic' || fail "new release not reported"
grep -q '"current":"0.11.2.17-generic"' "$HOME_DIR/www/data/update-status.json" || fail "current version missing"
grep -q '"latest":"0.11.2.18-generic"' "$HOME_DIR/www/data/update-status.json" || fail "latest version missing"
grep -q '"available":true' "$HOME_DIR/www/data/update-status.json" || fail "new release not marked available"
[ "$(cat "$HOME_DIR/var/update/notified_latest")" = 0.11.2.18-generic ] || fail "Telegram de-duplication marker missing"
[ "$(cat "$HOME_DIR/var/update/apply_state")" = idle ] || fail "manual check kept stale failed apply state"
[ ! -e "$HOME_DIR/var/update/last_error" ] || fail "manual check kept stale update error"
ok "trusted newer release is detected"

run_updater auto 1 >/dev/null || fail "auto update could not be enabled"
grep -q '^KZSC_UPDATE_AUTO="1"$' "$HOME_DIR/etc/kzsc.conf" || fail "auto update setting not persisted"
run_updater status | grep -q '"auto":true' || fail "auto update status not published"
run_updater auto 0 >/dev/null || fail "auto update could not be disabled"
ok "automatic update remains explicit opt-in"

write_release v0.11.2.14-generic
run_updater check >/dev/null || fail "older valid release check failed"
grep -q '"available":false' "$HOME_DIR/www/data/update-status.json" || fail "downgrade was offered"
ok "downgrades are not offered"

write_release v0.11.2.19-generic attacker
if run_updater check >/dev/null 2>&1; then fail "untrusted asset owner was accepted"; fi
grep -q 'Beklenen KZSC release arşivi bulunamadı.' "$HOME_DIR/www/data/update-status.json" || fail "untrusted asset error not published"
ok "asset URLs are pinned to the trusted repository"

write_release latest-generic
if run_updater check >/dev/null 2>&1; then fail "invalid release tag was accepted"; fi
grep -q 'GitHub latest release etiketi geçersiz.' "$HOME_DIR/www/data/update-status.json" || fail "invalid tag error not published"
ok "invalid tags are rejected"

# Exercise the complete self-update path. This specifically guards BusyBox ash
# variable scope: publish_status() and archive_safe() must not overwrite the
# apply worker's temporary directory or archive name.
write_release v0.11.2.18-generic
RELEASE_NAME="keenetic-zapret-smart-control-v0.11.2.18-generic"
RELEASE_ROOT="$TMP/$RELEASE_NAME"
mkdir -p "$RELEASE_ROOT"
cat >"$RELEASE_ROOT/install.sh" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' 'VERSION="0.11.2.18-generic"' >"$KZSC_HOME/bin/kzsc-maintenance.sh"
: >"$KZSC_HOME/var/update-fixture-installed"
EOF
(cd "$RELEASE_ROOT" && sha256sum install.sh >SHA256SUMS)
tar -czf "$FIXTURE/$RELEASE_NAME.tar.gz" -C "$TMP" "$RELEASE_NAME"
(cd "$FIXTURE" && sha256sum "$RELEASE_NAME.tar.gz" >"$RELEASE_NAME.tar.gz.sha256")

run_updater _apply >/dev/null || fail "complete archive update flow failed"
[ -f "$HOME_DIR/var/update-fixture-installed" ] || fail "fixture installer was not executed"
[ "$(sed -n 's/^VERSION="\([^"]*\)"$/\1/p' "$HOME_DIR/bin/kzsc-maintenance.sh")" = 0.11.2.18-generic ] \
  || fail "fixture release version was not installed"
grep -q '"apply_state":"success"' "$HOME_DIR/www/data/update-status.json" \
  || fail "successful apply state was not published"
if find "$HOME_DIR/www/data" -maxdepth 1 -type d -name 'update-status.json.tmp.*' | grep -q .; then
  fail "status temporary path was accidentally created as a directory"
fi
if find "$TMP/apply-tmp" -maxdepth 1 -name 'kzsc-self-update.*' 2>/dev/null | grep -q .; then
  fail "self-update temporary directory was not cleaned"
fi
ok "download, verify, extract, install, publish, and cleanup flow"

for cgi in check install auto_on auto_off; do
  f="$SRC/opt/kzsc/www/cgi-bin/kzsc_update_${cgi}.cgi"
  [ -f "$f" ] || fail "missing updater CGI: $cgi"
  grep -q "ACTION=\"kzsc_update_${cgi}\"" "$f" || fail "wrong updater CGI action: $cgi"
done
grep -q 'MAX_ARCHIVE_BYTES=10485760' "$UPDATER" || fail "archive size guard missing"
grep -q 'sha256sum.*SHA256SUMS' "$UPDATER" || fail "inner manifest verification missing"
grep -q 'count>500' "$UPDATER" || fail "archive entry-count guard missing"
grep -q 'Blockcheck çalışırken KZSC güncellenemez.' "$UPDATER" || fail "Blockcheck interlock missing"
grep -q 'var/run/installing' "$UPDATER" || fail "nested-installer interlock missing"
grep -q 'recover_stale_apply' "$UPDATER" || fail "interrupted-update recovery missing"
grep -Fq 'kzsc_pid_matches "$p" "$SELF"' "$UPDATER" || fail "update worker PID identity guard missing"
grep -q 'local current latest last error release_url apply_state available auto applying status_tmp' "$UPDATER" \
  || fail "status publisher variables are not function-local"
grep -q 'local apply_tmp latest tag archive root asset_url sha_url bytes expected actual' "$UPDATER" \
  || fail "apply worker variables are not function-local"
ok "update installation security guards are present"

QUEUE_HOME="$TMP/queue-home"
KZSC_HOME="$QUEUE_HOME" sh -c '. "$1"; kzsc_prepare_maintenance_queue' sh "$LIB" \
  || fail "maintenance queue permissions could not be prepared"
[ "$(stat -c %a "$QUEUE_HOME/var")" = 711 ] || fail "var traversal mode is not 711"
[ "$(stat -c %a "$QUEUE_HOME/var/run")" = 711 ] || fail "run traversal mode is not 711"
[ "$(stat -c %a "$QUEUE_HOME/var/run/maintenance-queue")" = 733 ] || fail "queue mode is not 733"
grep -q 'kzsc_prepare_maintenance_queue' "$SRC/opt/etc/init.d/S99kzsc" || fail "service queue preparation missing"
grep -q 'kzsc_prepare_maintenance_queue' "$SRC/install.sh" || fail "installer queue preparation missing"
grep -q 'maintenance_queue":true' "$SRC/opt/kzsc/www/cgi-bin/health.cgi" || fail "CGI queue probe missing"
grep -q 'id="kzscUpdateAuto"' "$SRC/opt/kzsc/www/index.html" || fail "web auto-update toggle missing"
grep -q 'kzsc_update_auto_on' "$SRC/opt/kzsc/www/index.html" || fail "web auto-update enable action missing"
grep -q 'kzsc_update_auto_off' "$SRC/opt/kzsc/www/index.html" || fail "web auto-update disable action missing"
grep -q 'friendlyKzscUpdateError' "$SRC/opt/kzsc/www/index.html" || fail "friendly bilingual updater error mapping missing"
for endpoint in kzsc_update_check kzsc_update_install kzsc_update_auto_on kzsc_update_auto_off; do
  grep -q '\[ -d "$QUEUE" \]' "$SRC/opt/kzsc/www/cgi-bin/${endpoint}.cgi" || fail "$endpoint queue directory guard missing"
  ! grep -q 'mkdir -p "$QUEUE"' "$SRC/opt/kzsc/www/cgi-bin/${endpoint}.cgi" || fail "$endpoint still attempts CGI-side queue creation"
done
grep -q 'local queue=' "$LIB" || fail "maintenance queue variable is not function-local"
ok "web updater queue permissions and auto-update toggle are guarded"

grep -q 'id="kzscRestartBtn"' "$SRC/opt/kzsc/www/index.html" || fail "settings restart button missing"
grep -q 'waitKzscServiceReady' "$SRC/opt/kzsc/www/index.html" || fail "restart health wait missing"
grep -q '^ACTION="restart"$' "$SRC/opt/kzsc/www/cgi-bin/restart.cgi" || fail "restart CGI action missing"
grep -Fq "printf '%s|%s\n' \"\$RID\" \"\$ACTION\"" "$SRC/opt/kzsc/www/cgi-bin/restart.cgi" || fail "restart CGI queue write missing"
grep -q 'id="routerRebootBtn"' "$SRC/opt/kzsc/www/index.html" || fail "settings router reboot button missing"
grep -q "routerRebootBtn')?.addEventListener" "$SRC/opt/kzsc/www/index.html" || fail "router reboot click handler missing"
grep -q "'X-KZSC-Action':'router-reboot'" "$SRC/opt/kzsc/www/index.html" || fail "router reboot custom request header missing"
grep -q '^ACTION="router_reboot"$' "$SRC/opt/kzsc/www/cgi-bin/router_reboot.cgi" || fail "router reboot CGI action missing"
grep -Fq "printf '%s|%s\n' \"\$RID\" \"\$ACTION\"" "$SRC/opt/kzsc/www/cgi-bin/router_reboot.cgi" || fail "router reboot CGI queue write missing"
grep -q 'REQUEST_METHOD:-GET' "$SRC/opt/kzsc/www/cgi-bin/router_reboot.cgi" || fail "router reboot POST guard missing"
grep -q 'HTTP_X_KZSC_ACTION' "$SRC/opt/kzsc/www/cgi-bin/router_reboot.cgi" || fail "router reboot request-header guard missing"
grep -q "system reboot 30" "$SRC/opt/kzsc/bin/kzsc-maintenance.sh" || fail "Keenetic scheduled reboot command missing"
grep -q 'command -v ndmc' "$SRC/opt/kzsc/bin/kzsc-maintenance.sh" || fail "Keenetic ndmc discovery missing"
grep -q "router_reboot) cat=system; title='Router Yeniden Başlatma'" "$SRC/opt/kzsc/bin/kzsc-telegram.sh" || fail "router reboot Telegram title missing"
grep -q '\[ "$action" = router_reboot \]' "$SRC/opt/kzsc/bin/kzsc-oplog.sh" || fail "router reboot synchronous Telegram attempt missing"
! grep -q 'operationLogPanel' "$SRC/opt/kzsc/www/index.html" || fail "removed Event Log tab is still visible"
grep -Fq "printf '%s\\n' 'idle' >/opt/kzsc/var/update/apply_state" "$SRC/install.sh" || fail "installer stale update-state reset missing"
canonical="$(sed -n 's/^VERSION="\([^"]*\)"$/\1/p' "$SRC/opt/kzsc/bin/kzsc-maintenance.sh")"
[ -n "$canonical" ] || fail "canonical release version missing"
grep -Fq "printf '%s\\n' '$canonical' >/opt/kzsc/var/update/latest" "$SRC/install.sh" || fail "installer current release normalization missing"
ok "settings KZSC/router restart controls and Event Log tab removal are guarded"

TELEGRAM="$SRC/opt/kzsc/bin/kzsc-telegram.sh"
grep -q '/kzsc_update_check' "$TELEGRAM" || fail "Telegram KZSC update-check command missing"
grep -q '/kzsc_update_install' "$TELEGRAM" || fail "Telegram KZSC update-install command missing"
grep -q 'callback_data.*ku_confirm:install' "$TELEGRAM" || fail "Telegram update confirmation button missing"
grep -q 'callback_data.*ku_install:yes' "$TELEGRAM" || fail "Telegram confirmed update action missing"
grep -q 'ku_auto)' "$TELEGRAM" || fail "Telegram automatic-update toggle handler missing"
grep -q 'send_view update' "$TELEGRAM" || fail "Telegram update view missing"
ok "Telegram KZSC update check, confirmation, install, and auto-toggle controls"

echo "ALL UPDATER TESTS PASSED"
