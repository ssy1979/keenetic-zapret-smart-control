#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

REG_STATE="$KZSC_HOME/var/dpi/wan-registry"
ENG_ROOT="$KZSC_HOME/var/dpi/engines"
OUT="$KZSC_HOME/www/data/engines.json"
KZSC_Z2="$KZSC_HOME/zapret2"

mkdir -p "$REG_STATE" "$ENG_ROOT" "$KZSC_HOME/www/data"

safe_id(){
  local v="$1"
  printf '%s' "$v" | tr ' A-Z/:.' '_a-z___' | tr -cd 'a-z0-9_-'
}

queue_for_nd(){
  local nd="$1" f
  f="$REG_STATE/$(safe_id "$nd").queue"
  [ -f "$f" ] && head -n1 "$f" 2>/dev/null
}

profile_for_nd(){
  local nd="$1" f
  f="$REG_STATE/$(safe_id "$nd").profile"
  [ -f "$f" ] && head -n1 "$f" 2>/dev/null || echo "unassigned"
}
mode_for_nd(){ /opt/kzsc/bin/kzsc-dpi-policy.sh get-mode "$1" 2>/dev/null || echo all; }

external_queue_for_iface(){
  local ifc="$1"

  iptables-save -t mangle 2>/dev/null | awk -v i="$ifc" '
    (index($0,"-o " i " ") || index($0,"-i " i " ")) && index($0,"NFQUEUE") {
      for(n=1;n<=NF;n++) if($n=="--queue-num"){print $(n+1); exit}
    }'
}

zapret_ready(){
  [ -x "$KZSC_Z2/nfq2/nfqws2" ] &&
  [ -f "$KZSC_Z2/lua/zapret-lib.lua" ]
}

engine_dir(){
  local nd="$1"
  echo "$ENG_ROOT/$(safe_id "$nd")"
}

prepare_one(){
  local nd="$1" lin q isp d
  lin="$(linux_if_for_ndmc "$nd")"
  [ -n "$lin" ] || return 1
  q="$(queue_for_nd "$nd")"
  [ -n "$q" ] || return 1
  isp="$(isp_label "$nd")"; [ -n "$isp" ] || isp="$nd"
  d="$(engine_dir "$nd")"
  mkdir -p "$d"
  cat >"$d/meta.conf" <<EOF
ENGINE_ID=$(safe_id "$nd")
NDMC_WAN=$nd
LINUX_WAN=$lin
ISP_LABEL=$isp
QUEUE=$q
PROFILE=$(profile_for_nd "$nd")
EOF
  [ -f "$d/enabled" ] || : >"$d/prepared"
  return 0
}

prepare_all(){
  local count nd
  /opt/kzsc/bin/kzsc-wan-registry.sh refresh >/dev/null 2>&1 || true
  count=0
  for nd in $(internet_wans); do
    prepare_one "$nd" && count=$((count+1))
  done
  write_json >/dev/null
  echo "$count WAN için KZSC motor tanımı hazırlandı. Motorlar otomatik olarak başlatılmadı."
}

ensure_all(){
  local nd
  /opt/kzsc/bin/kzsc-wan-registry.sh refresh >/dev/null 2>&1 || true
  for nd in $(internet_wans); do
    prepare_one "$nd" >/dev/null 2>&1 || true
  done
  write_json >/dev/null
}

engine_pid_state(){
  local d="$1" p q cmd
  p="$(cat "$d/pid" 2>/dev/null)"
  q="$(sed -n 's/^QUEUE=//p' "$d/meta.conf" 2>/dev/null | head -n1)"
  [ -n "$p" ] && [ -n "$q" ] || { echo stopped; return; }
  kill -0 "$p" 2>/dev/null || { echo stopped; return; }
  [ -r "/proc/$p/cmdline" ] || { echo stopped; return; }
  cmd="$(tr '\000' ' ' <"/proc/$p/cmdline" 2>/dev/null)"
  printf '%s\n' "$cmd" | grep -Fq "$KZSC_Z2/nfq2/nfqws2" || { echo stopped; return; }
  printf '%s\n' "$cmd" | grep -Fq -- "--qnum=$q" || { echo stopped; return; }
  echo running
}

pid_state(){ engine_pid_state "$1"; }

write_json(){
  local tmp body first count zready nd lin q isp d prof mode external state pid enabled any_enabled
  any_enabled=false
  /opt/kzsc/bin/kzsc-wan-registry.sh refresh >/dev/null 2>&1 || true
  tmp="$OUT.tmp.$$"
  body="$ENG_ROOT/.engines.body.$$"
  : >"$body"
  first=1
  count=0
  zready=false; zapret_ready && zready=true

  for nd in $(internet_wans); do
    lin="$(linux_if_for_ndmc "$nd")"
    [ -n "$lin" ] || continue
    q="$(queue_for_nd "$nd")"
    [ -n "$q" ] || continue
    isp="$(isp_label "$nd")"; [ -n "$isp" ] || isp="$nd"
    d="$(engine_dir "$nd")"
    prof="$(profile_for_nd "$nd")"
    mode="$(mode_for_nd "$nd")"
    external="$(external_queue_for_iface "$lin")"
    state="not_prepared"
    [ -f "$d/prepared" ] && state="prepared"
    enabled=false
    if [ -f "$d/enabled" ]; then
      state="$(engine_pid_state "$d")"
      enabled=true
      [ "$state" = running ] && any_enabled=true
    fi
    pid="$(cat "$d/pid" 2>/dev/null)"
    [ -n "$pid" ] || pid=""

    [ "$first" -eq 1 ] || printf ',\n' >>"$body"
    first=0
    count=$((count+1))
    printf '{"id":"%s","ndmc":"%s","linux":"%s","isp":"%s","queue":%s,"profile":"%s","mode":"%s","state":"%s","pid":"%s","external_queue":"%s","enabled":%s}' \
      "$(json_escape "$(safe_id "$nd")")" "$(json_escape "$nd")" "$(json_escape "$lin")" \
      "$(json_escape "$isp")" "$q" "$(json_escape "$prof")" "$(json_escape "$mode")" "$(json_escape "$state")" \
      "$(json_escape "$pid")" "$(json_escape "$external")" "$enabled" >>"$body"
  done

  {
    printf '{"count":%s,"zapret2_ready":%s,"any_enabled":%s,"engines":[\n' "$count" "$zready" "$any_enabled"
    cat "$body"
    printf '\n]}\n'
  } >"$tmp"
  rm -f "$body"
  mv "$tmp" "$OUT"
  chmod 644 "$OUT" 2>/dev/null || true
  cat "$OUT"
}

set_profile(){
  local nd="$1" profile="$2" found x
  [ -n "$nd" ] && [ -n "$profile" ] || {
    echo "Usage: kzsc engines set-profile NDMC_WAN PROFILE" >&2
    return 1
  }
  found=0
  for x in $(internet_wans); do [ "$x" = "$nd" ] && found=1; done
  [ "$found" -eq 1 ] || { echo "WAN bulunamadı: $nd" >&2; return 1; }
  case "$profile" in *[!A-Za-z0-9_.-]*|'') echo "Geçersiz profil adı." >&2; return 1;; esac
  echo "$profile" >"$REG_STATE/$(safe_id "$nd").profile"
  prepare_one "$nd"
  write_json >/dev/null
  echo "$nd -> $profile olarak kaydedildi. Motor durumu değiştirilmedi."
}

enable_one(){
  local nd="$1"
  prepare_one "$nd" || return 1
  /opt/kzsc/bin/kzsc-native-dpi.sh enable "$nd" || return $?
  write_json >/dev/null
}

disable_one(){
  local nd="$1"
  /opt/kzsc/bin/kzsc-native-dpi.sh disable "$nd" || return $?
  write_json >/dev/null
}

enable_all(){
  local nd rc=0
  for nd in $(internet_wans); do
    enable_one "$nd" || rc=1
  done
  return "$rc"
}

disable_all(){
  local nd
  for nd in $(internet_wans); do disable_one "$nd" >/dev/null 2>&1 || true; done
  write_json >/dev/null
}

reconfigure_one(){
  local nd="$1"
  prepare_one "$nd" || return 1
  /opt/kzsc/bin/kzsc-native-dpi.sh reconfigure "$nd" || return $?
  write_json >/dev/null
}


case "$1" in
  status|json) write_json ;;
  refresh) ensure_all ;;
  prepare) prepare_all ;;
  set-profile) set_profile "$2" "$3" ;;
  enable) enable_one "$2" ;;
  disable) disable_one "$2" ;;
  reconfigure) reconfigure_one "$2" ;;
  enable-all) enable_all ;;
  disable-all) disable_all ;;
  *)
    echo "Usage: kzsc-engines {status|refresh|prepare|set-profile NDMC_WAN PROFILE|enable NDMC_WAN|disable NDMC_WAN|reconfigure NDMC_WAN|enable-all|disable-all}"
    exit 1
    ;;
esac
