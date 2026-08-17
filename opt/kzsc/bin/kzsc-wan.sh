#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

WAN_JSON="$KZSC_HOME/www/data/wan.json"
WAN_LAST="$KZSC_HOME/var/run/wan-monitor.last"
WAN_LOCK="$KZSC_HOME/var/run/wan-monitor.lock"
WAN_HISTORY="$KZSC_HOME/www/data/wan-history.ndjson"
WAN_EVENTS="$KZSC_HOME/www/data/wan-events.ndjson"
WAN_STATE_DIR="$KZSC_HOME/var/run/wan-state"
WAN_HISTORY_LINES="${KZSC_WAN_HISTORY_LINES:-720}"
WAN_INTERVAL="${KZSC_WAN_INTERVAL:-30}"
WAN_TARGETS="${KZSC_WAN_TARGETS:-1.1.1.1 8.8.8.8}"
WAN_PING_COUNT="${KZSC_WAN_PING_COUNT:-3}"

mkdir -p "$KZSC_HOME/var/run" "$KZSC_HOME/var/log" "$KZSC_HOME/www/data" "$WAN_STATE_DIR"

num_or_zero(){
  case "$1" in
    ''|*[!0-9.]* ) printf '0' ;;
    * ) printf '%s' "$1" ;;
  esac
}

ping_probe(){
  ifc="$1"
  targets="$2"
  probe_count="$3"

  PING_TARGET=""
  PING_TX=0
  PING_RX=0
  PING_LOSS=100
  PING_AVG=0
  PING_MIN=0
  PING_MAX=0
  PING_JITTER=0

  have ping || return 1

  for target in $targets; do
    tmp="$KZSC_HOME/var/run/ping-${ifc}-$$.txt"
    rm -f "$tmp"

    ping -I "$ifc" -c "$probe_count" -W 1 "$target" >"$tmp" 2>&1 || true

    loss="$(sed -n 's/.* \([0-9][0-9]*\)% packet loss.*/\1/p' "$tmp" | tail -n1)"
    [ -n "$loss" ] || loss=100

    tx="$(sed -n 's/^\([0-9][0-9]*\) packets transmitted.*/\1/p' "$tmp" | tail -n1)"
    [ -n "$tx" ] || tx="$probe_count"

    rx="$(sed -n \
      -e 's/^[0-9][0-9]* packets transmitted, \([0-9][0-9]*\) packets received.*/\1/p' \
      -e 's/^[0-9][0-9]* packets transmitted, \([0-9][0-9]*\) received.*/\1/p' \
      "$tmp" | tail -n1)"
    [ -n "$rx" ] || rx=0

    stats="$(sed -n 's/.*time[=<]\([0-9.][0-9.]*\)[[:space:]]*ms.*/\1/p' "$tmp" | \
      awk '
        BEGIN{n=0;sum=0;mn=0;mx=0;j=0;prev=0}
        {
          x=$1+0
          n++
          sum+=x
          if(n==1 || x<mn) mn=x
          if(n==1 || x>mx) mx=x
          if(n>1){d=x-prev;if(d<0)d=-d;j+=d}
          prev=x
        }
        END{
          if(n==0) printf "0 0 0 0"
          else {
            avg=sum/n
            jit=(n>1)?j/(n-1):0
            printf "%.2f %.2f %.2f %.2f",mn,avg,mx,jit
          }
        }')"

    set -- $stats
    mn="$(num_or_zero "$1")"
    avg="$(num_or_zero "$2")"
    mx="$(num_or_zero "$3")"
    jit="$(num_or_zero "$4")"

    rm -f "$tmp"

    PING_TARGET="$target"
    PING_TX="$tx"
    PING_RX="$rx"
    PING_LOSS="$loss"
    PING_MIN="$mn"
    PING_AVG="$avg"
    PING_MAX="$mx"
    PING_JITTER="$jit"

    [ "$rx" -gt 0 ] 2>/dev/null && return 0
  done

  return 1
}

https_probe(){
  ifc="$1"
  HTTPS_STATE="unsupported"
  HTTPS_MS=0
  HTTPS_CODE=""

  have curl || return 0

  out="$(curl -4 --interface "$ifc" -sS -o /dev/null \
    --connect-timeout 3 --max-time 5 \
    -w '%{http_code} %{time_total}' \
    'https://connectivitycheck.gstatic.com/generate_204' 2>/dev/null || true)"

  code="${out%% *}"
  total="${out#* }"

  case "$code" in
    204|200|301|302)
      HTTPS_STATE="ok"
      HTTPS_CODE="$code"
      HTTPS_MS="$(awk -v t="$total" 'BEGIN{if(t+0>0) printf "%.0f",(t+0)*1000; else print 0}')"
      ;;
    *)
      HTTPS_STATE="fail"
      HTTPS_CODE="${code:-000}"
      HTTPS_MS=0
      ;;
  esac
}

quality_score(){
  rx="$1"; loss="$2"; avg="$3"; jit="$4"

  if [ "$rx" -le 0 ] 2>/dev/null; then
    SCORE=0
    QUALITY="down"
    return
  fi

  SCORE="$(awk -v loss="$loss" -v avg="$avg" -v jit="$jit" '
    BEGIN{
      # Fiber-friendly score:
      # - packet loss remains the strongest penalty
      # - latency up to 45 ms has no penalty
      # - above 45 ms, subtract ~1 point per additional 5 ms (max 15)
      # - jitter up to 5 ms has no penalty
      s=100-(loss*2)
      if(avg>45){p=(avg-45)/5;if(p>15)p=15;s-=p}
      if(jit>5){p=(jit-5)*2;if(p>20)p=20;s-=p}
      if(s<0)s=0
      if(s>100)s=100
      printf "%.0f",s
    }')"

  if [ "$SCORE" -ge 90 ]; then QUALITY="excellent"
  elif [ "$SCORE" -ge 75 ]; then QUALITY="good"
  elif [ "$SCORE" -ge 55 ]; then QUALITY="fair"
  else QUALITY="poor"
  fi
}


append_history(){
  ts="$1"; ndmc="$2"; lin="$3"; label="$4"; state="$5"
  loss="$6"; avg="$7"; jit="$8"; score="$9"
  printf '{"timestamp":%s,"ndmc":"%s","iface":"%s","label":"%s","state":"%s","loss_pct":%s,"latency_ms":%s,"jitter_ms":%s,"score":%s}\n' \
    "$ts" "$(json_escape "$ndmc")" "$(json_escape "$lin")" "$(json_escape "$label")" \
    "$state" "$loss" "$avg" "$jit" "$score" >> "$WAN_HISTORY"

  lines="$(wc -l < "$WAN_HISTORY" 2>/dev/null || echo 0)"
  case "$lines" in ''|*[!0-9]*) lines=0;; esac
  if [ "$lines" -gt "$WAN_HISTORY_LINES" ]; then
    keep="$WAN_HISTORY_LINES"
    tail -n "$keep" "$WAN_HISTORY" > "$WAN_HISTORY.tmp.$$" 2>/dev/null && mv "$WAN_HISTORY.tmp.$$" "$WAN_HISTORY"
  fi
}

record_event(){
  ts="$1"; ndmc="$2"; lin="$3"; label="$4"; state="$5"
  key="$(printf '%s' "$lin" | sed 's/[^A-Za-z0-9_.-]/_/g')"
  sf="$WAN_STATE_DIR/$key"
  prev="$(cat "$sf" 2>/dev/null || true)"

  if [ -n "$prev" ] && [ "$prev" != "$state" ]; then
    printf '{"timestamp":%s,"ndmc":"%s","iface":"%s","label":"%s","from":"%s","to":"%s"}\n' \
      "$ts" "$(json_escape "$ndmc")" "$(json_escape "$lin")" "$(json_escape "$label")" \
      "$prev" "$state" >> "$WAN_EVENTS"
    tail -n 200 "$WAN_EVENTS" > "$WAN_EVENTS.tmp.$$" 2>/dev/null && mv "$WAN_EVENTS.tmp.$$" "$WAN_EVENTS"
    [ -x /opt/kzsc/bin/kzsc-telegram.sh ] && /opt/kzsc/bin/kzsc-telegram.sh notify-wan "$ndmc" "$label" "$prev" "$state" >/dev/null 2>&1 &
  fi

  printf '%s\n' "$state" > "$sf"
}

check(){
  if ! mkdir "$WAN_LOCK" 2>/dev/null; then
    return 0
  fi
  trap 'rm -rf "$WAN_LOCK"' EXIT INT TERM HUP

  ts="$(date +%s)"
  tmp="$WAN_JSON.tmp.$$"
  items="$KZSC_HOME/var/run/wan-items.$$"
  : > "$items"

  item_count=0
  for ndmc_if in $(internet_wans); do
    lin="$(linux_if_for_ndmc "$ndmc_if")"
    label="$(isp_label "$ndmc_if")"
    state="down"

    if ip link show "$lin" >/dev/null 2>&1; then
      state="up"
    fi

    PING_TARGET=""
    PING_TX=0
    PING_RX=0
    PING_LOSS=100
    PING_MIN=0
    PING_AVG=0
    PING_MAX=0
    PING_JITTER=0
    HTTPS_STATE="unsupported"
    HTTPS_MS=0
    HTTPS_CODE=""

    if [ "$state" = "up" ]; then
      ping_probe "$lin" "$WAN_TARGETS" "$WAN_PING_COUNT" || true
      https_probe "$lin"
    fi

    quality_score "$PING_RX" "$PING_LOSS" "$PING_AVG" "$PING_JITTER"

    [ "$PING_RX" -gt 0 ] 2>/dev/null || state="down"

    esc_ndmc="$(json_escape "$ndmc_if")"
    esc_lin="$(json_escape "$lin")"
    esc_label="$(json_escape "$label")"
    esc_target="$(json_escape "$PING_TARGET")"

    [ "$item_count" -eq 0 ] || printf ',\n' >> "$items"
    cat >> "$items" <<EOF
{"ndmc":"$esc_ndmc","iface":"$esc_lin","label":"$esc_label","state":"$state","target":"$esc_target","tx":$PING_TX,"rx":$PING_RX,"loss_pct":$PING_LOSS,"latency_ms":{"min":$PING_MIN,"avg":$PING_AVG,"max":$PING_MAX},"jitter_ms":$PING_JITTER,"score":$SCORE,"quality":"$QUALITY","https":{"state":"$HTTPS_STATE","code":"$HTTPS_CODE","time_ms":$HTTPS_MS}}
EOF

    append_history "$ts" "$ndmc_if" "$lin" "$label" "$state" "$PING_LOSS" "$PING_AVG" "$PING_JITTER" "$SCORE"
    record_event "$ts" "$ndmc_if" "$lin" "$label" "$state"

    item_count=$((item_count+1))
  done

  {
    printf '{"timestamp":%s,"interval":%s,"targets":"' "$ts" "$WAN_INTERVAL"
    printf '%s' "$WAN_TARGETS" | sed 's/\\/\\\\/g;s/"/\\"/g'
    printf '","wans":[\n'
    cat "$items"
    printf '\n]}\n'
  } > "$tmp"

  mv "$tmp" "$WAN_JSON"
  echo "$ts" > "$WAN_LAST"
  rm -f "$items"

  trap - EXIT INT TERM HUP
  rm -rf "$WAN_LOCK"
}

maybe(){
  now="$(date +%s)"
  last="$(cat "$WAN_LAST" 2>/dev/null || echo 0)"
  case "$last" in ''|*[!0-9]*) last=0;; esac
  age=$((now-last))
  [ "$age" -ge "$WAN_INTERVAL" ] || return 0
  check
}

status(){
  [ -f "$WAN_JSON" ] || check

  echo "=== KZSC WAN Monitor ==="
  echo "interval: ${WAN_INTERVAL}s"
  echo "targets: $WAN_TARGETS"
  echo

  [ -f "$WAN_JSON" ] || {
    echo "No WAN monitor data."
    return 1
  }

  # Read our compact JSON without requiring jq.
  sed 's/},{/}\n{/g' "$WAN_JSON" | grep '"ndmc":' | while IFS= read -r line; do
    ndmc="$(printf '%s' "$line" | sed -n 's/.*"ndmc":"\([^"]*\)".*/\1/p')"
    iface="$(printf '%s' "$line" | sed -n 's/.*"iface":"\([^"]*\)".*/\1/p')"
    label="$(printf '%s' "$line" | sed -n 's/.*"label":"\([^"]*\)".*/\1/p')"
    state="$(printf '%s' "$line" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')"
    target="$(printf '%s' "$line" | sed -n 's/.*"target":"\([^"]*\)".*/\1/p')"
    loss="$(printf '%s' "$line" | sed -n 's/.*"loss_pct":\([0-9.]*\).*/\1/p')"
    avg="$(printf '%s' "$line" | sed -n 's/.*"latency_ms":{"min":[0-9.]*,"avg":\([0-9.]*\).*/\1/p')"
    jit="$(printf '%s' "$line" | sed -n 's/.*"jitter_ms":\([0-9.]*\).*/\1/p')"
    score="$(printf '%s' "$line" | sed -n 's/.*"score":\([0-9]*\).*/\1/p')"
    quality="$(printf '%s' "$line" | sed -n 's/.*"quality":"\([^"]*\)".*/\1/p')"
    https="$(printf '%s' "$line" | sed -n 's/.*"https":{"state":"\([^"]*\)".*/\1/p')"

    echo "$ndmc / $iface / $label"
    echo "  state   : $state"
    echo "  target  : ${target:--}"
    echo "  latency : ${avg:-0} ms"
    echo "  jitter  : ${jit:-0} ms"
    echo "  loss    : ${loss:-100}%"
    echo "  HTTPS   : ${https:-unsupported}"
    echo "  score   : ${score:-0}/100 ($quality)"
    echo
  done
}

case "$1" in
  check) check ;;
  maybe) maybe ;;
  status) status ;;
  *) echo "Usage: kzsc-wan {check|maybe|status}"; exit 1 ;;
esac
