#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

for path in \
    docs/INSTALLATION.md \
    docs/KURULUM.md \
    docs/images/kurulum-akisi.svg \
    tools/kzsc-hazirlayici/app.py \
    tools/kzsc-hazirlayici/core.py \
    tools/kzsc-hazirlayici/profile.json \
    tools/kzsc-hazirlayici/tests/test_core.py
do
    [ -f "$path" ] || fail "protected project file is missing: $path"
done

for backend in \
    kzsc-daemon.sh kzsc-discover.sh kzsc-reconcile.sh kzsc-clients.sh \
    kzsc-isolation.sh kzsc-wan-registry.sh kzsc-native-dpi.sh \
    kzsc-maintenance.sh kzsc-updater.sh
do
    [ -f "opt/kzsc/bin/$backend" ] || fail "required KZSC backend is missing: $backend"
done

[ "$(grep -c '^<!-- KZSC_PREPARER_START:' README.md)" -eq 1 ] || fail 'README.md preparer start marker is missing or duplicated'
[ "$(grep -c '^<!-- KZSC_PREPARER_END -->$' README.md)" -eq 1 ] || fail 'README.md preparer end marker is missing or duplicated'
[ "$(grep -c '^<!-- KZSC_HAZIRLAYICI_START:' README.tr.md)" -eq 1 ] || fail 'README.tr.md preparer start marker is missing or duplicated'
[ "$(grep -c '^<!-- KZSC_HAZIRLAYICI_END -->$' README.tr.md)" -eq 1 ] || fail 'README.tr.md preparer end marker is missing or duplicated'

grep -q -- '--exclude=docs' .github/workflows/release.yml || fail 'router release no longer excludes docs'
grep -q -- '--exclude=tools' .github/workflows/release.yml || fail 'router release no longer excludes preparer sources'
grep -q '^  windows-preparer:$' .github/workflows/release.yml || fail 'Windows preparer release job is missing'
grep -q 'KZSC-Hazirlayici-v\*\.zip' .github/workflows/release.yml || fail 'Windows preparer asset rule is missing'

printf '%s\n' 'Repository ownership contract: OK'
