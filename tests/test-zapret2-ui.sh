#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail(){ printf 'FAIL: %s\n' "$1" >&2; exit 1; }

[ -f "$ROOT/opt/kzsc/www/cgi-bin/zapret2_check.cgi" ] || fail 'Zapret2 version-check CGI is missing'
[ -f "$ROOT/opt/kzsc/www/cgi-bin/zapret2_stop.cgi" ] || fail 'Zapret2 stop CGI is missing'
[ -f "$ROOT/opt/kzsc/www/cgi-bin/zapret2_start.cgi" ] || fail 'Zapret2 start CGI is missing'
[ -f "$ROOT/opt/kzsc/www/cgi-bin/zapret2_update_auto.cgi" ] || fail 'Zapret2 automatic update CGI is missing'
grep -q 'check) check' "$ROOT/opt/kzsc/bin/kzsc-zapret2.sh" || fail 'Zapret2 check command is missing'
grep -q 'auto-check)' "$ROOT/opt/kzsc/bin/kzsc-zapret2.sh" || fail 'Zapret2 automatic update check is missing'
grep -q 'KZSC_ZAPRET2_UPDATE_AUTO' "$ROOT/opt/kzsc/bin/kzsc-zapret2.sh" || fail 'Zapret2 automatic update setting is missing'
grep -q 'interval_seconds":1800' "$ROOT/opt/kzsc/bin/kzsc-zapret2.sh" || fail 'Zapret2 automatic update interval is not 30 minutes'
grep -q 'id="z2AutoUpdate"' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 automatic update checkbox is missing'
grep -q 'Check Zapret2 updates every 30 minutes' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 automatic update translation is missing'
grep -q 'z2CheckBtn' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 version-check button is missing'
grep -q 'Zapret2 IPv6 support' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 IPv6 English translation is missing'
grep -q 'Include IPv6 traffic in Zapret2 NFQUEUE engines' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 IPv6 hint translation is missing'
grep -q 'Check Zapret2 version' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 version-check translation is missing'
grep -q 'Stop Zapret2' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 stop translation is missing'
grep -q 'Start Zapret2' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 start translation is missing'
grep -q 'pause-all' "$ROOT/opt/kzsc/bin/kzsc-native-dpi.sh" || fail 'Zapret2 pause command is missing'
grep -q 'resume-all' "$ROOT/opt/kzsc/bin/kzsc-native-dpi.sh" || fail 'Zapret2 resume command is missing'
grep -q 'function renderZapret2Control' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 status does not use a shared renderer'
grep -q 'renderZapret2Control(z2,engines)' "$ROOT/opt/kzsc/www/index.html" || fail 'Maintenance refresh bypasses the shared Zapret2 renderer'
grep -q 'renderZapret2Control(z,latestEngines)' "$ROOT/opt/kzsc/www/index.html" || fail 'Panel refresh bypasses the shared Zapret2 renderer'
grep -q "box.dataset.loaded='1'" "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 panel does not preserve the last good status during transient refresh failures'

# Exercise the actual status producer. The automatic-update object added in
# v0.11.2.46 must close both its own object and the outer status object. Keep
# special characters in state fields so JSON escaping is covered as well.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
TEST_HOME="$TMP/kzsc-status"
mkdir -p "$TEST_HOME/etc" "$TEST_HOME/var/zapret2"
printf '%s\n' 'KZSC_ZAPRET2_UPDATE_AUTO="1"' >"$TEST_HOME/etc/kzsc.conf"
printf '%s\n' 'v99.1.0' >"$TEST_HOME/var/zapret2/auto_latest"
printf '%s\n' 'release "lookup" failed: C:\tmp' >"$TEST_HOME/var/zapret2/auto_error"
KZSC_HOME="$TEST_HOME" \
KZSC_LIB="$ROOT/opt/kzsc/bin/kzsc-lib.sh" \
  sh "$ROOT/opt/kzsc/bin/kzsc-zapret2.sh" status >"$TMP/status.json"

KZSC_HOME="$TEST_HOME" \
KZSC_LIB="$ROOT/opt/kzsc/bin/kzsc-lib.sh" \
KZSC_ZAPRET2_BIN="$ROOT/opt/kzsc/bin/kzsc-zapret2.sh" \
KZSC_SH=sh \
QUERY_STRING=status \
  sh "$ROOT/opt/kzsc/www/cgi-bin/zapret2_update_auto.cgi" >"$TMP/status.cgi"

if command -v python3 >/dev/null 2>&1; then
  KZSC_TEST_PYTHON=python3
elif command -v python >/dev/null 2>&1; then
  KZSC_TEST_PYTHON=python
else
  fail 'Python is required to validate Zapret2 JSON output'
fi

"$KZSC_TEST_PYTHON" - "$TMP/status.json" "$TMP/status.cgi" <<'PY'
import json
import pathlib
import sys

status = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert status["auto_update"]["enabled"] is True
assert status["auto_update"]["interval_seconds"] == 1800
assert status["auto_update"]["latest"] == "v99.1.0"
assert status["auto_update"]["last_error"] == 'release "lookup" failed: C:\\tmp'

raw = pathlib.Path(sys.argv[2]).read_bytes()
headers, body = raw.split(b"\r\n\r\n", 1)
assert b"Content-Type: application/json" in headers
wrapped = json.loads(body)
assert wrapped["ok"] is True
assert wrapped["status"] == status
PY

printf '%s\n' 'Zapret2 UI bilingual contract: OK'
