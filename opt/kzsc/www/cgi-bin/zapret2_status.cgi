#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'

# The status artifact is normally refreshed by the daemon.  Generate it on
# demand as a fallback so a freshly installed router never leaves the panel
# stuck at "Loading" when the daemon has not completed its first cycle.
out="$(/opt/kzsc/bin/kzsc-zapret2.sh status 2>/dev/null | tail -n1)"
[ -n "$out" ] && printf '%s\n' "$out" || printf '{"installed":false,"error":"Zapret2 status unavailable."}\n'
