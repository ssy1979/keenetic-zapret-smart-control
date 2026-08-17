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
VERSION="0.11.2.14-generic"
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
    KZSC_UPDATER_SELF="$UPDATER" sh "$UPDATER" "$@"
}

write_release v0.11.2.15-generic
out="$(run_updater check)" || fail "valid release check failed"
printf '%s' "$out" | grep -q '0.11.2.15-generic' || fail "new release not reported"
grep -q '"current":"0.11.2.14-generic"' "$HOME_DIR/www/data/update-status.json" || fail "current version missing"
grep -q '"latest":"0.11.2.15-generic"' "$HOME_DIR/www/data/update-status.json" || fail "latest version missing"
grep -q '"available":true' "$HOME_DIR/www/data/update-status.json" || fail "new release not marked available"
[ "$(cat "$HOME_DIR/var/update/notified_latest")" = 0.11.2.15-generic ] || fail "Telegram de-duplication marker missing"
ok "trusted newer release is detected"

run_updater auto 1 >/dev/null || fail "auto update could not be enabled"
grep -q '^KZSC_UPDATE_AUTO="1"$' "$HOME_DIR/etc/kzsc.conf" || fail "auto update setting not persisted"
run_updater status | grep -q '"auto":true' || fail "auto update status not published"
run_updater auto 0 >/dev/null || fail "auto update could not be disabled"
ok "automatic update remains explicit opt-in"

write_release v0.11.2.13-generic
run_updater check >/dev/null || fail "older valid release check failed"
grep -q '"available":false' "$HOME_DIR/www/data/update-status.json" || fail "downgrade was offered"
ok "downgrades are not offered"

write_release v0.11.2.16-generic attacker
if run_updater check >/dev/null 2>&1; then fail "untrusted asset owner was accepted"; fi
grep -q 'Beklenen KZSC release arşivi bulunamadı.' "$HOME_DIR/www/data/update-status.json" || fail "untrusted asset error not published"
ok "asset URLs are pinned to the trusted repository"

write_release latest-generic
if run_updater check >/dev/null 2>&1; then fail "invalid release tag was accepted"; fi
grep -q 'GitHub latest release etiketi geçersiz.' "$HOME_DIR/www/data/update-status.json" || fail "invalid tag error not published"
ok "invalid tags are rejected"

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
ok "update installation security guards are present"

echo "ALL UPDATER TESTS PASSED"
