#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/kzsc-registered-clients.$$"
HOME_DIR="$TMP/home"
MOCK="$TMP/mock"
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$HOME_DIR/var/dpi-policy/devices" "$MOCK"

cat >"$MOCK/ndmc" <<'EOF'
#!/bin/sh
case "$*" in
  'show ip hotspot')
    cat <<'HOSTS'
host:
  mac: AA:BB:CC:DD:EE:01
  ip: 192.168.1.20
  name: Online laptop
  active: yes
host:
  mac: AA:BB:CC:DD:EE:02
  ip: 192.168.1.50
  name: Offline tablet
  active: no
host:
  mac: AA:BB:CC:DD:EE:03
  name: Offline no-IP device
  active: no
HOSTS
    ;;
  'show ip route') : ;;
  *) : ;;
esac
EOF
cat >"$MOCK/ip" <<'EOF'
#!/bin/sh
case "$*" in
  '-4 -o addr show') printf '2 br0    inet 192.168.1.1/24 brd 192.168.1.255 scope global br0\n' ;;
  '-4 neigh show') printf '192.168.1.20 dev br0 lladdr aa:bb:cc:dd:ee:01 REACHABLE\n' ;;
  *) : ;;
esac
EOF
chmod +x "$MOCK/ndmc" "$MOCK/ip"

cat >"$TMP/lib.sh" <<EOF
#!/bin/sh
. "$ROOT/opt/kzsc/bin/kzsc-lib.sh"
EOF
chmod +x "$TMP/lib.sh"

# Device preferences are MAC-based; a disabled preference must persist while
# the client is offline and apply when the device reconnects.
printf 'disabled\n' >"$HOME_DIR/var/dpi-policy/devices/aabbccddee02.mode"
PATH="$MOCK:$PATH" KZSC_HOME="$HOME_DIR" KZSC_LIB="$TMP/lib.sh" \
  sh "$ROOT/opt/kzsc/bin/kzsc-clients.sh" >"$TMP/out.json"

JSON="$HOME_DIR/var/clients.json"
[ "$(grep -o '"mac":"[^"]*"' "$JSON" | wc -l | tr -d ' ')" = 3 ] || { echo 'FAIL: registered clients missing' >&2; exit 1; }
grep -q '"name":"Online laptop".*"online":true,"registered":true' "$JSON" || { echo 'FAIL: online registered client missing' >&2; exit 1; }
grep -q '"name":"Offline tablet".*"state":"offline".*"online":false,"registered":true' "$JSON" || { echo 'FAIL: offline registered client missing' >&2; exit 1; }
grep -q '"name":"Offline tablet".*"zapret_enabled":false' "$JSON" || { echo 'FAIL: offline device preference missing' >&2; exit 1; }
grep -q '"name":"Offline no-IP device".*"ipv4":"".*"online":false' "$JSON" || { echo 'FAIL: MAC-only registered client missing' >&2; exit 1; }
echo 'Registered/offline client inventory regression suite: OK'
