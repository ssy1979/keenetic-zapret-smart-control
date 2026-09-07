#!/opt/bin/sh

PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
unset LD_LIBRARY_PATH

printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'

urldecode(){
  printf '%b' "$(printf '%s' "$1" | sed 's/+/ /g;s/%/\\x/g')"
}

if [ "${REQUEST_METHOD:-GET}" = "GET" ]; then
  exec /opt/kzsc/bin/kzsc-settings.sh json
fi

[ "${REQUEST_METHOD:-}" = "POST" ] || {
  printf '{"ok":false,"error":"method_not_allowed"}\n'
  exit 0
}

# Keenetic lighttpd may consume or omit CGI POST stdin. The UI mirrors the same
# application/x-www-form-urlencoded payload in QUERY_STRING, so prefer it and
# retain stdin only as a compatibility fallback for direct callers.
body="${QUERY_STRING:-}"
[ -n "$body" ] || body="$(cat 2>/dev/null)"

[ -n "$body" ] || {
  printf '{"ok":false,"error":"empty_request"}\n'
  exit 0
}

blen="${#body}"
[ "$blen" -le 4096 ] || {
  printf '{"ok":false,"error":"request_too_large"}\n'
  exit 0
}

args=""
oldifs="$IFS"
IFS='&'
for pair in $body; do
  key="${pair%%=*}"
  val="${pair#*=}"
  val="$(urldecode "$val")"
  case "$key" in
    port|wan_interval|ping_count|targets|history_lines)
      args="$args
$key=$val"
      ;;
  esac
done
IFS="$oldifs"

set --
oldifs="$IFS"
IFS='
'
for kv in $args; do
  [ -n "$kv" ] && set -- "$@" "$kv"
done
IFS="$oldifs"

[ "$#" -gt 0 ] || {
  printf '{"ok":false,"error":"empty_request"}\n'
  exit 0
}

oldjson="$(/opt/kzsc/bin/kzsc-settings.sh json 2>/dev/null)"
oldport="$(printf '%s' "$oldjson" | sed -n 's/.*"port":\([0-9][0-9]*\).*/\1/p')"
[ -n "$oldport" ] || oldport=9090

kdjson="$(/opt/kzsc/bin/kzsc-keendns.sh status 2>/dev/null)"
kd_enabled="$(printf '%s' "$kdjson" | sed -n 's/.*"enabled":\(true\|false\).*/\1/p')"
[ "$kd_enabled" = true ] || kd_enabled=false

out="$(/opt/kzsc/bin/kzsc-settings.sh set "$@" 2>&1)"
rc=$?

if [ "$rc" -eq 10 ]; then
  newjson="$(/opt/kzsc/bin/kzsc-settings.sh json 2>/dev/null)"
  newport="$(printf '%s' "$newjson" | sed -n 's/.*"port":\([0-9][0-9]*\).*/\1/p')"
  lan="$(printf '%s' "$newjson" | sed -n 's/.*"lan_ip":"\([^"]*\)".*/\1/p')"
  [ -n "$newport" ] || newport="$oldport"
  [ -n "$lan" ] || lan="192.168.1.1"

  /opt/kzsc/bin/kzsc-oplog.sh append settings_save true \
    "Ayarlar kaydedildi; web portu değişiyor: $oldport → $newport." \
    "settings-$(date +%s)-$$" >/dev/null 2>&1 || true

  (
    sleep 2

    rollback_port(){
      /opt/kzsc/bin/kzsc-settings.sh set "port=$oldport" >/dev/null 2>&1 || true
      /opt/etc/init.d/S99kzsc restart >>/opt/kzsc/var/log/settings.log 2>&1 || true
      if [ "$kd_enabled" = true ]; then
        /opt/kzsc/bin/kzsc-keendns.sh enable >>/opt/kzsc/var/log/settings.log 2>&1 || true
      fi
      /opt/kzsc/bin/kzsc-oplog.sh append settings_port_change false \
        "Panel portu değişikliği doğrulanamadı; $oldport portuna geri dönüldü." \
        "settings-port-rollback-$(date +%s)-$$" >/dev/null 2>&1 || true
    }

    if ! /opt/etc/init.d/S99kzsc restart >>/opt/kzsc/var/log/settings.log 2>&1; then
      rollback_port
      exit 1
    fi

    web_ok=0
    n=0
    while [ "$n" -lt 10 ]; do
      if command -v curl >/dev/null 2>&1; then
        if curl -fsS --max-time 2 "http://$lan:$newport/cgi-bin/settings.cgi" 2>/dev/null | grep -q '"port"'; then
          web_ok=1
          break
        fi
      else
        pid="$(cat /opt/kzsc/var/run/lighttpd.pid 2>/dev/null)"
        [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && {
          web_ok=1
          break
        }
      fi
      n=$((n+1))
      sleep 1
    done

    if [ "$web_ok" -ne 1 ]; then
      rollback_port
      exit 1
    fi

    if [ "$kd_enabled" = true ]; then
      /opt/kzsc/bin/kzsc-keendns.sh sync >>/opt/kzsc/var/log/settings.log 2>&1 || {
        rollback_port
        exit 1
      }
      /opt/kzsc/bin/kzsc-keendns.sh audit >>/opt/kzsc/var/log/settings.log 2>&1 || {
        rollback_port
        exit 1
      }
    fi

    /opt/kzsc/bin/kzsc-oplog.sh append settings_port_change true \
      "Panel portu değiştirildi: $oldport → $newport. KeenDNS durumu doğrulandı." \
      "settings-port-ok-$(date +%s)-$$" >/dev/null 2>&1 || true
  ) >/dev/null 2>&1 &

  printf '{"ok":true,"restart":true,"port":%s,"url":"http://%s:%s/"}\n' "$newport" "$lan" "$newport"
  exit 0
fi

if [ "$rc" -ne 0 ]; then
  /opt/kzsc/bin/kzsc-oplog.sh append settings_save false "$out" "settings-$(date +%s)-$$" >/dev/null 2>&1 || true
  msg="$(printf '%s' "$out" | sed 's/\\/\\\\/g;s/"/\\"/g')"
  printf '{"ok":false,"error":"%s"}\n' "$msg"
  exit 0
fi

/opt/kzsc/bin/kzsc-oplog.sh append settings_save true "Ayarlar kaydedildi." "settings-$(date +%s)-$$" >/dev/null 2>&1 || true
printf '{"ok":true,"restart":false}\n'
