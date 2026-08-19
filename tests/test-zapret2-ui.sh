#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail(){ printf 'FAIL: %s\n' "$1" >&2; exit 1; }

[ -f "$ROOT/opt/kzsc/www/cgi-bin/zapret2_check.cgi" ] || fail 'Zapret2 version-check CGI is missing'
[ -f "$ROOT/opt/kzsc/www/cgi-bin/zapret2_stop.cgi" ] || fail 'Zapret2 stop CGI is missing'
[ -f "$ROOT/opt/kzsc/www/cgi-bin/zapret2_start.cgi" ] || fail 'Zapret2 start CGI is missing'
grep -q 'check) check' "$ROOT/opt/kzsc/bin/kzsc-zapret2.sh" || fail 'Zapret2 check command is missing'
grep -q 'z2CheckBtn' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 version-check button is missing'
grep -q 'Zapret2 IPv6 support' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 IPv6 English translation is missing'
grep -q 'Include IPv6 traffic in Zapret2 NFQUEUE engines' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 IPv6 hint translation is missing'
grep -q 'Check Zapret2 version' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 version-check translation is missing'
grep -q 'Stop Zapret2' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 stop translation is missing'
grep -q 'Start Zapret2' "$ROOT/opt/kzsc/www/index.html" || fail 'Zapret2 start translation is missing'
grep -q 'pause-all' "$ROOT/opt/kzsc/bin/kzsc-native-dpi.sh" || fail 'Zapret2 pause command is missing'
grep -q 'resume-all' "$ROOT/opt/kzsc/bin/kzsc-native-dpi.sh" || fail 'Zapret2 resume command is missing'
printf '%s\n' 'Zapret2 UI bilingual contract: OK'
