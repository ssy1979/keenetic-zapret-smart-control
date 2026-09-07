#!/opt/bin/sh
. "${KZSC_LIB:-/opt/kzsc/bin/kzsc-lib.sh}"

QUEUE="$KZSC_HOME/var/run/maintenance-queue"
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
[ -d "$QUEUE" ] || { printf '{"ok":false,"error":"maintenance_queue_unavailable"}\n'; exit 0; }

body=""
[ "${REQUEST_METHOD:-GET}" = POST ] && body="$(cat 2>/dev/null)"
data="${QUERY_STRING:+$QUERY_STRING&}$body"

urldecode(){
  # POSIX sh/dash does not require printf %b to understand \xHH escapes.
  # Decode form bytes in awk instead, while leaving encoded control bytes
  # literal so a request cannot inject extra key/value payload lines.
  printf '%s' "$1" | awk '
    function hex(c){ return index("0123456789ABCDEF", toupper(c))-1 }
    {
      out=""
      for(i=1;i<=length($0);i++){
        c=substr($0,i,1)
        if(c=="+"){ out=out " "; continue }
        if(c=="%" && i+2<=length($0)){
          hi=hex(substr($0,i+1,1)); lo=hex(substr($0,i+2,1))
          if(hi>=0 && lo>=0){
            n=hi*16+lo
            if(n>=32 && n!=127){ out=out sprintf("%c",n); i+=2; continue }
          }
        }
        out=out c
      }
      printf "%s",out
    }
  '
}
param(){
  local wanted="$1" pair key val oldifs
  oldifs="$IFS"; IFS='&'
  for pair in $data; do
    key="${pair%%=*}"; [ "$key" = "$wanted" ] || continue
    val="$(urldecode "${pair#*=}")"; IFS="$oldifs"; printf '%s' "$val"; return
  done
  IFS="$oldifs"
}

action="$(param action)"; wan="$(param wan)"; list="$(param list)"; domain="$(param domain)"; mac="$(param mac)"; value="$(param value)"; ip="$(param ip)"
case "$action" in mode|add|remove|device|static) :;; *) printf '{"ok":false,"error":"invalid_dpi_policy_action"}\n'; exit 0;; esac

ts="$(date +%s)"; rid="dpi_policy-${ts}-$$"; req="$QUEUE/req.${ts}.$$"; payload="$QUEUE/payload.$rid"
if {
  printf 'action=%s\nwan=%s\nlist=%s\ndomain=%s\nmac=%s\nvalue=%s\nip=%s\n' "$action" "$wan" "$list" "$domain" "$mac" "$value" "$ip"
} >"$payload" && printf '%s|dpi_policy:%s\n' "$rid" "$action" >"$req"; then
  printf '{"ok":true,"queued":true,"action":"dpi_policy_%s","request_id":"%s"}\n' "$action" "$rid"
else
  rm -f "$payload" "$req" 2>/dev/null || true
  printf '{"ok":false,"error":"queue_write_failed"}\n'
fi
