#!/opt/bin/sh
set -u
PURGE=0; [ "${1:-}" = "--purge" ] && PURGE=1
# Preserve the router's DNS configuration.  Uninstall only stops/removes KZSC.
[ -x /opt/etc/init.d/S99kzsc ] && /opt/etc/init.d/S99kzsc stop >/dev/null 2>&1 || true
rm -f /opt/bin/kzsc /opt/etc/init.d/S99kzsc
if [ "$PURGE" -eq 1 ]; then
  # Full removal is intentionally limited to KZSC-owned paths.  Do not touch
  # the Entware base or unrelated packages under /opt.
  for p in /opt/kzsc-backup-* /opt/etc/init.d/S98kzsc-bootstrap-resume; do
    [ -e "$p" ] && rm -rf "$p"
  done
  rm -f /tmp/kzsc-telegram-req.* /tmp/kzsc-telegram-payload.* /tmp/kzsc-backup-req.* /tmp/kzsc-backup-upload.* 2>/dev/null || true
  rm -rf /opt/kzsc
  echo "KZSC tamamen kaldırıldı."
else
  b="/opt/kzsc-backup-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$b"
  cp -R /opt/kzsc/etc "$b/" 2>/dev/null || true
  cp -R /opt/kzsc/var/lib "$b/" 2>/dev/null || true
  rm -rf /opt/kzsc
  echo "KZSC kaldırıldı. Ayar/politika yedeği: $b"
fi

