#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
AUDIT="$ROOT/opt/kzsc/bin/kzsc-audit.sh"
PURITY="$ROOT/opt/kzsc/bin/kzsc-purity.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM HUP
die(){ printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok(){ printf 'OK   %s\n' "$*"; }
bad(){ printf 'FAIL %s\n' "$*"; fail=1; }
warn(){ printf 'WARN %s\n' "$*"; }

# Exercise the shipped functions in a temporary, deterministic runtime. No
# router /opt, process signals, firewall updates, or source bypass are needed.
sed -n '/^reconcilecheck(){/,/^runtime(){/p' "$AUDIT" | sed '$d' >"$TMP/functions.sh"
. "$TMP/functions.sh"
KZSC_HOME="$TMP/runtime"
mkdir -p "$KZSC_HOME/var/reconcile/pending" "$KZSC_HOME/var/blockcheck/pppoe0"
job="$KZSC_HOME/var/blockcheck/pppoe0"
pending="$KZSC_HOME/var/reconcile/pending/pppoe0.pending"
now="$(date +%s)"
printf 'PPPoE0\tProvider\tppp0\tprofile_missing\t0\t%s\n' "$now" >"$pending"
printf 'manual\n' >"$job/source"
printf 'idle\n' >"$job/state"
iface_state(){ printf 'up\n'; }
ps(){ printf '%s\n' "${TEST_PS:-}"; }
printf '#!/bin/sh\nprintf "%%s\\n" "${TEST_CHAINS:-}"\n' >"$TMP/iptables-save"
chmod +x "$TMP/iptables-save"
PATH="$TMP:$PATH"
export PATH TEST_CHAINS

fail=0
reconcilecheck '{"pending":1}' >"$TMP/pending.out"
[ "$fail" -eq 0 ] && grep -q '^WARN ' "$TMP/pending.out" || die 'initial asynchronous pending WAN was rejected'
printf 'wan_reconcile\n' >"$job/source"
printf '%s\n' "$now" >"$job/ended"
for state in failed timeout restore_failed blocked; do
  printf '%s\n' "$state" >"$job/state"
  fail=0
  reconcilecheck '{"pending":1}' >"$TMP/failed.out"
  [ "$fail" -eq 1 ] || die "current WAN validation failure was hidden: $state"
done
# A previous failed attempt must not reject a newer queued attempt.
printf '%s\n' "$((now-30))" >"$job/ended"
fail=0
reconcilecheck '{"pending":1}' >/dev/null
[ "$fail" -eq 0 ] || die 'historical WAN failure rejected a newer attempt'
fail=0
reconcilecheck '{"pending":"broken"}' >/dev/null
[ "$fail" -eq 1 ] || die 'malformed reconcile status accepted'
fail=0
reconcilecheck '{"pending":0}' >/dev/null
[ "$fail" -eq 0 ] || die 'completed WAN reconcile rejected'

TEST_PS="456 root /opt/bin/sh $KZSC_HOME/var/blockcheck/pppoe0/run/blockcheck2.sh"
TEST_CHAINS=':blockcheck_output_456 - [0:0]'
fail=0
blockcheckcheck '{"running":1}' >"$TMP/active.out"
[ "$fail" -eq 0 ] && grep -q '^WARN ' "$TMP/active.out" || die 'active Blockcheck treated as stale'
fail=0
blockcheckcheck '{"running":0}' >/dev/null
[ "$fail" -eq 1 ] || die 'orphaned KZSC Blockcheck process ignored'
TEST_PS='789 root /opt/unrelated/run/blockcheck2.sh'
fail=0
blockcheckcheck '{"running":0}' >"$TMP/foreign.out"
[ "$fail" -eq 0 ] || die 'unrelated Blockcheck process rejected KZSC'
fail=0
blockcheckcheck 'invalid' >/dev/null
[ "$fail" -eq 1 ] || die 'malformed Blockcheck status accepted'

# Run the real CGI allowlist against every shipped static endpoint, then
# prove an unknown endpoint still fails the same gate.
mkdir -p "$KZSC_HOME/www/cgi-bin"
cp "$ROOT/opt/kzsc/www/cgi-bin/"* "$KZSC_HOME/www/cgi-bin/"
awk '/^  unexpected_cgi=0/{capture=1} capture{print} /ok "KZSC CGI allow-list temiz"/{exit}' "$AUDIT" >"$TMP/cgi-check.sh"
fail=0
. "$TMP/cgi-check.sh" >"$TMP/cgi.out"
[ "$fail" -eq 0 ] || { cat "$TMP/cgi.out"; die 'shipped CGI endpoint missing from audit allowlist'; }
printf 'unexpected\n' >"$KZSC_HOME/www/cgi-bin/unexpected.cgi"
fail=0
. "$TMP/cgi-check.sh" >/dev/null
[ "$fail" -eq 1 ] || die 'unknown CGI endpoint was accepted'

cp -R "$ROOT/opt/kzsc" "$TMP/source"
sh "$PURITY" check "$TMP/source" >"$TMP/purity.out" || { cat "$TMP/purity.out"; die 'complete first-party source rejected'; }
mkdir -p "$TMP/external/var/run"
printf 'unrelated cache must be preserved\n' >"$TMP/external/var/run/kzm2_iss.cache"
before="$(sha256sum "$TMP/external/var/run/kzm2_iss.cache")"
sh "$PURITY" external "$TMP/external" >"$TMP/external.out"
[ "$before" = "$(sha256sum "$TMP/external/var/run/kzm2_iss.cache")" ] || die 'read-only external check modified another application cache'
grep -q '^WARN ' "$TMP/external.out" || die 'external cache was not reported'
printf '#!/bin/sh\n/opt/kzm2/bin/foreign.sh\n' >"$TMP/source/bin/foreign-test.sh"
if sh "$PURITY" check "$TMP/source" >/dev/null 2>&1; then die 'external source coupling was accepted'; fi
rm -f "$TMP/source/bin/foreign-test.sh"
ln -s "$TMP/external/var/run/kzm2_iss.cache" "$TMP/source/bin/unsafe-link"
if [ -L "$TMP/source/bin/unsafe-link" ]; then
  if sh "$PURITY" check "$TMP/source" >/dev/null 2>&1; then die 'unsafe source symlink was accepted'; fi
else
  case "$(uname -s)" in
    MINGW*|MSYS*) printf '%s\n' 'SKIP native symlink fixture: Git Bash copied the file; Linux CI exercises this case' ;;
    *) die 'test filesystem cannot create the required symlink fixture' ;;
  esac
fi
rm -f "$TMP/source/bin/unsafe-link"

# The installer now has a read-only payload mode. It must reject incomplete
# inputs before bootstrap/service mutation, including the once-missing purity
# backend and newly added CGI endpoints.
mkdir -p "$TMP/package/opt"
cp "$ROOT/install.sh" "$TMP/package/install.sh"
cp -R "$ROOT/opt/kzsc" "$TMP/package/opt/kzsc"
cp -R "$ROOT/opt/etc" "$TMP/package/opt/etc"
sh "$TMP/package/install.sh" --verify-payload >"$TMP/package.out" || { cat "$TMP/package.out"; die 'complete installer payload rejected'; }
for item in bin/kzsc-purity.sh www/cgi-bin/kzsc_uninstall.cgi share/dpi-presets/tt-fiber.conf; do
  mv "$TMP/package/opt/kzsc/$item" "$TMP/removed"
  if sh "$TMP/package/install.sh" --verify-payload >/dev/null 2>&1; then die "incomplete payload accepted: $item"; fi
  mv "$TMP/removed" "$TMP/package/opt/kzsc/$item"
done
if sh "$TMP/package/install.sh" --remove-retired >/dev/null 2>&1; then die 'legacy external removal mode accepted'; fi
grep -Fq 'if ! /opt/kzsc/bin/kzsc-audit.sh full; then' "$ROOT/install.sh" || die 'installer does not run final full audit'
KZSC_HOME="$ROOT/opt/kzsc" KZSC_LIB="$ROOT/opt/kzsc/bin/kzsc-lib.sh" \
  sh "$AUDIT" version >"$TMP/version.out" || { cat "$TMP/version.out"; die 'release version consistency audit failed'; }
printf '%s\n' 'Audit / read-only ownership / installation payload regression suite: OK'
