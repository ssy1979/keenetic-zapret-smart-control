#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BOOTSTRAP="$ROOT/opt/kzsc/bin/kzsc-bootstrap.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM HUP

fail(){ printf 'FAIL: %s\n' "$1" >&2; exit 1; }

cat >"$TMP/version-missing.txt" <<'EOF'
components: base,opkg,dns-tls,dns-https
EOF
missing="$(KZSC_BOOTSTRAP_VERSION_FILE="$TMP/version-missing.txt" sh "$BOOTSTRAP" missing-components)"
[ "$missing" = 'opkg-kmod-netfilter opkg-kmod-netfilter-addons' ] || fail 'missing Keenetic component detection'

cat >"$TMP/version-complete.txt" <<'EOF'
components: base,opkg,dns-tls,dns-https,opkg-kmod-netfilter,opkg-kmod-netfilter-addons
EOF
[ -z "$(KZSC_BOOTSTRAP_VERSION_FILE="$TMP/version-complete.txt" sh "$BOOTSTRAP" missing-components)" ] \
  || fail 'complete Keenetic component detection'

# Actual Keenetic output includes additional metadata around the components;
# the bootstrap detector must agree with the pre-flight parser.
cat >"$TMP/version-router.txt" <<'EOF'
model: Titan (KN-1812)
components: base, opkg, pppoe, dns-tls, dns-https, opkg-kmod-netfilter, opkg-kmod-netfilter-addons
EOF
[ -z "$(KZSC_BOOTSTRAP_VERSION_FILE="$TMP/version-router.txt" sh "$BOOTSTRAP" missing-components)" ] \
  || fail 'router component output was incorrectly treated as incomplete'

cat >"$TMP/ndmc" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$MOCK_NDMC_LOG"
printf '%s\n' 'Core::Configurator: Done.'
EOF
command -v chmod >/dev/null 2>&1 && chmod +x "$TMP/ndmc"
MOCK_NDMC_LOG="$TMP/ndmc.log" KZSC_NDMC="$TMP/ndmc" sh "$BOOTSTRAP" \
  install-components opkg-kmod-netfilter opkg-kmod-netfilter-addons >/dev/null
grep -Fq -- '-c components install opkg-kmod-netfilter' "$TMP/ndmc.log" || fail 'netfilter component install command'
grep -Fq -- '-c components install opkg-kmod-netfilter-addons' "$TMP/ndmc.log" || fail 'netfilter addons install command'
grep -Fq -- '-c components preview' "$TMP/ndmc.log" || fail 'component preview command'
grep -Fq -- '-c components commit' "$TMP/ndmc.log" || fail 'component commit command'
if MOCK_NDMC_LOG="$TMP/ndmc.log" KZSC_NDMC="$TMP/ndmc" sh "$BOOTSTRAP" install-components unsafe-name >/dev/null 2>&1; then
  fail 'component allowlist accepted an unsafe name'
fi

cat >"$TMP/opkg" <<'EOF'
#!/bin/sh
case "${1:-}" in
  list-installed)
    cat "$MOCK_OPKG_STATE" 2>/dev/null || true
    ;;
  update)
    printf '%s\n' update >>"$MOCK_OPKG_LOG"
    ;;
  install)
    shift
    printf 'install' >>"$MOCK_OPKG_LOG"
    for package in "$@"; do
      printf ' %s' "$package" >>"$MOCK_OPKG_LOG"
      printf '%s - 1.0\n' "$package" >>"$MOCK_OPKG_STATE"
    done
    printf '\n' >>"$MOCK_OPKG_LOG"
    [ "${MOCK_FAIL_INSTALL:-0}" != 1 ]
    ;;
  *) exit 2 ;;
esac
EOF
command -v chmod >/dev/null 2>&1 && chmod +x "$TMP/opkg"
: >"$TMP/opkg.state"
: >"$TMP/opkg.log"
export MOCK_OPKG_STATE="$TMP/opkg.state" MOCK_OPKG_LOG="$TMP/opkg.log"
KZSC_OPKG="$TMP/opkg" KZSC_OPT_ROOT="$TMP/opt" sh "$BOOTSTRAP" ensure-packages >/dev/null

packages="$(sh "$BOOTSTRAP" requirements | sed -n 's/^packages://p')"
for package in $packages; do
  grep -q "^${package} - " "$TMP/opkg.state" || fail "package was not installed: $package"
done
before="$(wc -l <"$TMP/opkg.log")"
KZSC_OPKG="$TMP/opkg" KZSC_OPT_ROOT="$TMP/opt" sh "$BOOTSTRAP" ensure-packages >/dev/null
after="$(wc -l <"$TMP/opkg.log")"
[ "$before" -eq "$after" ] || fail 'package bootstrap is not idempotent'

: >"$TMP/opkg.state"
if MOCK_FAIL_INSTALL=1 KZSC_OPKG="$TMP/opkg" KZSC_OPT_ROOT="$TMP/opt" \
  sh "$BOOTSTRAP" ensure-packages >/dev/null 2>&1; then
  fail 'package installation failure did not fail closed'
fi

install_file="$ROOT/install.sh"
grep -Fq 'kzsc-bootstrap.sh' "$install_file" || fail 'installer does not invoke bootstrap'
component_line="$(grep -n 'missing-components)' "$BOOTSTRAP" | head -n1 | cut -d: -f1)"
[ -n "$component_line" ] || fail 'bootstrap component action missing'
ensure_line="$(grep -n '"$BOOTSTRAP" ensure-packages' "$install_file" | head -n1 | cut -d: -f1)"
preflight_line="$(grep -n 'kzsc-preflight.sh" install' "$install_file" | head -n1 | cut -d: -f1)"
[ "$ensure_line" -lt "$preflight_line" ] || fail 'Entware packages are not completed before preflight'
grep -Fq 'S98kzsc-bootstrap-resume' "$install_file" || fail 'post-reboot automatic resume hook missing'
grep -Fq 'kzsc-bootstrap-resume-package' "$install_file" || fail 'durable post-reboot installer copy missing'
grep -Fq 'cp -R "$SRC/opt" "$RESUME_PACKAGE/opt"' "$install_file" || fail 'resume payload does not preserve router files'
grep -Fq '[ -r "$RESUME_PACKAGE/opt/kzsc/bin/kzsc-bootstrap.sh" ]' "$install_file" \
  || fail 'resume payload incorrectly requires executable source mode'

printf '%s\n' 'Installer bootstrap regression suite: OK'
