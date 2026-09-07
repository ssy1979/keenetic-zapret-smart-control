#!/opt/bin/sh
. "${KZSC_LIB:-/opt/kzsc/bin/kzsc-lib.sh}"

OUT="$KZSC_HOME/www/data/wan-registry.json"
STATE="$KZSC_HOME/var/dpi/wan-registry"
mkdir -p "$KZSC_HOME/www/data" "$STATE"

# Queue range reserved exclusively for KZSC DPI engines.
QUEUE_BASE="${KZSC_QUEUE_BASE:-320}"
QUEUE_MAX="${KZSC_QUEUE_MAX:-399}"
case "$QUEUE_BASE:$QUEUE_MAX" in *[!0-9:]*) QUEUE_BASE=320; QUEUE_MAX=399;; esac
[ "$QUEUE_BASE" -le "$QUEUE_MAX" ] 2>/dev/null || { QUEUE_BASE=320; QUEUE_MAX=399; }

safe_id(){
  printf '%s' "$1" | tr ' A-Z/:.' '_a-z___' | tr -cd 'a-z0-9_-'
}

existing_queue(){
  ifc="$1"
  iptables-save -t mangle 2>/dev/null | awk -v i="$ifc" '
    (index($0,"-o " i " ") || index($0,"-i " i " ")) && index($0,"NFQUEUE") {
      for(n=1;n<=NF;n++) if($n=="--queue-num"){print $(n+1); exit}
    }'
}

queue_in_use(){
  q="$1"
  iptables-save -t mangle 2>/dev/null | grep -q -- "--queue-num $q"
}

queue_claimed_elsewhere(){
  wanted="$1"; own="$2"
  for x in "$STATE"/*.queue; do
    [ -f "$x" ] || continue
    [ "$x" = "$own" ] && continue
    [ "$(cat "$x" 2>/dev/null)" = "$wanted" ] && return 0
  done
  return 1
}

alloc_queue(){
  key="$1"
  f="$STATE/$(safe_id "$key").queue"
  if [ -f "$f" ]; then
    q="$(cat "$f" 2>/dev/null)"
    case "$q" in ''|*[!0-9]*) q="";; esac
    if [ -n "$q" ] && [ "$q" -ge "$QUEUE_BASE" ] 2>/dev/null && [ "$q" -le "$QUEUE_MAX" ] 2>/dev/null && \
       ! queue_claimed_elsewhere "$q" "$f"; then
      echo "$q"; return
    fi
  fi
  q="$QUEUE_BASE"
  while [ "$q" -le "$QUEUE_MAX" ]; do
    claimed=0
    for x in "$STATE"/*.queue; do
      [ -f "$x" ] || continue
      [ "$(cat "$x" 2>/dev/null)" = "$q" ] && claimed=1 && break
    done
    if [ "$claimed" -eq 0 ] && ! queue_in_use "$q"; then
      echo "$q" >"$f"
      echo "$q"
      return
    fi
    q=$((q+1))
  done
  echo "KZSC queue aralığı tükendi: ${QUEUE_BASE}-${QUEUE_MAX} · WAN=$key" >&2
  return 1
}

profile_for(){
  key="$1"
  f="$STATE/$(safe_id "$key").profile"
  [ -f "$f" ] && cat "$f" 2>/dev/null | head -n1 || echo "unassigned"
}


write_registry(){
  tmp="$OUT.tmp.$$"
  body="$STATE/.registry.body.$$"
  : >"$body"
  first=1
  count=0

  for nd in $(internet_wans); do
    [ -n "$nd" ] || continue
    lin="$(linux_if_for_ndmc "$nd")"
    [ -n "$lin" ] || continue
    isp="$(isp_label "$nd")"
    [ -n "$isp" ] || isp="$nd"
    if ! q="$(alloc_queue "$nd")" || [ -z "$q" ]; then
      rm -f "$body" "$tmp"
      return 1
    fi
    external_q="$(existing_queue "$lin")"
    prof="$(profile_for "$nd")"
    kind="$(internet_wan_kind "$nd")"

    [ "$first" -eq 1 ] || printf ',\n' >>"$body"
    first=0
    count=$((count+1))
    printf '{"id":"%s","ndmc":"%s","linux":"%s","kind":"%s","isp":"%s","queue":%s,"external_queue":"%s","profile":"%s"}' \
      "$(json_escape "$(safe_id "$nd")")" "$(json_escape "$nd")" "$(json_escape "$lin")" \
      "$(json_escape "$kind")" "$(json_escape "$isp")" "$q" "$(json_escape "$external_q")" \
      "$(json_escape "$prof")" >>"$body"
  done

  {
    printf '{"count":%s,"queue_base":%s,"queue_max":%s,"wans":[\n' "$count" "$QUEUE_BASE" "$QUEUE_MAX"
    cat "$body"
    printf '\n]}\n'
  } >"$tmp"
  rm -f "$body"
  mv "$tmp" "$OUT"
  chmod 644 "$OUT" 2>/dev/null || true
  cat "$OUT"
}

case "$1" in
  json|refresh) write_registry ;;
  *) echo "Usage: kzsc-wan-registry {json|refresh}"; exit 1 ;;
esac
