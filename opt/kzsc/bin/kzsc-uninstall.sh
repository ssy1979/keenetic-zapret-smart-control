#!/opt/bin/sh
set -u
PURGE=0; [ "${1:-}" = "--purge" ] && PURGE=1
[ -x /opt/kzsc/bin/kzsc-dns.sh ] && /opt/kzsc/bin/kzsc-dns.sh disable >/dev/null 2>&1 || true
[ -x /opt/etc/init.d/S99kzsc ] && /opt/etc/init.d/S99kzsc stop >/dev/null 2>&1 || true
rm -f /opt/bin/kzsc /opt/etc/init.d/S99kzsc
if [ "$PURGE" -eq 1 ]; then
  rm -rf /opt/kzsc
  echo "KZSC tamamen kaldırıldı."
else
  b="/opt/kzsc-backup-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$b"
  cp -R /opt/kzsc/etc "$b/" 2>/dev/null || true
  cp -R /opt/kzsc/var/lib "$b/" 2>/dev/null || true
  rm -rf /opt/kzsc
  echo "KZSC kaldırıldı. Ayar/politika yedeği: $b"
fi

