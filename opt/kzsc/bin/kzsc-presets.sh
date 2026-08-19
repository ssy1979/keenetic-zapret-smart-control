#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

DIR="$KZSC_HOME/share/dpi-presets"
AUTO="$KZSC_HOME/var/dpi/auto-presets"
OUT="$KZSC_HOME/www/data/presets.json"
mkdir -p "$DIR" "$KZSC_HOME/www/data"

valid_id(){ case "$1" in kablonet|sol|tt-fiber|vodafone|vodafone-tt|vodafone-tt2) [ -f "$DIR/$1.conf" ];; auto_*) [ -f "$AUTO/$1.conf" ];; *) return 1;; esac; }
conf_for(){ valid_id "$1" || return 1; case "$1" in auto_*) echo "$AUTO/$1.conf";; *) echo "$DIR/$1.conf";; esac; }

field(){
  local id="$1" key="$2" f
  f="$(conf_for "$id")" || return 1
  [ -f "$f" ] || return 1
  # Preset files may have been copied by Windows tooling with CRLF endings.
  # Strip the carriage return before matching the closing quote so names and
  # desync options are never silently reduced to empty strings.
  sed 's/\r$//' "$f" | sed -n "s/^${key}=\"\(.*\)\"$/\1/p" | head -n1
}

name(){ field "$1" NAME; }

recommend(){
  local isp="$1" u
  u="$(printf '%s' "$isp" | tr 'a-z' 'A-Z')"
  case "$u" in
    *TURK*TELEKOM*|*TTNET*|*TT*FIBER*|*TURK*TELEKOM*FIBER*) echo tt-fiber ;;
    *SUPERONLINE*|*SOL*FIBER*) echo sol ;;
    *KABLONET*|*TURKSAT*|*KABLO*) echo kablonet ;;
    *) echo "" ;;
  esac
}

opt(){
  local id="$1" h t u
  h="$(field "$id" HTTP_OPT)" || return 1
  t="$(field "$id" TLS_OPT)"
  u="$(field "$id" UDP_OPT)"
  printf '%s %s %s\n' "$h" "$t" "$u" | tr -s ' ' | sed 's/^ //;s/ $//'
}

write_json(){
  local tmp first id nm src no_udp http tls udp
  tmp="$OUT.tmp.$$"
  {
    printf '{"presets":['
    first=1
    for id in $(find "$DIR" -maxdepth 1 -type f -name '*.conf' 2>/dev/null | sed 's#.*/##;s/\.conf$//' | sort) $(find "$AUTO" -maxdepth 1 -type f -name 'auto_*.conf' 2>/dev/null | sed 's#.*/##;s/\.conf$//' | sort); do
      nm="$(field "$id" NAME)"
      src="$(field "$id" SOURCE)"
      no_udp="$(field "$id" NO_UDP)"
      http="$(field "$id" HTTP_OPT)"
      tls="$(field "$id" TLS_OPT)"
      udp="$(field "$id" UDP_OPT)"
      [ "$first" -eq 1 ] || printf ','
      first=0
      printf '{"id":"%s","name":"%s","no_udp":%s,"source":"%s","http":"%s","tls":"%s","udp":"%s"}' \
        "$(json_escape "$id")" "$(json_escape "$nm")" \
        "$([ "$no_udp" = 1 ] && echo true || echo false)" \
        "$(json_escape "$src")" "$(json_escape "$http")" \
        "$(json_escape "$tls")" "$(json_escape "$udp")"
    done
    printf ']}\n'
  } >"$tmp"
  mv "$tmp" "$OUT"
  chmod 644 "$OUT" 2>/dev/null || true
  cat "$OUT"
}

case "$1" in
  json|status) write_json ;;
  refresh) write_json >/dev/null ;;
  name) name "$2" ;;
  recommend) recommend "$2" ;;
  opt) opt "$2" ;;
  *)
    echo "Usage: kzsc-presets {json|refresh|name ID|recommend ISP_LABEL|opt ID}"
    exit 1
    ;;
esac
