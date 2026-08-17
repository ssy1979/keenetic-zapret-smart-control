#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh
STORE="$KZSC_HOME/var/log/operation-log.ndjson"
PUBLIC="$KZSC_HOME/www/data/operation-log.ndjson"
mkdir -p "$KZSC_HOME/var/log" "$KZSC_HOME/www/data"
bool(){ case "$1" in true|1|yes|ok) echo true;; *) echo false;; esac; }
publish_unlocked(){
 [ -f "$STORE" ] || : >"$STORE"
 rm -f "$PUBLIC.tmp.$$" 2>/dev/null || true
 tail -n 500 "$STORE" >"$PUBLIC.tmp.$$" 2>/dev/null || : >"$PUBLIC.tmp.$$"
 mv "$PUBLIC.tmp.$$" "$PUBLIC"; chmod 644 "$PUBLIC" 2>/dev/null || true
}
publish(){
 kzsc_lock_acquire oplog || return 1
 publish_unlocked
 rc=$?
 kzsc_lock_release oplog
 return "$rc"
}
append(){
 action="$1"; ok="$(bool "$2")"; msg="$3"; rid="$4"; ts="${5:-$(date +%s)}"; notify="${6:-1}"
 msg="$(printf '%s' "$msg" | tr '\r\n' '  ')"
 line="$(printf '{"request_id":"%s","action":"%s","ok":%s,"message":"%s","timestamp":%s}' \
   "$(json_escape "$rid")" "$(json_escape "$action")" "$ok" "$(json_escape "$msg")" "$ts")"
 kzsc_lock_acquire oplog || return 1
 printf '%s\n' "$line" >>"$STORE" || { kzsc_lock_release oplog; return 1; }
 n="$(wc -l <"$STORE" 2>/dev/null | tr -d ' ')"; case "$n" in ''|*[!0-9]*) n=0;; esac
 if [ "$n" -gt 500 ]; then
   tail -n 500 "$STORE" >"$STORE.tmp.$$" && mv "$STORE.tmp.$$" "$STORE" \
     || { rm -f "$STORE.tmp.$$"; kzsc_lock_release oplog; return 1; }
 fi
 publish_unlocked
 rc=$?
 kzsc_lock_release oplog
 [ "$rc" -eq 0 ] || return "$rc"
 if [ "$notify" = 1 ] && [ -x /opt/kzsc/bin/kzsc-telegram.sh ]; then
   /opt/kzsc/bin/kzsc-telegram.sh notify-event "$action" "$ok" "$msg" >/dev/null 2>&1 &
 fi
}
clear_log(){
  mkdir -p "$KZSC_HOME/var/log" "$KZSC_HOME/www/data"
  kzsc_lock_acquire oplog || return 1
  : > "$STORE"
  : > "$PUBLIC"
  chmod 644 "$STORE" "$PUBLIC" 2>/dev/null || true
  kzsc_lock_release oplog
}

sanitize_log(){
  kzsc_lock_acquire oplog || return 1
  [ -f "$STORE" ] || { : >"$STORE"; publish_unlocked; rc=$?; kzsc_lock_release oplog; return "$rc"; }
  tmp="$STORE.sanitize.$$"
  awk '
    /^\{.*\}$/ && /"timestamp":[0-9]+/ && /"action":"/ && /"ok":(true|false)/ { print }
  ' "$STORE" >"$tmp" 2>/dev/null || { rm -f "$tmp"; kzsc_lock_release oplog; return 1; }
  tail -n 500 "$tmp" >"$STORE" 2>/dev/null || : >"$STORE"
  rm -f "$tmp"
  publish_unlocked
  rc=$?
  kzsc_lock_release oplog
  return "$rc"
}

reconcile(){
  kzsc_lock_acquire oplog || return 1
  [ -f "$STORE" ] || { publish_unlocked; rc=$?; kzsc_lock_release oplog; return "$rc"; }
  tmp="$STORE.reconcile.$$"

  awk '
  {
    line=$0
    is_z2 = (line ~ /"action":"zapret2_(install|update|repair)"/)
    false_flag = (line ~ /"ok":false/)
    success_msg = (
      line ~ /Zapret2[^"]* kuruldu/ ||
      line ~ /Zapret2[^"]* onarımı tamamlandı/
    )
    if (is_z2 && false_flag && success_msg) {
      sub(/"ok":false/, "\"ok\":true", line)
    }
    print line
  }' "$STORE" >"$tmp" 2>/dev/null || {
    rm -f "$tmp"
    kzsc_lock_release oplog
    return 1
  }

  mv "$tmp" "$STORE"
  publish_unlocked
  rc=$?
  kzsc_lock_release oplog
  return "$rc"
}

case "$1" in
 append) shift; append "$@";;
 append-local) shift; append "$1" "$2" "$3" "$4" "${5:-$(date +%s)}" 0;;
 publish) publish;;
 json) publish; cat "$PUBLIC";;
 clear)
   clear_log
   ;;
 reconcile)
   reconcile
   ;;
 sanitize)
   sanitize_log
   ;;
 selfcheck)
   publish || exit 1
   [ -f "$STORE" ] || exit 1
   [ -f "$PUBLIC" ] || exit 1
   [ -w "$STORE" ] || exit 1
   echo "Olay Günlüğü depolama/yayın: OK"
   ;;
 *) echo "Usage: kzsc-oplog {append|append-local|publish|json|clear|reconcile|sanitize|selfcheck}"; exit 1;;
esac
