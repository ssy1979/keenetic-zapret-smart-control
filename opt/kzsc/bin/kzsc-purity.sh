#!/opt/bin/sh
# Original KZSC read-only source/payload checks. This tool never removes,
# rewrites, stops, or imports another application's files or processes.
# A reference scan detects accidental coupling; it is not proof of authorship.

SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="${2:-${KZSC_HOME:-${SELF_DIR%/bin}}}"
FAIL=0
ok(){ printf 'OK   %s\n' "$*"; }
bad(){ printf 'FAIL %s\n' "$*"; FAIL=1; }
warn(){ printf 'WARN %s\n' "$*"; }

required_payload_check(){
  for f in \
    bin/kzsc bin/kzsc-lib.sh bin/kzsc-audit.sh bin/kzsc-purity.sh \
    bin/kzsc-ui-selftest.sh bin/kzsc-bootstrap.sh bin/kzsc-preflight.sh \
    bin/kzsc-daemon.sh bin/kzsc-discover.sh bin/kzsc-reconcile.sh \
    bin/kzsc-clients.sh bin/kzsc-isolation.sh bin/kzsc-wan-registry.sh \
    bin/kzsc-wan.sh bin/kzsc-native-dpi.sh bin/kzsc-maintenance.sh \
    bin/kzsc-updater.sh bin/kzsc-backup.sh bin/kzsc-blockcheck.sh \
    bin/kzsc-blockcheck-cgi.sh bin/kzsc-dns.sh bin/kzsc-dns-cgi.sh \
    bin/kzsc-dpi-policy.sh bin/kzsc-engine-cgi.sh bin/kzsc-engines.sh \
    bin/kzsc-keendns.sh bin/kzsc-oplog.sh bin/kzsc-presets-cgi.sh \
    bin/kzsc-presets.sh bin/kzsc-settings.sh bin/kzsc-telegram.sh \
    bin/kzsc-uninstall.sh bin/kzsc-zapret2.sh \
    www/index.html www/cgi-bin/health.cgi www/cgi-bin/settings.cgi \
    www/cgi-bin/kzsc_uninstall.cgi www/cgi-bin/zapret2_status.cgi \
    www/cgi-bin/backup_create.cgi www/cgi-bin/backup_delete.cgi \
    www/cgi-bin/backup_download.cgi www/cgi-bin/backup_restore_saved.cgi \
    www/cgi-bin/backup_restore.cgi www/cgi-bin/backup_status.cgi \
    www/cgi-bin/backup_telegram.cgi www/cgi-bin/clients \
    www/cgi-bin/dpi_policy.cgi www/cgi-bin/keendns_disable.cgi \
    www/cgi-bin/keendns_enable.cgi www/cgi-bin/kzsc_update_auto_off.cgi \
    www/cgi-bin/kzsc_update_auto_on.cgi www/cgi-bin/kzsc_update_check.cgi \
    www/cgi-bin/kzsc_update_install.cgi www/cgi-bin/operation_log_clear.cgi \
    www/cgi-bin/refresh.cgi www/cgi-bin/restart.cgi www/cgi-bin/router_reboot.cgi \
    www/cgi-bin/state www/cgi-bin/telegram_find_chat.cgi www/cgi-bin/telegram_save.cgi \
    www/cgi-bin/telegram_status.cgi www/cgi-bin/telegram_test.cgi \
    www/cgi-bin/topology www/cgi-bin/ui_event.cgi www/cgi-bin/wan_check.cgi \
    www/cgi-bin/zapret2_check.cgi www/cgi-bin/zapret2_install.cgi \
    www/cgi-bin/zapret2_ipv6.cgi www/cgi-bin/zapret2_remove.cgi \
    www/cgi-bin/zapret2_repair.cgi www/cgi-bin/zapret2_start.cgi \
    www/cgi-bin/zapret2_stop.cgi www/cgi-bin/zapret2_update_auto.cgi \
    www/cgi-bin/zapret2_update.cgi \
    etc/kzsc.conf.example etc/isp-map.conf.example etc/dpi-map.conf.example
  do
    [ -f "$ROOT/$f" ] && [ -s "$ROOT/$f" ] && [ ! -L "$ROOT/$f" ] \
      || bad "Required KZSC payload missing, empty, or symlinked: $f"
  done
  for name in kablonet sol tt-fiber vodafone vodafone-tt vodafone-tt2; do
    [ -s "$ROOT/share/dpi-presets/$name.conf" ] && [ ! -L "$ROOT/share/dpi-presets/$name.conf" ] \
      || bad "Required KZSC preset missing, empty, or symlinked: $name"
  done

  # An added literal backend dependency must be shipped with the same release.
  refs="$(grep -hEo '(/opt/kzsc/bin/|\$KZSC_HOME/bin/)kzsc-[a-z0-9-]+[.]sh' \
    "$ROOT"/bin/* "$ROOT"/www/cgi-bin/* 2>/dev/null | sed 's#.*/##' | sort -u)"
  for name in $refs; do
    [ -s "$ROOT/bin/$name" ] || bad "Referenced KZSC backend missing: $name"
  done
  [ "$FAIL" -ne 0 ] || ok 'Required KZSC source payload and backend references present'
}

source_retired_scan(){
  # Keep scan terms assembled so this detector does not match its own source.
  manager='k''zm2'
  prior='k''sc'
  author='revolution''tr'
  pattern="/opt/(${manager}[^/[:space:]\"']*|${prior})(/|[[:space:]\"'])|github[.]com/${author}/"
  for dir in bin share www/cgi-bin; do
    [ -d "$ROOT/$dir" ] && [ ! -L "$ROOT/$dir" ] || { bad "KZSC source directory missing or symlinked: $dir"; continue; }
    links="$(find "$ROOT/$dir" -type l 2>/dev/null)"
    [ -z "$links" ] || { bad "KZSC source must not follow external symlinks: $dir"; printf '%s\n' "$links"; }
    files="$(find "$ROOT/$dir" -type f 2>/dev/null)"
    # File names shipped by KZSC never contain newlines. Preserve spaces while
    # iterating so an unexpected source filename cannot disable the check.
    saved_ifs="$IFS"
    IFS='
'
    for f in $files; do
      # profile_set_*.cgi files are generated runtime endpoints.  The daemon
      # may replace them while a reinstall audit is scanning the tree; they
      # are not shipped source and must not make a healthy install fail.
      case "$f" in
        "$ROOT/www/cgi-bin/profile_set_"*.cgi) continue ;;
      esac
      if ! [ -r "$f" ] && printf '%s' "$f" | grep -q '/profile_set_[^/]*\.cgi$'; then
        # Generated profile endpoints can be replaced by the daemon during
        # reinstall. Refresh the endpoint and retry before declaring the
        # source unreadable.
        /opt/kzsc/bin/kzsc-presets-cgi.sh >/dev/null 2>&1 || true
      fi
      if awk -v p="$pattern" ' /^[[:space:]]*#/ {next} $0 ~ p {hit=1} END {exit !hit}' "$f"; then
        bad "Unexpected external application reference in KZSC source: ${f#"$ROOT/"}"
      else
        rc=$?
        if [ "$rc" -gt 1 ] && printf '%s' "$f" | grep -q '/profile_set_[^/]*\.cgi$'; then
          /opt/kzsc/bin/kzsc-presets-cgi.sh >/dev/null 2>&1 || true
          awk -v p="$pattern" ' /^[[:space:]]*#/ {next} $0 ~ p {hit=1} END {exit !hit}' "$f"
          rc=$?
        fi
        [ "$rc" -eq 1 ] || bad "Unable to inspect KZSC source: ${f#"$ROOT/"}"
      fi
      lower="$(printf '%s' "${f#"$ROOT/"}" | tr 'A-Z' 'a-z')"
      case "$lower" in *"$manager"*|"$prior"/*|*/"$prior".*) bad "Unexpected external application source name: $lower";; esac
    done
    IFS="$saved_ifs"
  done
  [ "$FAIL" -ne 0 ] || ok 'KZSC source references and source symlinks checked (read-only)'
}

external_check(){
  # Scope to known external installation/launcher/cache surfaces. These are
  # informational and deliberately not part of the KZSC source verdict.
  opt_root="${2:-/opt}"
  manager='k''zm'
  prior='k''sc'
  found=0
  for f in "$opt_root"/"$manager"* "$opt_root/bin"/"$manager"* \
    "$opt_root/etc/init.d"/S??"$manager"* "$opt_root/var/run"/"$manager"* \
    "$opt_root/$prior" "$opt_root/bin/$prior" "$opt_root/etc/init.d/S99$prior" \
    "$opt_root/zapret2"
  do
    [ -e "$f" ] || [ -L "$f" ] || continue
    warn "External application file exists; left untouched and excluded from KZSC source audit: $f"
    found=1
  done
  [ "$found" -ne 0 ] || ok 'No external application entries on checked paths'
  return 0
}

case "${1:-check}" in
  check)
    [ -d "$ROOT" ] && [ ! -L "$ROOT" ] || { bad "Invalid KZSC source root: $ROOT"; exit 1; }
    required_payload_check
    source_retired_scan
    ;;
  external) external_check "$@" ;;
  *) printf '%s\n' 'Usage: kzsc-purity {check [KZSC_ROOT]|external [OPT_ROOT]} (read-only)' >&2; exit 2 ;;
esac
exit "$FAIL"
