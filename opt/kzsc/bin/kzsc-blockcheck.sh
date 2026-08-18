#!/opt/bin/sh
. "${KZSC_LIB:-/opt/kzsc/bin/kzsc-lib.sh}"

ROOT="$KZSC_HOME/var/blockcheck"
WWW="$KZSC_HOME/www/data"
ZROOT="$KZSC_HOME/zapret2"
REG="$KZSC_HOME/var/dpi/wan-registry"
QUEUE_DIR="$ROOT/queue"
AUTO_PRESET_DIR="$KZSC_HOME/var/dpi/auto-presets"
SCHED_DIR="$ROOT/scheduler"
MAX_SECONDS="${KZSC_BLOCKCHECK_MAX_SECONDS:-1800}"
case "$MAX_SECONDS" in ''|*[!0-9]*) MAX_SECONDS=1800;; esac
[ "$MAX_SECONDS" -ge 60 ] 2>/dev/null || MAX_SECONDS=60
[ "$MAX_SECONDS" -le 3600 ] 2>/dev/null || MAX_SECONDS=3600
WORKER_DEADLINE=0
mkdir -p "$ROOT" "$WWW" "$QUEUE_DIR" "$AUTO_PRESET_DIR" "$SCHED_DIR"

safe_id(){
  local v="$1"
  printf '%s' "$v" | tr ' A-Z/:.' '_a-z___' | tr -cd 'a-z0-9_-'
}

wan_exists(){
  local want="$1" x
  for x in $(internet_wans); do
    [ "$x" = "$want" ] && return 0
  done
  return 1
}

linux_for(){
  local nd="$1"
  linux_if_for_ndmc "$nd"
}
isp_for(){
  local nd="$1"
  isp_label "$nd"
}
job_dir(){
  local nd="$1"
  echo "$ROOT/$(safe_id "$nd")"
}

domains_file(){
  local nd="$1"
  echo "$(job_dir "$nd")/domains"
}

scanlevel_file(){
  local nd="$1"
  echo "$(job_dir "$nd")/scanlevel"
}

validate_scanlevel(){ [ "$1" = "quick" ]; }

get_scanlevel(){
  local nd="$1" raw
  raw="$(cat "$(scanlevel_file "$nd")" 2>/dev/null)"
  validate_scanlevel "$raw" || raw="quick"
  printf '%s\n' "$raw"
}

set_scanlevel(){
  local nd="$1" d
  wan_exists "$nd" || { echo "WAN bulunamadı: $nd" >&2; return 1; }
  is_running "$nd" && { echo "$nd Blockcheck çalışırken ayar değiştirilemez." >&2; return 1; }
  d="$(job_dir "$nd")"; mkdir -p "$d"
  printf '%s\n' quick >"$(scanlevel_file "$nd")"
  write_all_json >/dev/null 2>&1 || true
  echo "$nd tek Blockcheck modu aktif · maksimum ${MAX_SECONDS}s"
}

estimate_for(){ echo "";
}

validate_domains(){
  local raw="$1" tok count length
  [ -n "$raw" ] || return 1
  length="$(printf '%s' "$raw" | awk '{print length($0)}')"
  [ "$length" -le 240 ] 2>/dev/null || return 1
  count=0
  for tok in $raw; do
    count=$((count+1))
    [ "$count" -le 10 ] || return 1
    [ "${#tok}" -le 120 ] || return 1
    # Domain or domain/path. No scheme, shell metacharacters or whitespace.
    printf '%s\n' "$tok" | grep -Eq '^[A-Za-z0-9._-]+(:[0-9]+)?(/[A-Za-z0-9._~!$&()*+,;=:@%/?-]*)?$' || return 1
  done
  return 0
}

get_domains(){
  local nd="$1" f raw
  f="$(domains_file "$nd")"
  raw="$(cat "$f" 2>/dev/null)"
  validate_domains "$raw" || raw="pastebin.com"
  printf '%s\n' "$raw"
}

set_domains(){
  local nd="$1" raw="$2" d
  wan_exists "$nd" || { echo "WAN bulunamadı: $nd" >&2; return 1; }
  is_running "$nd" && { echo "$nd Blockcheck çalışırken domain değiştirilemez." >&2; return 1; }

  raw="$(printf '%s' "$raw" | tr ',' ' ' | tr -s ' ')"
  [ -n "$raw" ] || raw="pastebin.com"

  validate_domains "$raw" || {
    echo "Geçersiz domain listesi. Örnek: pastebin.com discord.com" >&2
    return 1
  }
  d="$(job_dir "$nd")"; mkdir -p "$d"
  printf '%s\n' "$raw" >"$(domains_file "$nd")"
  write_all_json >/dev/null 2>&1 || true
  echo "$nd Blockcheck hedefleri: $raw"
}

extract_summary(){
  local log="$1" out="$2"
  : >"$out"
  [ -f "$log" ] || return 1
  awk '
    /^\* SUMMARY[[:space:]]*$/ {in_summary=1; next}
    in_summary && /^Please note this SUMMARY/ {exit}
    in_summary {
      if ($0=="") {
        if (seen) exit
        next
      }
      print
      seen=1
    }
  ' "$log" >"$out"
  [ -s "$out" ]
}

classify_summary(){
  local f="$1"
  [ -s "$f" ] || { echo "no_result"; return; }

  if grep -Eq ': (nfqws2|nfqws|dvtws2|winws2) ' "$f"; then
    echo "profile_found"
    return
  fi

  if grep -q 'working without bypass' "$f"; then
    # Only call it no_bypass_needed if no bypass strategy was reported.
    if ! grep -Eq ': (nfqws2|nfqws|dvtws2|winws2|tpws) ' "$f"; then
      echo "no_bypass_needed"
      return
    fi
  fi

  echo "no_result"
}

is_running(){
  local nd="$1" d p
  d="$(job_dir "$nd")"
  p="$(cat "$d/pid" 2>/dev/null)"
  [ -n "$p" ] && kill -0 "$p" 2>/dev/null
}

reconcile_stale(){
  local nd="$1" d state
  d="$(job_dir "$nd")"
  state="$(cat "$d/state" 2>/dev/null)"
  case "$state" in
    running)
      if ! is_running "$nd"; then
        # A queued/running job without a live PID is a launcher/worker failure.
        rm -f "$d/pid"
        [ -f "$d/rc" ] || echo 125 >"$d/rc"
        [ -f "$d/ended" ] || date +%s >"$d/ended"
        echo failed >"$d/state"
        [ -s "$d/blockcheck.log" ] || {
          echo "KZSC: Blockcheck worker başlatılamadı veya beklenmedik şekilde sonlandı." >"$d/blockcheck.log"
        }
      fi
      ;;
  esac
}

elapsed(){
  local nd="$1" d started ended now finish e
  d="$(job_dir "$nd")"
  started="$(cat "$d/started" 2>/dev/null)"
  ended="$(cat "$d/ended" 2>/dev/null)"
  now="$(date +%s 2>/dev/null)"
  case "$started" in ''|*[!0-9]*) echo 0; return;; esac
  case "$ended" in ''|*[!0-9]*) finish="$now";; *) finish="$ended";; esac
  case "$finish" in ''|*[!0-9]*) echo 0; return;; esac
  e=$((finish-started)); [ "$e" -lt 0 ] && e=0
  echo "$e"
}

last_stage(){
  local nd="$1" d log line
  d="$(job_dir "$nd")"
  log="$d/blockcheck.log"
  [ -f "$log" ] || { echo "Hazırlanıyor"; return; }
  # Keep this parser deliberately generic across upstream blockcheck versions.
  # Prefer recent descriptive lines but do not depend on exact upstream text.
  line="$(tail -n 80 "$log" 2>/dev/null | grep -E -i 'checking|testing|test |strategy|http|https|tls|quic|udp|summary|result|found|fail|success|dpi' | tail -n1)"
  [ -n "$line" ] || line="$(tail -n1 "$log" 2>/dev/null)"
  [ -n "$line" ] || line="Çalışıyor"
  printf '%s\n' "$line" | cut -c1-180
}

summary_file(){
  local nd="$1" d
  d="$(job_dir "$nd")"
  [ -f "$d/summary.txt" ] && { echo "$d/summary.txt"; return; }
  ls -1t "$d"/run/blockcheck_summary_*.txt "$d"/run/*summary*.txt 2>/dev/null | head -n1
}

any_running(){
  local nd
  for nd in $(internet_wans); do is_running "$nd" && return 0; done
  return 1
}

upstream_blockcheck_rules_active(){
  iptables-save -t mangle 2>/dev/null | grep -Eq 'blockcheck_(input|output)_[0-9]+'
}

queued_for(){
  local nd="$1" f
  for f in "$QUEUE_DIR"/*.req; do
    [ -f "$f" ] || continue
    [ "$(sed -n 's/^NDMC=//p' "$f" | head -n1)" = "$nd" ] && { echo "$f"; return 0; }
  done
  return 1
}

queue_position(){
  local nd="$1" f n=0 qnd
  for f in $(ls -1tr "$QUEUE_DIR"/*.req 2>/dev/null); do
    [ -f "$f" ] || continue
    n=$((n+1)); qnd="$(sed -n 's/^NDMC=//p' "$f" | head -n1)"
    [ "$qnd" = "$nd" ] && { echo "$n"; return; }
  done
  echo 0
}

enqueue_job(){
  local nd="$1" domains="$2" scan="$3" autoapply="$4" source="$5" force_enable="${6:-0}" d f now existing
  d="$(job_dir "$nd")"; mkdir -p "$d" "$QUEUE_DIR"
  printf '%s\n' "$nd" >"$d/ndmc"
  existing="$(queued_for "$nd" 2>/dev/null || true)"
  [ -n "$existing" ] && rm -f "$existing"
  now="$(date +%s)"
  f="$QUEUE_DIR/${now}-$$-$(safe_id "$nd").req"
  {
    printf 'NDMC=%s\n' "$nd"
    printf 'DOMAINS=%s\n' "$domains"
    printf 'SCANLEVEL=%s\n' "$scan"
    printf 'AUTO_APPLY=%s\n' "$autoapply"
    printf 'SOURCE=%s\n' "$source"
    printf 'FORCE_ENABLE=%s\n' "$force_enable"
    printf 'QUEUED_AT=%s\n' "$now"
  } >"$f" || return 1
  echo queued >"$d/state"
  echo "$now" >"$d/started"
  printf '%s\n' "$source" >"$d/source"
  printf '%s\n' "$autoapply" >"$d/auto_apply"
  printf '%s\n' "$force_enable" >"$d/force_enable"
  rm -f "$d/ended" "$d/rc" "$d/pid" "$d/result_type" "$d/summary.txt"
  printf 'Sırada · diğer WAN Blockcheck tamamlandığında otomatik başlayacak.\n' >"$d/blockcheck.log"
  write_all_json >/dev/null 2>&1 || true
  /opt/kzsc/bin/kzsc-oplog.sh append blockcheck_queued true "$(isp_for "$nd") ($nd) Blockcheck sıraya alındı · mod=$scan · kaynak=$source" "blockcheck-queue-$now-$$" >/dev/null 2>&1 || true
  echo "$(isp_for "$nd") / $nd Blockcheck sıraya alındı. Diğer WAN testi tamamlanınca otomatik başlayacak."
}

remove_queued(){
  local nd="$1" f
  f="$(queued_for "$nd" 2>/dev/null || true)"
  [ -n "$f" ] && rm -f "$f"
}


engine_profile_for(){
  local nd="$1" f
  f="$REG/$(safe_id "$nd").profile"
  [ -f "$f" ] && head -n1 "$f" 2>/dev/null || echo "unassigned"
}

engine_enabled_for(){
  [ -f "$KZSC_HOME/var/dpi/engines/$(safe_id "$1")/enabled" ]
}

probe_url(){
  local lin="$1" url="$2" code rc
  [ "$WORKER_DEADLINE" -le 0 ] 2>/dev/null || [ "$(date +%s)" -lt "$WORKER_DEADLINE" ] || return 1
  code="$(curl --interface "$lin" -4 -sS -L --connect-timeout 5 --max-time 12 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)"
  rc=$?
  [ "$rc" -eq 0 ] || return 1
  case "$code" in
    ''|000) return 1 ;;
    *) return 0 ;;
  esac
}

probe_profile(){
  local nd="$1" lin="$2" profile="$3" domains="$4" tok host http_ok https_ok
  /opt/kzsc/bin/kzsc-engines.sh set-profile "$nd" "$profile" >/dev/null 2>&1 || return 1
  /opt/kzsc/bin/kzsc-native-dpi.sh enable "$nd" >/dev/null 2>&1 || return 1
  sleep 1
  http_ok=1; https_ok=1
  for tok in $domains; do
    [ "$WORKER_DEADLINE" -le 0 ] 2>/dev/null || [ "$(date +%s)" -lt "$WORKER_DEADLINE" ] || return 1
    host="${tok%%/*}"
    probe_url "$lin" "http://$host/" || http_ok=0
    probe_url "$lin" "https://$host/" || https_ok=0
  done
  [ "$http_ok" -eq 1 ] && [ "$https_ok" -eq 1 ]
}

restore_engine_profile(){
  local nd="$1" profile="$2" was_enabled="$3"
  [ -n "$profile" ] && [ "$profile" != "unassigned" ] && \
    /opt/kzsc/bin/kzsc-engines.sh set-profile "$nd" "$profile" >/dev/null 2>&1 || true
  if [ "$was_enabled" -eq 1 ]; then
    /opt/kzsc/bin/kzsc-native-dpi.sh enable "$nd" >/dev/null 2>&1 || true
  else
    /opt/kzsc/bin/kzsc-native-dpi.sh disable "$nd" >/dev/null 2>&1 || true
  fi
}

preset_first_probe(){
  local nd="$1" lin="$2" domains="$3" auto_apply="$4" force_enable="${5:-0}" d isp rec orig was_enabled candidates p seen name
  d="$(job_dir "$nd")"
  isp="$(isp_for "$nd")"
  rec="$(/opt/kzsc/bin/kzsc-presets.sh recommend "$isp" 2>/dev/null)"
  orig="$(engine_profile_for "$nd")"
  was_enabled=0; engine_enabled_for "$nd" && was_enabled=1

  # Known-good built-ins are intentionally tested before the broad upstream scan.
  # ISP recommendation comes first, then the remaining built-in presets, then the
  # WAN's current AUTO profile if one exists. Duplicate candidates are skipped.
  candidates="$rec tt sol kablonet $(find "$KZSC_HOME/share/dpi-presets" -maxdepth 1 -type f -name 'kzm2-*.conf' 2>/dev/null | sed 's#.*/##;s/\.conf$//' | sort)"
  case "$orig" in auto_*) candidates="$candidates $orig";; esac
  seen=""
  for p in $candidates; do
    [ "$WORKER_DEADLINE" -le 0 ] 2>/dev/null || [ "$(date +%s)" -lt "$WORKER_DEADLINE" ] || {
      restore_engine_profile "$nd" "$orig" "$was_enabled"
      return 1
    }
    [ -n "$p" ] || continue
    case " $seen " in *" $p "*) continue;; esac
    seen="$seen $p"
    [ -f "$KZSC_HOME/share/dpi-presets/$p.conf" ] || [ -f "$AUTO_PRESET_DIR/$p.conf" ] || continue
    name="$(/opt/kzsc/bin/kzsc-presets.sh name "$p" 2>/dev/null)"; [ -n "$name" ] || name="$p"
    {
      echo "KZSC PRESET-FIRST: Testing preset $name ($p)"
      echo "KZSC PRESET-FIRST: HTTP + HTTPS/TLS reachability must both pass for all configured domains."
    } >>"$d/blockcheck.log"
    write_all_json >/dev/null 2>&1 || true

    if probe_profile "$nd" "$lin" "$p" "$domains"; then
      if [ "$WORKER_DEADLINE" -gt 0 ] 2>/dev/null && [ "$(date +%s)" -ge "$WORKER_DEADLINE" ]; then
        restore_engine_profile "$nd" "$orig" "$was_enabled"
        return 1
      fi
      echo "KZSC PRESET-FIRST: Preset sufficient: $name ($p). Broad Blockcheck scan skipped." >>"$d/blockcheck.log"
      if [ "$auto_apply" = 1 ]; then
        # Preserve the user's previous engine enabled/disabled state while keeping
        # the verified preset selected.
        if [ "$was_enabled" -eq 0 ] && [ "$force_enable" != 1 ]; then
          /opt/kzsc/bin/kzsc-native-dpi.sh disable "$nd" >/dev/null 2>&1 || true
        fi
        printf '%s\n' "$p" >"$d/applied_profile"
      else
        restore_engine_profile "$nd" "$orig" "$was_enabled"
      fi
      printf '%s\n' preset_verified >"$d/result_type"
      printf 'preset=%s\nname=%s\nhttp=ok\nhttps=ok\n' "$p" "$name" >"$d/summary.txt"
      return 0
    fi
    echo "KZSC PRESET-FIRST: Preset insufficient: $name ($p)." >>"$d/blockcheck.log"
  done

  restore_engine_profile "$nd" "$orig" "$was_enabled"
  echo "KZSC PRESET-FIRST: No preset was sufficient; continuing with broad Blockcheck scan." >>"$d/blockcheck.log"
  return 1
}

strategy_safe(){
  # Upstream blockcheck output is treated as data and is never eval'ed.
  # Reject only line breaks to keep generated profile records one-line.
  [ "$(printf '%s' "$1" | tr -d '\r\n')" = "$1" ]
}


first_nfqws2_strategy(){
  local summary="$1" kind="$2"
  awk -v k="$kind" '
    index($0," : nfqws2 ") {
      ok=0
      if(k=="http" && $0 ~ /^curl_test_http ipv/) ok=1
      if(k=="tls"  && $0 ~ /^curl_test_https/) ok=1
      if(k=="quic" && ($0 ~ /^curl_test_http3/ || $0 ~ /^curl_test_quic/ || $0 ~ /^curl_test_udp/)) ok=1
      if(ok){ x=$0; sub(/^.* : nfqws2[[:space:]]+/,"",x); print x; exit }
    }
  ' "$summary"
}

build_auto_profile(){
  local nd="$1" summary="$2" id f http tls udp no_udp src
  [ -s "$summary" ] || return 1
  http="$(first_nfqws2_strategy "$summary" http)"
  tls="$(first_nfqws2_strategy "$summary" tls)"
  udp="$(first_nfqws2_strategy "$summary" quic)"
  # Blockcheck runs from a per-WAN copy. Persist strategies against the stable
  # official KZSC Zapret2 tree when upstream prints absolute resource paths.
  runprefix="$(job_dir "$nd")/run/"
  http="$(printf '%s' "$http" | sed "s#${runprefix}#${ZROOT}/#g")"
  tls="$(printf '%s' "$tls" | sed "s#${runprefix}#${ZROOT}/#g")"
  udp="$(printf '%s' "$udp" | sed "s#${runprefix}#${ZROOT}/#g")"
  [ -n "$http$tls$udp" ] || return 1
  strategy_safe "$http" && strategy_safe "$tls" && strategy_safe "$udp" || return 1
  id="auto_$(safe_id "$nd")"; f="$AUTO_PRESET_DIR/$id.conf"; mkdir -p "$AUTO_PRESET_DIR"
  [ -n "$udp" ] && no_udp=0 || no_udp=1
  [ -n "$http" ] && http="--filter-tcp=80 --filter-l7=http $http --new"
  [ -n "$tls" ] && tls="--filter-tcp=443 --filter-l7=tls $tls$([ -n "$udp" ] && printf ' --new')"
  [ -n "$udp" ] && udp="--filter-udp=443 --filter-l7=quic $udp"
  src="KZSC Blockcheck auto profile · $(date '+%Y-%m-%d %H:%M:%S')"
  {
    printf 'ID="%s"\n' "$id"
    printf 'NAME="AUTO BLOCKCHECK · %s"\n' "$(isp_for "$nd")"
    printf 'SOURCE="%s"\n' "$src"
    printf 'HTTP_OPT="%s"\n' "$http"
    printf 'TLS_OPT="%s"\n' "$tls"
    printf 'UDP_OPT="%s"\n' "$udp"
    printf 'NO_UDP="%s"\n' "$no_udp"
    printf 'MATCH=""\n'
  } >"$f" || return 1
  chmod 600 "$f" 2>/dev/null || true
  printf '%s\n' "$id"
}

auto_apply_result(){
  local nd="$1" summary="$2" force_enable="${3:-0}" d id was_enabled msg
  [ "${KZSC_BLOCKCHECK_AUTO_APPLY:-1}" = 1 ] || { echo "Otomatik uygulama kapalı."; return 2; }
  d="$KZSC_HOME/var/dpi/engines/$(safe_id "$nd")"
  [ -f "$d/enabled" ] && was_enabled=1 || was_enabled=0
  id="$(build_auto_profile "$nd" "$summary")" || { echo "Uygulanabilir nfqws2 stratejisi çıkarılamadı."; return 3; }
  /opt/kzsc/bin/kzsc-engines.sh set-profile "$nd" "$id" >/dev/null 2>&1 || { echo "Otomatik DPI profili kaydedilemedi."; return 4; }
  if [ "$was_enabled" -eq 1 ] || [ "$force_enable" = 1 ]; then
    /opt/kzsc/bin/kzsc-native-dpi.sh enable "$nd" >/dev/null 2>&1 || { echo "Otomatik profil kaydedildi fakat DPI motoru başlatılamadı."; return 5; }
    msg="Blockcheck sonucu otomatik uygulandı: $id · DPI motoru aktif."
  else
    msg="Blockcheck sonucu otomatik profil olarak kaydedildi: $id · motor kapalı olduğu için başlatılmadı."
  fi
  printf '%s\n' "$id" >"$(job_dir "$nd")/applied_profile"
  printf '%s\n' "$msg"
}

launch_job(){
  local nd="$1" d launcher wp
  d="$(job_dir "$nd")"; mkdir -p "$d"
  printf '%s\n' "$nd" >"$d/ndmc"
  echo running >"$d/state"
  date +%s >"$d/started"
  rm -f "$d/ended" "$d/rc" "$d/pid" "$d/result_type" "$d/summary.txt" "$d/applied_profile"
  : >"$d/blockcheck.log"
  launcher="$d/launcher.log"; : >"$launcher"
  (
    exec /opt/bin/sh /opt/kzsc/bin/kzsc-blockcheck.sh _worker "$nd"
  ) >>"$launcher" 2>&1 &
  wp=$!; echo "$wp" >"$d/pid"
  sleep 1
  if ! kill -0 "$wp" 2>/dev/null; then
    reconcile_stale "$nd"; write_all_json >/dev/null 2>&1 || true
    echo "Blockcheck worker başlatılamadı. Ayrıntı: $launcher" >&2; return 1
  fi
  write_all_json >/dev/null 2>&1 || true
  echo "$(isp_for "$nd") / $nd Blockcheck başlatıldı (pid $wp)."
}

dispatch_queue(){
  local f nd domains scan autoapply source force_enable d
  any_running && return 0
  upstream_blockcheck_rules_active && return 0
  f="$(ls -1tr "$QUEUE_DIR"/*.req 2>/dev/null | head -n1)"
  [ -f "$f" ] || return 0
  nd="$(sed -n 's/^NDMC=//p' "$f" | head -n1)"
  domains="$(sed -n 's/^DOMAINS=//p' "$f" | head -n1)"
  scan="$(sed -n 's/^SCANLEVEL=//p' "$f" | head -n1)"
  autoapply="$(sed -n 's/^AUTO_APPLY=//p' "$f" | head -n1)"
  source="$(sed -n 's/^SOURCE=//p' "$f" | head -n1)"
  force_enable="$(sed -n 's/^FORCE_ENABLE=//p' "$f" | head -n1)"
  rm -f "$f"
  wan_exists "$nd" || return 0
  d="$(job_dir "$nd")"; mkdir -p "$d"
  [ -n "$domains" ] && printf '%s\n' "$domains" >"$(domains_file "$nd")"
  scan=quick
  printf '%s\n' "$scan" >"$(scanlevel_file "$nd")"
  printf '%s\n' "${autoapply:-1}" >"$d/auto_apply"
  printf '%s\n' "${source:-queue}" >"$d/source"
  printf '%s\n' "${force_enable:-0}" >"$d/force_enable"
  if ! launch_job "$nd"; then
    echo failed >"$d/state"; echo 126 >"$d/rc"; date +%s >"$d/ended"
    /opt/kzsc/bin/kzsc-oplog.sh append blockcheck_dispatch false "$(isp_for "$nd") ($nd) sıradaki Blockcheck başlatılamadı." "blockcheck-dispatch-$(date +%s)-$$" >/dev/null 2>&1 || true
  fi
}

schedule_tick(){
  local enabled hour mode nowh day stamp nd queued=0
  enabled="${KZSC_BLOCKCHECK_NIGHTLY:-1}"; [ "$enabled" = 1 ] || return 0
  hour="${KZSC_BLOCKCHECK_NIGHTLY_HOUR:-04}"; mode="${KZSC_BLOCKCHECK_NIGHTLY_MODE:-quick}"
  nowh="$(date +%H 2>/dev/null)"; day="$(date +%Y%m%d 2>/dev/null)"
  [ "$nowh" = "$hour" ] || return 0
  stamp="$SCHED_DIR/nightly-$day.done"; [ -f "$stamp" ] && return 0
  : >"$stamp"
  if [ ! -x "$ZROOT/blockcheck2.sh" ]; then
    /opt/kzsc/bin/kzsc-oplog.sh append blockcheck_nightly false "Gece Blockcheck başlatılamadı: Zapret2/blockcheck2 hazır değil." "blockcheck-nightly-$day" >/dev/null 2>&1 || true
    return 0
  fi
  for nd in $(internet_wans); do
    enqueue_job "$nd" "$(get_domains "$nd")" "$mode" 1 nightly 0 >/dev/null 2>&1 && queued=$((queued+1))
  done
  /opt/kzsc/bin/kzsc-oplog.sh append blockcheck_nightly true "04:00 otomatik hızlı Blockcheck: $queued WAN sıraya alındı; sonuçlar otomatik uygulanacak." "blockcheck-nightly-$day" >/dev/null 2>&1 || true
}

blockcheck_preflight(){
  local nd="$1" lin="$2"
  [ -x "$ZROOT/blockcheck2.sh" ] || { echo "KZSC Zapret2/blockcheck2 hazır değil."; return 20; }
  [ -n "$lin" ] || { echo "Linux WAN interface çözümlenemedi: $nd"; return 21; }
  iso_msg="$(/opt/kzsc/bin/kzsc-isolation.sh can-isolate "$nd" "$lin" 2>&1)"
  iso_rc=$?
  if [ "$iso_rc" -ne 0 ]; then
    echo "$nd / $lin için güvenli NFQUEUE izolasyonu hazırlanamadı${iso_msg:+: $iso_msg}"
    return 30
  fi
  return 0
}

progress_counts(){
  local nd="$1" d log completed total remaining pct state
  d="$(job_dir "$nd")"; log="$d/blockcheck.log"
  completed="$(grep -Ec '^[[:space:]]*-?[[:space:]]*curl_test_[A-Za-z0-9_]+' "$log" 2>/dev/null)"; [ -n "$completed" ] || completed=0
  state="$(cat "$d/state" 2>/dev/null)"
  # Upstream blockcheck2 builds candidate sets dynamically according to protocol,
  # reachability and DPI responses. There is no reliable fixed total while it is running.
  # At completion the observed total is exact; while running expose completed and unknown total.
  if [ "$state" = success ] || [ "$state" = failed ] || [ "$state" = blocked ] || [ "$state" = timeout ] || [ "$state" = restore_failed ]; then total="$completed"; remaining=0; pct=100
  else total=0; remaining=-1; pct=-1; fi
  printf '%s|%s|%s|%s' "$completed" "$total" "$remaining" "$pct"
}

write_one_state(){
  local nd="$1" d lin isp state p e stage started ended job_rc sum out isolated domains result_type scanlevel estimate queue_pos source auto_apply applied_profile pc completed total_tests remaining_tests progress_percent max_seconds max_remaining
  d="$(job_dir "$nd")"
  mkdir -p "$d"
  reconcile_stale "$nd"
  lin="$(linux_for "$nd")"
  isp="$(isp_for "$nd")"; [ -n "$isp" ] || isp="$nd"
  state="$(cat "$d/state" 2>/dev/null)"
  [ -n "$state" ] || state="idle"
  if is_running "$nd"; then state="running"; fi
  p="$(cat "$d/pid" 2>/dev/null)"
  e="$(elapsed "$nd")"
  stage="$(last_stage "$nd")"
  started="$(cat "$d/started" 2>/dev/null)"
  ended="$(cat "$d/ended" 2>/dev/null)"
  job_rc="$(cat "$d/rc" 2>/dev/null)"
  sum="$(summary_file "$nd")"
  domains="$(get_domains "$nd")"
  scanlevel="$(get_scanlevel "$nd")"
  auto_apply="$(cat "$d/auto_apply" 2>/dev/null)"; [ -n "$auto_apply" ] || auto_apply="${KZSC_BLOCKCHECK_AUTO_APPLY:-1}"
  source="$(cat "$d/source" 2>/dev/null)"; [ -n "$source" ] || source="manual"
  estimate=""
  max_seconds="$MAX_SECONDS"; max_remaining=$((MAX_SECONDS-e)); [ "$max_remaining" -lt 0 ] && max_remaining=0
  pc="$(progress_counts "$nd")"; completed="${pc%%|*}"; restpc="${pc#*|}"; total_tests="${restpc%%|*}"; restpc="${restpc#*|}"; remaining_tests="${restpc%%|*}"; progress_percent="${restpc##*|}"
  result_type="$(cat "$d/result_type" 2>/dev/null)"
  [ -n "$result_type" ] || result_type="none"
  queue_pos="$(queue_position "$nd")"
  source="$(cat "$d/source" 2>/dev/null)"; [ -n "$source" ] || source="manual"
  auto_apply="$(cat "$d/auto_apply" 2>/dev/null)"; [ -n "$auto_apply" ] || auto_apply="${KZSC_BLOCKCHECK_AUTO_APPLY:-1}"
  applied_profile="$(cat "$d/applied_profile" 2>/dev/null)"

  # `stopped` is an event, not a persistent active state. Once no worker is
  # running, present the WAN as ready again on subsequent refreshes.
  if [ "$state" = "stopped" ]; then
    state="idle"
    echo idle >"$d/state"
  fi

  # Idle cards must not keep stale elapsed/stage/result information from an
  # aborted previous Blockcheck run.
  if [ "$state" = "queued" ]; then
    p=""
    stage="Sırada · diğer WAN Blockcheck tamamlandığında otomatik başlayacak."
  fi

  if [ "$state" = "idle" ]; then
    p=""
    e=0
    stage="Hazırlanıyor"
    started=0
    ended=0
    job_rc=""
    sum=""
    result_type="none"
    # An idle WAN must not expose progress counters from a completed or
    # interrupted run; those counters made a finished test look active after
    # a reboot.
    completed=0
    total_tests=0
    remaining_tests=0
    progress_percent=0
  fi

  isolated=false
  /opt/kzsc/bin/kzsc-isolation.sh is-active "$nd" >/dev/null 2>&1 && isolated=true
  [ -n "$started" ] || started=0
  [ -n "$ended" ] || ended=0
  [ -n "$job_rc" ] || job_rc=""
  out="$d/state.json.tmp.$$"
  printf '{"id":"%s","ndmc":"%s","linux":"%s","isp":"%s","state":"%s","pid":"%s","started":%s,"ended":%s,"elapsed":%s,"stage":"%s","rc":"%s","summary":"%s","isolated":%s,"domains":"%s","result_type":"%s","scanlevel":"%s","estimate":"%s","queue_pos":%s,"source":"%s","auto_apply":%s,"applied_profile":"%s","completed_tests":%s,"total_tests":%s,"remaining_tests":%s,"progress_percent":%s,"max_seconds":%s,"max_remaining":%s}\n' \
    "$(json_escape "$(safe_id "$nd")")" "$(json_escape "$nd")" "$(json_escape "$lin")" \
    "$(json_escape "$isp")" "$(json_escape "$state")" "$(json_escape "$p")" \
    "$started" "$ended" "$e" "$(json_escape "$stage")" "$(json_escape "$job_rc")" "$(json_escape "$sum")" "$isolated" \
    "$(json_escape "$domains")" "$(json_escape "$result_type")" "$(json_escape "$scanlevel")" "$(json_escape "$estimate")" \
    "${queue_pos:-0}" "$(json_escape "$source")" "$([ "$auto_apply" = 1 ] && echo true || echo false)" "$(json_escape "$applied_profile")" "$completed" "$total_tests" "$remaining_tests" "$progress_percent" "$max_seconds" "$max_remaining" >"$out"
  mv "$out" "$d/state.json"
}

write_all_json(){
  local tmp body first count running nd d
  tmp="$WWW/blockcheck.json.tmp.$$"
  body="$ROOT/.body.$$"
  : >"$body"
  first=1
  count=0
  running=0
  for nd in $(internet_wans); do
    write_one_state "$nd"
    d="$(job_dir "$nd")"
    [ "$first" -eq 1 ] || printf ',\n' >>"$body"
    first=0
    cat "$d/state.json" >>"$body"
    count=$((count+1))
    is_running "$nd" && running=$((running+1))
  done
  {
    printf '{"count":%s,"running":%s,"jobs":[\n' "$count" "$running"
    cat "$body"
    printf '\n]}\n'
  } >"$tmp"
  rm -f "$body"
  mv "$tmp" "$WWW/blockcheck.json"
  chmod 644 "$WWW/blockcheck.json" 2>/dev/null || true
  cat "$WWW/blockcheck.json"
}

prepare_run_tree(){
  local nd="$1" d
  d="$(job_dir "$nd")"
  rm -rf "$d/run"
  mkdir -p "$d/run"
  # Give blockcheck an isolated writable working copy while using KZSC-owned
  # official Zapret2 files. This avoids sharing summary/temp files between jobs.
  cp -R "$ZROOT"/. "$d/run"/ || return 1
}

kill_tree(){
  local p="$1" c
  case "$p" in ''|*[!0-9]*) return 0;; esac
  [ -r "/proc/$p/task/$p/children" ] && for c in $(cat "/proc/$p/task/$p/children" 2>/dev/null); do kill_tree "$c"; done
  kill "$p" 2>/dev/null || true
}
kill_tree_hard(){
  local p="$1" c
  case "$p" in ''|*[!0-9]*) return 0;; esac
  [ -r "/proc/$p/task/$p/children" ] && for c in $(cat "/proc/$p/task/$p/children" 2>/dev/null); do kill_tree_hard "$c"; done
  kill -9 "$p" 2>/dev/null || true
}
cleanup_temp_chains(){
  local c h
  # Blockcheck2 creates global temporary chains. KZSC serializes Blockcheck jobs,
  # so when the active job is stopped/times out these chains belong to that job.
  for c in $(iptables-save -t mangle 2>/dev/null | awk '/^:blockcheck_(input|output)_[0-9]+ / {sub(/^:/,"",$1); print $1}'); do
    for h in INPUT OUTPUT FORWARD PREROUTING POSTROUTING; do
      while iptables -t mangle -D "$h" -j "$c" 2>/dev/null; do :; done
    done
    iptables -t mangle -F "$c" 2>/dev/null || true
    iptables -t mangle -X "$c" 2>/dev/null || true
  done
}

cleanup_job_children(){
  local nd="$1" d p cmd
  d="$(job_dir "$nd")"
  # A child may be re-parented before the worker exits. Do not rely solely on
  # /proc/<parent>/children; kill every process executing from this WAN run tree.
  for p in $(ps w 2>/dev/null | awk -v d="$d/run/" 'index($0,d)>0 && $0 !~ /awk/ {print $1}'); do
    case "$p" in ''|*[!0-9]*) continue;; esac
    kill "$p" 2>/dev/null || true
  done
  sleep 1
  for p in $(ps w 2>/dev/null | awk -v d="$d/run/" 'index($0,d)>0 && $0 !~ /awk/ {print $1}'); do
    case "$p" in ''|*[!0-9]*) continue;; esac
    kill -9 "$p" 2>/dev/null || true
  done
}

cleanup_upstream(){
  local nd="$1" d up
  d="$(job_dir "$nd")"; up="$(cat "$d/upstream_pid" 2>/dev/null)"
  if [ -n "$up" ]; then
    kill_tree "$up"
    sleep 1
    kill -0 "$up" 2>/dev/null && kill_tree_hard "$up" || true
  fi
  cleanup_job_children "$nd"
  cleanup_temp_chains
  rm -f "$d/upstream_pid"
}
worker_restore(){
  local nd="$1"
  /opt/kzsc/bin/kzsc-isolation.sh restore "$nd" >>"$(job_dir "$nd")/blockcheck.log" 2>&1
}
worker_signal_cleanup(){
  local nd="$1"
  cleanup_upstream "$nd" >/dev/null 2>&1 || true
  worker_restore "$nd" >/dev/null 2>&1 || true
}

run_worker(){
  local nd="$1" d lin run log worker_rc sum premsg pre_rc isolated restore_rc curlwrap domains result_type scanlevel auto_apply apply_msg applied_profile source force_enable worker_started deadline now
  isolated=0
  d="$(job_dir "$nd")"
  mkdir -p "$d"
  worker_started="$(date +%s)"
  deadline=$((worker_started+MAX_SECONDS))
  WORKER_DEADLINE="$deadline"
  echo "KZSC worker entered pid=$$ ndmc=$nd" >>"$d/launcher.log"
  lin="$(linux_for "$nd")"
  if [ -z "$lin" ]; then
    echo 11 >"$d/rc"
    date +%s >"$d/ended"
    echo failed >"$d/state"
    echo "KZSC: Linux WAN interface çözümlenemedi: $nd" >>"$d/blockcheck.log"
    rm -f "$d/pid"
    exit 11
  fi

  echo $$ >"$d/pid"
  printf '%s\n' "$worker_started" >"$d/started"
  rm -f "$d/ended" "$d/rc" "$d/summary.txt" "$d/result_type"
  domains="$(get_domains "$nd")"
  scanlevel="$(get_scanlevel "$nd")"
  auto_apply="$(cat "$d/auto_apply" 2>/dev/null)"; [ -n "$auto_apply" ] || auto_apply="${KZSC_BLOCKCHECK_AUTO_APPLY:-1}"
  source="$(cat "$d/source" 2>/dev/null)"; [ -n "$source" ] || source="manual"
  force_enable="$(cat "$d/force_enable" 2>/dev/null)"; [ -n "$force_enable" ] || force_enable=0

  # Phase 1: validate known KZSC presets first. If a preset already gives
  # reliable HTTP + HTTPS/TLS connectivity for all configured targets, there is
  # no value in spending minutes on the broad strategy search.
  : >"$d/blockcheck.log"
  if preset_first_probe "$nd" "$lin" "$domains" "$auto_apply" "$force_enable"; then
    if [ "$(date +%s)" -ge "$deadline" ]; then
      echo 124 >"$d/rc"; date +%s >"$d/ended"; echo timeout >"$d/state"; rm -f "$d/pid"
      echo "KZSC: Mutlak Blockcheck süresi (${MAX_SECONDS}s) preset aşamasında doldu." >>"$d/blockcheck.log"
      write_all_json >/dev/null 2>&1 || true
      exit 124
    fi
    echo 0 >"$d/rc"
    date +%s >"$d/ended"
    echo success >"$d/state"
    rm -f "$d/pid"
    write_all_json >/dev/null 2>&1 || true
    applied_profile="$(cat "$d/applied_profile" 2>/dev/null)"
    /opt/kzsc/bin/kzsc-oplog.sh append "blockcheck_complete:$nd" true "$(isp_for "$nd") Blockcheck preset-first tamamlandı · doğrulanan profil: ${applied_profile:-preset} · geniş tarama atlandı." "blockcheck-result-$(date +%s)-$$" >/dev/null 2>&1 || true
    exit 0
  fi

  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo 124 >"$d/rc"; date +%s >"$d/ended"; echo timeout >"$d/state"; rm -f "$d/pid"
    echo "KZSC: Mutlak Blockcheck süresi (${MAX_SECONDS}s) preset aşamasında doldu." >>"$d/blockcheck.log"
    write_all_json >/dev/null 2>&1 || true
    exit 124
  fi

  premsg="$(blockcheck_preflight "$nd" "$lin" 2>&1)"
  pre_rc=$?
  if [ "$pre_rc" -ne 0 ]; then
    printf '%s\n' "$premsg" >"$d/blockcheck.log"
    echo "$pre_rc" >"$d/rc"
    date +%s >"$d/ended"
    echo blocked >"$d/state"
    rm -f "$d/pid"
    write_all_json >/dev/null 2>&1 || true
    exit 0
  fi

  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo 124 >"$d/rc"; date +%s >"$d/ended"; echo timeout >"$d/state"; rm -f "$d/pid"
    printf '%s\n' 'KZSC: Mutlak Blockcheck süresi ön kontrolde doldu.' >"$d/blockcheck.log"
    write_all_json >/dev/null 2>&1 || true
    exit 124
  fi

  if ! /opt/kzsc/bin/kzsc-isolation.sh activate "$nd" "$lin" "$$" >"$d/isolation.log" 2>&1; then
    cat "$d/isolation.log" >"$d/blockcheck.log" 2>/dev/null || true
    echo 32 >"$d/rc"
    date +%s >"$d/ended"
    echo blocked >"$d/state"
    rm -f "$d/pid"
    write_all_json >/dev/null 2>&1 || true
    exit 0
  fi
  isolated=1
  trap 'worker_signal_cleanup "$nd"' INT TERM HUP EXIT

  echo running >"$d/state"

  prepare_run_tree "$nd" || {
    echo 12 >"$d/rc"; date +%s >"$d/ended"; echo failed >"$d/state"; rm -f "$d/pid"; exit 12;
  }

  run="$d/run"
  log="$d/blockcheck.log"
  echo "KZSC PRESET-FIRST: Entering broad upstream Blockcheck phase." >>"$log"

  curlwrap="$d/curl-iface.sh"
  cat >"$curlwrap" <<EOF
#!/opt/bin/sh
exec curl --interface "$lin" "\$@"
EOF
  chmod 755 "$curlwrap"

  # Generic WAN isolation:
  # - the selected Linux WAN is exported with common interface variable names
  #   used by zapret ecosystems;
  # - routing is NOT mutated here;
  # - unrelated NFQUEUE rules are not modified here.
  #
  # Upstream blockcheck versions differ in accepted environment knobs, so KZSC
  # exports multiple harmless aliases and records the chosen WAN in the log.
  {
    echo "KZSC_BLOCKCHECK_WAN=$nd"
    echo "KZSC_BLOCKCHECK_LINUX_IF=$lin"
    echo "KZSC_BLOCKCHECK_DOMAINS=$domains"
    echo "KZSC_BLOCKCHECK_SCANLEVEL=$scanlevel"
    echo "KZSC_BLOCKCHECK_STARTED=$(date)"
  } >>"$log"

  (
    cd "$run" || exit 20
    export ZAPRET_BASE="$run"
    export ZAPRET_RW="$run"
    export IFACE_WAN="$lin"
    export WAN_IFACE="$lin"
    export IFACE="$lin"
    export KZSC_WAN_IFACE="$lin"
    export CURL="$curlwrap"
    export DOMAINS_DEFAULT="$domains"
    # KZSC exposes one Blockcheck mode. Upstream quick is used internally,
    # while KZSC enforces the real wall-clock limit independently.
    export SCANLEVEL=quick
    export BATCH=1
    exec sh ./blockcheck2.sh
  ) >>"$log" 2>&1 &
  upstream_pid=$!
  echo "$upstream_pid" >"$d/upstream_pid"
  timed_out=0
  while kill -0 "$upstream_pid" 2>/dev/null; do
    now=$(date +%s)
    if [ "$now" -ge "$deadline" ]; then
      timed_out=1
      echo "KZSC: Maksimum Blockcheck süresi (${MAX_SECONDS}s) doldu; upstream test kontrollü sonlandırılıyor." >>"$log"
      cleanup_upstream "$nd"
      break
    fi
    sleep 2
  done
  if [ "$timed_out" -eq 0 ]; then
    wait "$upstream_pid"
    worker_rc=$?
    rm -f "$d/upstream_pid"
  else
    worker_rc=124
  fi
  case "$worker_rc" in ''|*[!0-9]*) worker_rc=99;; esac

  # blockcheck2 prints SUMMARY to stdout. Capture it from the per-WAN log,
  # independent of whether a future upstream version also creates a file.
  extract_summary "$log" "$d/summary.txt" || true
  result_type="$(classify_summary "$d/summary.txt")"
  printf '%s
' "$result_type" >"$d/result_type"

  restore_rc=0
  if [ "$isolated" -eq 1 ]; then
    /opt/kzsc/bin/kzsc-isolation.sh restore "$nd" >>"$log" 2>&1 || restore_rc=$?
    isolated=0
  fi
  trap - INT TERM HUP EXIT

  [ "$restore_rc" -eq 0 ] || worker_rc=70

  apply_msg=""
  if [ "$restore_rc" -eq 0 ] && [ "$worker_rc" -eq 0 ] && [ "$result_type" = "profile_found" ] && [ "$auto_apply" = 1 ]; then
    apply_msg="$(auto_apply_result "$nd" "$d/summary.txt" "$force_enable" 2>&1)"
    apply_rc=$?
    if [ "$apply_rc" -eq 0 ]; then
      applied_profile="$(cat "$d/applied_profile" 2>/dev/null)"
    else
      printf '%s\n' "$apply_msg" >>"$log"
    fi
  fi

  echo "$worker_rc" >"$d/rc"
  date +%s >"$d/ended"
  rm -f "$d/pid"
  if [ "$restore_rc" -ne 0 ]; then
    echo restore_failed >"$d/state"
  elif [ "$worker_rc" -eq 124 ]; then
    echo timeout >"$d/state"
  elif [ "$worker_rc" -eq 0 ]; then
    echo success >"$d/state"
  else
    echo failed >"$d/state"
  fi
  write_all_json >/dev/null 2>&1 || true
  if [ "$restore_rc" -ne 0 ]; then
    /opt/kzsc/bin/kzsc-oplog.sh append "blockcheck_complete:$nd" false "$(isp_for "$nd") Blockcheck tamamlandı fakat NFQUEUE restore başarısız · rc=$worker_rc" "blockcheck-result-$(date +%s)-$$" >/dev/null 2>&1 || true
  elif [ "$worker_rc" -eq 0 ]; then
    if [ -n "$applied_profile" ]; then
      msg="$(isp_for "$nd") Blockcheck tamamlandı · mod=$scanlevel · otomatik uygulandı: $applied_profile"
    elif [ "$result_type" = "no_bypass_needed" ]; then
      msg="$(isp_for "$nd") Blockcheck tamamlandı · bypass gerekmiyor; mevcut DPI profili değiştirilmedi."
    elif [ "$result_type" = "profile_found" ]; then
      msg="$(isp_for "$nd") Blockcheck tamamlandı · strateji bulundu fakat otomatik uygulama yapılamadı${apply_msg:+: $apply_msg}"
    else
      msg="$(isp_for "$nd") Blockcheck tamamlandı · uygulanabilir nfqws2 stratejisi bulunamadı."
    fi
    /opt/kzsc/bin/kzsc-oplog.sh append "blockcheck_complete:$nd" true "$msg" "blockcheck-result-$(date +%s)-$$" >/dev/null 2>&1 || true
  elif [ "$worker_rc" -eq 124 ]; then
    /opt/kzsc/bin/kzsc-oplog.sh append "blockcheck_complete:$nd" false "$(isp_for "$nd") Blockcheck mutlak ${MAX_SECONDS} saniye sınırında sonlandırıldı; mevcut DPI profili korundu." "blockcheck-result-$(date +%s)-$$" >/dev/null 2>&1 || true
  else
    /opt/kzsc/bin/kzsc-oplog.sh append "blockcheck_complete:$nd" false "$(isp_for "$nd") Blockcheck başarısız · rc=$worker_rc" "blockcheck-result-$(date +%s)-$$" >/dev/null 2>&1 || true
  fi
  exit "$worker_rc"
}

start_job(){
  local nd="$1" override="$2" scan_override="$3" source_override="${4:-manual}" force_enable="${5:-0}" d lin domains scan autoapply source busy
  wan_exists "$nd" || { echo "WAN bulunamadı: $nd" >&2; return 1; }
  [ -x "$ZROOT/blockcheck2.sh" ] || { echo "KZSC Zapret2/blockcheck2 hazır değil." >&2; return 1; }
  is_running "$nd" && { echo "$nd için Blockcheck zaten çalışıyor." >&2; return 1; }
  [ -n "$(queued_for "$nd" 2>/dev/null || true)" ] && { echo "$nd için Blockcheck zaten sırada."; return 0; }

  if [ -n "$override" ]; then set_domains "$nd" "$override" >/dev/null || return 1; fi
  if [ -n "$scan_override" ]; then set_scanlevel "$nd" "$scan_override" >/dev/null || return 1; fi
  domains="$(get_domains "$nd")"; scan="quick"
  autoapply="${KZSC_BLOCKCHECK_AUTO_APPLY:-1}"; source="${source_override:-manual}"

  # Upstream blockcheck uses global temporary NFQUEUE hooks. Never run two
  # WAN blockchecks concurrently: queue the second request instead of failing
  # isolation with code 30.
  if any_running || upstream_blockcheck_rules_active; then
    enqueue_job "$nd" "$domains" "$scan" "$autoapply" "$source" "$force_enable"
    return $?
  fi

  d="$(job_dir "$nd")"; mkdir -p "$d"
  printf '%s
' "$autoapply" >"$d/auto_apply"; printf '%s
' "$source" >"$d/source"; printf '%s
' "$force_enable" >"$d/force_enable"
  launch_job "$nd"
}

stop_job(){
  local nd="$1" d p
  wan_exists "$nd" || { echo "WAN bulunamadı: $nd" >&2; return 1; }
  d="$(job_dir "$nd")"
  p="$(cat "$d/pid" 2>/dev/null)"
  if [ -z "$p" ]; then
    if [ -n "$(queued_for "$nd" 2>/dev/null || true)" ]; then
      remove_queued "$nd"; echo idle >"$d/state"; rm -f "$d/started" "$d/ended" "$d/rc" "$d/result_type" "$d/summary.txt"
      write_all_json >/dev/null 2>&1 || true
      echo "$nd sıradaki Blockcheck isteği iptal edildi."; return 0
    fi
    echo "$nd için çalışan Blockcheck yok."; return 0
  fi
  cleanup_upstream "$nd" >/dev/null 2>&1 || true
  kill "$p" 2>/dev/null || true
  sleep 2
  kill -0 "$p" 2>/dev/null && kill -9 "$p" 2>/dev/null || true
  # If TERM arrived while the worker was waiting on upstream, make cleanup and
  # restore explicit as a second idempotent safety net.
  cleanup_job_children "$nd" >/dev/null 2>&1 || true
  cleanup_temp_chains >/dev/null 2>&1 || true
  /opt/kzsc/bin/kzsc-isolation.sh restore "$nd" >/dev/null 2>&1 || true
  /opt/kzsc/bin/kzsc-native-dpi.sh ensure "$nd" >/dev/null 2>&1 || true
  rm -f "$d/pid" "$d/upstream_pid"

  # Stop is immediately reflected as a ready WAN. Keep diagnostic logs, but
  # reset timing/result files so an idle card cannot inherit stale elapsed time.
  rm -f "$d/started" "$d/ended" "$d/rc" "$d/result_type" "$d/summary.txt" "$d/applied_profile"
  echo idle >"$d/state"
  write_all_json >/dev/null
  echo "$nd Blockcheck durduruldu. WAN tekrar hazır."
}

# A router reboot cannot safely resume an upstream Blockcheck process: its
# temporary NFQUEUE chains, isolation state and child PIDs no longer exist.
# Clear only jobs that were active at boot, while retaining their log for
# diagnosis.  This is deliberately explicit so queued manual requests are not
# silently dispatched after a restart.
boot_reconcile(){
  local boot_file="$ROOT/boot-id" boot_id d nd state p
  boot_id="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || true)"
  [ -n "$boot_id" ] || return 0
  [ "$(cat "$boot_file" 2>/dev/null)" = "$boot_id" ] && return 0
  mkdir -p "$ROOT"
  printf '%s\n' "$boot_id" >"$boot_file"
  for d in "$ROOT"/*; do
    [ -d "$d" ] || continue
    nd="$(cat "$d/ndmc" 2>/dev/null)"
    [ -n "$nd" ] || nd="$(basename "$d")"
    state="$(cat "$d/state" 2>/dev/null)"
    case "$state" in
      running|queued)
        p="$(cat "$d/pid" 2>/dev/null)"
        [ -n "$p" ] && kill "$p" 2>/dev/null || true
        cleanup_job_children "$nd" >/dev/null 2>&1 || true
        cleanup_temp_chains >/dev/null 2>&1 || true
        /opt/kzsc/bin/kzsc-isolation.sh restore "$nd" >/dev/null 2>&1 || true
        rm -f "$d/pid" "$d/upstream_pid"
        for f in "$QUEUE_DIR"/*.req; do
          [ -f "$f" ] || continue
          [ "$(sed -n 's/^NDMC=//p' "$f" | head -n1)" = "$nd" ] && rm -f "$f"
        done
        printf '%s\n' 'KZSC: Router yeniden başlatıldığı için önceki Blockcheck iptal edildi.' >>"$d/blockcheck.log"
        date +%s >"$d/ended"
        echo 125 >"$d/rc"
        echo stopped >"$d/state"
        ;;
    esac
  done
}

case "$1" in
  start) start_job "$2" "$3" "$4" manual 0 ;;
  auto-start) start_job "$2" "" quick wan_reconcile "${3:-1}" ;;
  stop) stop_job "$2" ;;
  boot-reconcile) boot_reconcile ;;
  set-domains) set_domains "$2" "$3" ;;
  get-domains) get_domains "$2" ;;
  set-mode) set_scanlevel "$2" "$3" ;;
  get-mode) get_scanlevel "$2" ;;
  status|json) write_all_json ;;
  refresh) schedule_tick >/dev/null 2>&1 || true; dispatch_queue >/dev/null 2>&1 || true; write_all_json >/dev/null ;;
  dispatch) dispatch_queue ;;
  schedule-tick) schedule_tick ;;
  _worker) run_worker "$2" ;;
  *)
    echo "Usage: kzsc-blockcheck {start NDMC_WAN|auto-start NDMC_WAN [FORCE_ENABLE]|stop NDMC_WAN|set-domains NDMC_WAN \"domain1 domain2\"|get-domains NDMC_WAN|status|refresh}"
    exit 1
    ;;
esac
