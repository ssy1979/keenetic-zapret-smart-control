#!/opt/bin/sh
. "${KZSC_LIB:-/opt/kzsc/bin/kzsc-lib.sh}"

CGI="$KZSC_HOME/www/cgi-bin"
QUEUE="$KZSC_HOME/var/run/maintenance-queue"
mkdir -p "$CGI"

# The daemon, installer and audits may refresh endpoints concurrently. Serialize
# writers and keep the active endpoints in place until their atomic replacement
# is ready; otherwise an audit/UI request can observe the old delete-create gap.
LOCK_NAME="blockcheck-cgi"
kzsc_lock_acquire "$LOCK_NAME" || exit 1
LOCK_HELD=1
cleanup(){
  [ "$LOCK_HELD" -eq 1 ] || return 0
  LOCK_HELD=0
  rm -f "$CGI"/blockcheck_start_*.cgi.tmp.$$ \
        "$CGI"/blockcheck_stop_*.cgi.tmp.$$ 2>/dev/null || true
  kzsc_lock_release "$LOCK_NAME"
}
trap 'cleanup' EXIT
trap 'cleanup; exit 1' INT TERM HUP

safe_id(){
  printf '%s' "$1" | tr ' A-Z/:.' '_a-z___' | tr -cd 'a-z0-9_-'
}

write_stop_ep(){
  path="$1"; nd="$2"
  tmp="$path.tmp.$$"
  if ! cat >"$tmp" <<EOF
#!/opt/bin/sh
ACTION="blockcheck_stop:$nd"
QUEUE="$QUEUE"
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
[ -d "\$QUEUE" ] || { printf '{"ok":false,"error":"maintenance_queue_unavailable"}\n'; exit 0; }
TS="\$(date +%s)"; RID="blockcheck_stop-\${TS}-\$\$"
req="\$QUEUE/req.\${TS}.\$\$"
umask 022
if printf '%s|%s\n' "\$RID" "\$ACTION" >"\$req"; then
  printf '{"ok":true,"queued":true,"action":"blockcheck_stop","request_id":"%s","message":"Durdurma isteği gönderildi."}\n' "\$RID"
else
  printf '{"ok":false,"error":"queue_write_failed"}\n'
fi
EOF
  then
    rm -f "$tmp" 2>/dev/null || true
    return 1
  fi
  chmod 755 "$tmp" && mv -f "$tmp" "$path" || {
    rm -f "$tmp" 2>/dev/null || true
    return 1
  }
}

write_start_ep(){
  path="$1"; nd="$2"
  tmp="$path.tmp.$$"
  if ! cat >"$tmp" <<EOF
#!/opt/bin/sh
QUEUE="$QUEUE"
NDMC="$nd"
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
[ -d "\$QUEUE" ] || { printf '{"ok":false,"error":"maintenance_queue_unavailable"}\n'; exit 0; }

# Fixed CGI endpoint is retained. Dynamic Blockcheck target arrives in a
# standard CGI HTTP header environment variable. Header-less calls default
# to pastebin.com. Remove queue delimiters/control chars and cap input length.
DOMAINS="\${HTTP_X_KZSC_BLOCKCHECK_DOMAINS:-pastebin.com}"
DOMAINS="\$(printf '%s' "\$DOMAINS" | tr ',' ' ' | tr -d '\r\n|' | cut -c1-240 | tr -s ' ')"
[ -n "\$DOMAINS" ] || DOMAINS="pastebin.com"

SCAN="\${HTTP_X_KZSC_BLOCKCHECK_SCANLEVEL:-quick}"
case "\$SCAN" in quick|standard|force) : ;; *) SCAN="quick" ;; esac

ACTION="blockcheck_start:\$NDMC:\$SCAN:\$DOMAINS"
TS="\$(date +%s)"; RID="blockcheck_start-\${TS}-\$\$"
req="\$QUEUE/req.\${TS}.\$\$"
umask 022
if printf '%s|%s\n' "\$RID" "\$ACTION" >"\$req"; then
  printf '{"ok":true,"queued":true,"action":"blockcheck_start","request_id":"%s","message":"Blockcheck isteği gönderildi."}\n' "\$RID"
else
  printf '{"ok":false,"error":"queue_write_failed"}\n'
fi
EOF
  then
    rm -f "$tmp" 2>/dev/null || true
    return 1
  fi
  chmod 755 "$tmp" && mv -f "$tmp" "$path" || {
    rm -f "$tmp" 2>/dev/null || true
    return 1
  }
}

active_ids=" "
generation_ok=1
for nd in $(internet_wans); do
  id="$(safe_id "$nd")"
  [ -n "$id" ] || continue
  active_ids="$active_ids$id "
  write_start_ep "$CGI/blockcheck_start_$id.cgi" "$nd" || generation_ok=0
  write_stop_ep "$CGI/blockcheck_stop_$id.cgi" "$nd" || generation_ok=0
done

# Do not discard a previously working set if this refresh could not finish.
[ "$generation_ok" -eq 1 ] || exit 1

# WAN identities are dynamic. Remove only endpoints whose sanitized identity is
# no longer present, after every active endpoint has been replaced successfully.
for path in "$CGI"/blockcheck_start_*.cgi "$CGI"/blockcheck_stop_*.cgi; do
  [ -e "$path" ] || continue
  name="${path##*/}"
  sid="${name%.cgi}"
  case "$sid" in
    blockcheck_start_*) sid="${sid#blockcheck_start_}" ;;
    blockcheck_stop_*) sid="${sid#blockcheck_stop_}" ;;
    *) continue ;;
  esac
  case "$active_ids" in
    *" $sid "*) : ;;
    *) rm -f "$path" 2>/dev/null || true ;;
  esac
done
