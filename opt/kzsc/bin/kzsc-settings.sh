#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

CONF="$KZSC_HOME/etc/kzsc.conf"

ensure_conf(){
  [ -f "$CONF" ] || cp "$KZSC_HOME/etc/kzsc.conf.example" "$CONF"
}

getv(){
  key="$1"; def="$2"
  val="$(sed -n "s/^${key}=\"\([^\"]*\)\"$/\1/p" "$CONF" 2>/dev/null | tail -n1 | tr -d '\r')"
  [ -n "$val" ] || val="$def"
  printf '%s' "$val"
}

valid_port(){
  case "$1" in ''|*[!0-9]*) return 1;; esac
  [ "$1" -ge 1024 ] 2>/dev/null && [ "$1" -le 65535 ] 2>/dev/null
}

valid_interval(){
  case "$1" in ''|*[!0-9]*) return 1;; esac
  [ "$1" -ge 10 ] 2>/dev/null && [ "$1" -le 3600 ] 2>/dev/null
}

valid_ping_count(){
  case "$1" in ''|*[!0-9]*) return 1;; esac
  [ "$1" -ge 1 ] 2>/dev/null && [ "$1" -le 10 ] 2>/dev/null
}

valid_history_lines(){
  case "$1" in ''|*[!0-9]*) return 1;; esac
  [ "$1" -ge 120 ] 2>/dev/null && [ "$1" -le 10000 ] 2>/dev/null
}

valid_targets(){
  # Conservative: IPv4/IPv6-ish literals and hostnames, space separated only.
  [ -n "$1" ] || return 1
  printf '%s' "$1" | grep -Eq '^[A-Za-z0-9._: -]+$'
}

setv(){
  key="$1"; val="$2"
  tmp="$CONF.tmp.$$"
  awk -v k="$key" -v v="$val" '
    BEGIN{done=0}
    $0 ~ "^" k "=" {
      print k "=\"" v "\""
      done=1
      next
    }
    {print}
    END{if(!done) print k "=\"" v "\""}
  ' "$CONF" > "$tmp" && mv "$tmp" "$CONF"
}

show_json(){
  ensure_conf
  port="$(getv KZSC_PORT 9090)"
  wint="$(getv KZSC_WAN_INTERVAL 30)"
  pcnt="$(getv KZSC_WAN_PING_COUNT 3)"
  targets="$(getv KZSC_WAN_TARGETS '1.1.1.1 8.8.8.8')"
  hist="$(getv KZSC_WAN_HISTORY_LINES 720)"
  lan="$(detect_lan_ip | head -n1)"
  printf '{"port":%s,"wan_interval":%s,"ping_count":%s,"targets":"%s","history_lines":%s,"lan_ip":"%s"}\n' \
    "$port" "$wint" "$pcnt" "$(json_escape "$targets")" "$hist" "$(json_escape "$lan")"
}

apply_kv(){
  ensure_conf
  restart_web=0
  changed=0

  while [ "$#" -gt 0 ]; do
    kv="$1"; shift
    key="${kv%%=*}"
    val="${kv#*=}"
    [ "$key" != "$kv" ] || { echo "ERROR: expected key=value" >&2; return 1; }

    case "$key" in
      port)
        valid_port "$val" || { echo "ERROR: port must be 1024-65535" >&2; return 1; }
        old="$(getv KZSC_PORT 9090)"
        setv KZSC_PORT "$val"
        [ "$old" = "$val" ] || restart_web=1
        changed=1
        ;;
      wan_interval)
        valid_interval "$val" || { echo "ERROR: wan_interval must be 10-3600 seconds" >&2; return 1; }
        setv KZSC_WAN_INTERVAL "$val"; changed=1
        ;;
      ping_count)
        valid_ping_count "$val" || { echo "ERROR: ping_count must be 1-10" >&2; return 1; }
        setv KZSC_WAN_PING_COUNT "$val"; changed=1
        ;;
      targets)
        valid_targets "$val" || { echo "ERROR: invalid targets" >&2; return 1; }
        setv KZSC_WAN_TARGETS "$val"; changed=1
        ;;
      history_lines)
        valid_history_lines "$val" || { echo "ERROR: history_lines must be 120-10000" >&2; return 1; }
        setv KZSC_WAN_HISTORY_LINES "$val"; changed=1
        ;;
      *)
        echo "ERROR: unsupported setting: $key" >&2
        return 1
        ;;
    esac
  done

  [ "$changed" -eq 1 ] || return 0

  # Refresh the WAN worker environment without disturbing DPI engine.
  # Full KZSC init restart is only needed for port changes; other settings
  # are picked up by newly invoked scripts through kzsc-lib.sh.
  if [ "$restart_web" -eq 1 ]; then
    return 10
  fi
  return 0
}

case "$1" in
  json)
    show_json
    ;;
  set)
    shift
    apply_kv "$@"
    rc=$?
    if [ "$rc" -eq 10 ]; then
      echo "RESTART_WEB=1"
      exit 10
    fi
    exit "$rc"
    ;;
  *)
    echo "Usage: kzsc-settings {json|set key=value ...}"
    exit 1
    ;;
esac
