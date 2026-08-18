#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

ROOT="$KZSC_HOME/var/reconcile"
LAST="$ROOT/wan-bindings.tsv"
DEFAULT_LAST="$ROOT/default-wan.last"
PENDING="$ROOT/pending"
VALIDATED="$ROOT/validated"
STATUS="$KZSC_HOME/www/data/reconcile.json"
LAST_CHANGE="$ROOT/last-change.tsv"
LAST_VALIDATION="$ROOT/last-validation.tsv"
CHANGES="$ROOT/changes.$$"
CURRENT="$ROOT/current.$$"
RETRY_SECONDS="${KZSC_WAN_REVALIDATE_RETRY_SECONDS:-21600}"
AUTO_VALIDATE="${KZSC_WAN_AUTO_VALIDATE:-1}"
AUTO_ENABLE_NEW="${KZSC_WAN_AUTO_ENABLE_NEW:-1}"

mkdir -p "$ROOT" "$PENDING" "$VALIDATED" "$KZSC_HOME/www/data"

safe_id(){
  printf '%s' "$1" | tr ' A-Z/:.' '_a-z___' | tr -cd 'a-z0-9_-'
}

reg_q(){
  head -n1 "$KZSC_HOME/var/dpi/wan-registry/$(safe_id "$1").queue" 2>/dev/null
}
reg_profile(){
  head -n1 "$KZSC_HOME/var/dpi/wan-registry/$(safe_id "$1").profile" 2>/dev/null
}
engine_enabled(){
  [ -f "$KZSC_HOME/var/dpi/engines/$(safe_id "$1")/enabled" ] && echo 1 || echo 0
}
profile_valid(){
  case "$1" in
    kablonet|sol|tt-fiber|vodafone|vodafone-tt|vodafone-tt2) [ -f "$KZSC_HOME/share/dpi-presets/$1.conf" ] ;;
    auto_*) [ -f "$KZSC_HOME/var/dpi/auto-presets/$1.conf" ] ;;
    *) return 1 ;;
  esac
}

snapshot(){
  for nd in $(internet_wans); do
    lin="$(linux_if_for_ndmc "$nd")"
    isp="$(isp_label "$nd")"; [ -n "$isp" ] || isp="$nd"
    state="$(iface_state "$nd")"; [ -n "$state" ] || state="unknown"
    def="$(iface_defaultgw "$nd")"
    pri="$(iface_priority "$nd")"
    q="$(reg_q "$nd")"
    prof="$(reg_profile "$nd")"; [ -n "$prof" ] || prof="unassigned"
    en="$(engine_enabled "$nd")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$nd" "$lin" "$isp" "$state" "$def" "$pri" "$q" "$prof" "$en"
  done
}

field(){
  # field LINE NUMBER
  printf '%s\n' "$1" | cut -f"$2"
}

line_by_nd(){
  f="$1"; nd="$2"
  [ -f "$f" ] || return 0
  awk -F '\t' -v n="$nd" '$1==n {print; exit}' "$f"
}

line_by_isp(){
  f="$1"; isp="$2"
  [ -f "$f" ] || return 0
  awk -F '\t' -v x="$isp" '$3==x {print; exit}' "$f"
}

current_has_nd(){
  nd="$1"
  awk -F '\t' -v n="$nd" '$1==n {found=1} END{exit !found}' "$CURRENT"
}

pending_file(){
  echo "$PENDING/$(safe_id "$1").pending"
}

pending_write(){
  nd="$1"; isp="$2"; lin="$3"; reason="$4"; force="$5"; now="$6"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$nd" "$isp" "$lin" "$reason" "$force" "$now" >"$(pending_file "$nd")"
}

pending_count(){
  n=0
  for f in "$PENDING"/*.pending; do [ -f "$f" ] && n=$((n+1)); done
  echo "$n"
}

record_change(){
  rc_kind="$1"; rc_nd="$2"; rc_lin="$3"; rc_isp="$4"; rc_reason="$5"; rc_msg="$6"; rc_ts="${7:-$(date +%s)}"
  rc_msg="$(printf '%s' "$rc_msg" | tr '\r\n\t' '   ')"
  case "$rc_ts" in ''|*[!0-9]*) rc_ts="$(date +%s)";; esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$rc_ts" "$rc_kind" "$rc_nd" "$rc_lin" "$rc_isp" "$rc_reason" "$rc_msg" >"$LAST_CHANGE"
}

record_validation(){
  rv_nd="$1"; rv_isp="$2"; rv_lin="$3"; rv_profile="$4"; rv_result="$5"; rv_msg="$6"; rv_ts="${7:-$(date +%s)}"
  rv_msg="$(printf '%s' "$rv_msg" | tr '\r\n\t' '   ')"
  case "$rv_ts" in ''|*[!0-9]*) rv_ts="$(date +%s)";; esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$rv_ts" "$rv_nd" "$rv_isp" "$rv_lin" "$rv_profile" "$rv_result" "$rv_msg" >"$LAST_VALIDATION"
}

bootstrap_visibility(){
  # v0.11.2.1 upgrade: expose already-validated v0.11.2.0 state immediately.
  if [ ! -s "$LAST_VALIDATION" ]; then
    bv_best=0; bv_line=""
    for bv_f in "$VALIDATED"/*.tsv; do
      [ -f "$bv_f" ] || continue
      bv_x="$(cat "$bv_f" 2>/dev/null)"
      bv_ts="$(field "$bv_x" 6)"
      case "$bv_ts" in ''|*[!0-9]*) bv_ts=0;; esac
      if [ "$bv_ts" -gt "$bv_best" ]; then bv_best="$bv_ts"; bv_line="$bv_x"; fi
    done
    if [ -n "$bv_line" ]; then
      bv_nd="$(field "$bv_line" 1)"; bv_isp="$(field "$bv_line" 2)"; bv_lin="$(field "$bv_line" 3)"
      bv_profile="$(field "$bv_line" 4)"; bv_result="$(field "$bv_line" 5)"
      bv_msg="$bv_isp otomatik WAN doğrulaması tamamlandı · profil=${bv_profile:-unknown} · sonuç=${bv_result:-unknown}"
      record_validation "$bv_nd" "$bv_isp" "$bv_lin" "$bv_profile" "$bv_result" "$bv_msg" "$bv_best"
    fi
  fi

  # Recover the last topology/default-WAN change from the canonical operation log
  # so the Overview card is useful immediately after upgrade.
  if [ ! -s "$LAST_CHANGE" ] && [ -f "$KZSC_HOME/var/log/operation-log.ndjson" ]; then
    bv_hist="$(grep '"action":"wan_reconcile"' "$KZSC_HOME/var/log/operation-log.ndjson" 2>/dev/null \
      | grep -v 'otomatik WAN doğrulaması tamamlandı' \
      | grep -v 'neden=profile_missing' \
      | tail -n1)"
    if [ -n "$bv_hist" ]; then
      bv_hts="$(printf '%s\n' "$bv_hist" | sed -n 's/.*"timestamp":\([0-9][0-9]*\).*/\1/p')"
      bv_hmsg="$(printf '%s\n' "$bv_hist" | sed -n 's/.*"message":"\(.*\)","timestamp":[0-9][0-9]*}.*/\1/p')"
      [ -n "$bv_hmsg" ] && record_change history "" "" "" history "$bv_hmsg" "$bv_hts"
    fi
  fi
}

write_status(){
  event="$1"
  now="$(date +%s)"
  def="$(global_default_wan)"
  pc="$(pending_count)"
  bootstrap_visibility

  lc_json='null'
  if [ -s "$LAST_CHANGE" ]; then
    lc="$(cat "$LAST_CHANGE" 2>/dev/null)"
    lc_ts="$(field "$lc" 1)"; lc_kind="$(field "$lc" 2)"; lc_nd="$(field "$lc" 3)"; lc_lin="$(field "$lc" 4)"
    lc_isp="$(field "$lc" 5)"; lc_reason="$(field "$lc" 6)"; lc_msg="$(field "$lc" 7)"
    case "$lc_ts" in ''|*[!0-9]*) lc_ts=0;; esac
    lc_json="$(printf '{"timestamp":%s,"kind":"%s","wan":"%s","linux":"%s","isp":"%s","reason":"%s","message":"%s"}' \
      "$lc_ts" "$(json_escape "$lc_kind")" "$(json_escape "$lc_nd")" "$(json_escape "$lc_lin")" "$(json_escape "$lc_isp")" "$(json_escape "$lc_reason")" "$(json_escape "$lc_msg")")"
  fi

  lv_json='null'
  if [ -s "$LAST_VALIDATION" ]; then
    lv="$(cat "$LAST_VALIDATION" 2>/dev/null)"
    lv_ts="$(field "$lv" 1)"; lv_nd="$(field "$lv" 2)"; lv_isp="$(field "$lv" 3)"; lv_lin="$(field "$lv" 4)"
    lv_profile="$(field "$lv" 5)"; lv_result="$(field "$lv" 6)"; lv_msg="$(field "$lv" 7)"
    case "$lv_ts" in ''|*[!0-9]*) lv_ts=0;; esac
    lv_json="$(printf '{"timestamp":%s,"wan":"%s","linux":"%s","isp":"%s","profile":"%s","result":"%s","message":"%s"}' \
      "$lv_ts" "$(json_escape "$lv_nd")" "$(json_escape "$lv_lin")" "$(json_escape "$lv_isp")" "$(json_escape "$lv_profile")" "$(json_escape "$lv_result")" "$(json_escape "$lv_msg")")"
  fi

  printf '{"enabled":%s,"default_wan":"%s","pending":%s,"last_event":"%s","updated":%s,"last_change":%s,"last_validation":%s}\n' \
    "$([ "$AUTO_VALIDATE" = 1 ] && echo true || echo false)" \
    "$(json_escape "$def")" "$pc" "$(json_escape "$event")" "$now" "$lc_json" "$lv_json" >"$STATUS.tmp.$$"
  mv "$STATUS.tmp.$$" "$STATUS"
  chmod 644 "$STATUS" 2>/dev/null || true
}

log_event(){
  ok="$1"; msg="$2"; rid="wan-reconcile-$(date +%s)-$$"
  /opt/kzsc/bin/kzsc-oplog.sh append wan_reconcile "$ok" "$msg" "$rid" >/dev/null 2>&1 || true
  log "wan-reconcile: $msg"
}

cleanup_binding(){
  oldlin="$1"; oldq="$2"
  [ -n "$oldlin" ] && [ -n "$oldq" ] || return 0
  /opt/kzsc/bin/kzsc-native-dpi.sh purge-binding "$oldlin" "$oldq" >/dev/null 2>&1 || true
}

invalidate_nd(){
  nd="$1"; id="$(safe_id "$nd")"
  rm -f "$KZSC_HOME/var/dpi/wan-registry/$id.profile"
  rm -f "$KZSC_HOME/var/dpi/auto-presets/auto_$id.conf"
  rm -f "$VALIDATED/$id.tsv"
  d="$KZSC_HOME/var/dpi/engines/$id"
  rm -f "$d/enabled" "$d/pid"
  mkdir -p "$d"
  : >"$d/prepared"
}

queue_validation(){
  nd="$1"; isp="$2"; lin="$3"; reason="$4"; force="$5"
  now="$(date +%s)"
  pending_write "$nd" "$isp" "$lin" "$reason" "$force" "$now"
  start_msg="$isp bağlantısı değişti/yeni algılandı · preset-first Blockcheck otomatik başlatıldı · $nd/$lin · neden=$reason"
  case "$reason" in new_wan|binding_changed) record_change "$reason" "$nd" "$lin" "$isp" "$reason" "$start_msg" "$now";; esac
  if /opt/kzsc/bin/kzsc-blockcheck.sh auto-start "$nd" "$force" >/dev/null 2>&1; then
    log_event true "$start_msg"
    return 0
  fi
  fail_msg="$isp bağlantısı için otomatik Blockcheck başlatılamadı · $nd/$lin · neden=$reason"
  log_event false "$fail_msg"
  return 1
}

reconcile_pending(){
  [ "$AUTO_VALIDATE" = 1 ] || return 0
  now="$(date +%s)"
  for f in "$PENDING"/*.pending; do
    [ -f "$f" ] || continue
    line="$(cat "$f" 2>/dev/null)"
    nd="$(field "$line" 1)"; isp="$(field "$line" 2)"; lin="$(field "$line" 3)"
    reason="$(field "$line" 4)"; force="$(field "$line" 5)"; attempted="$(field "$line" 6)"
    [ -n "$nd" ] || { rm -f "$f"; continue; }
    current_has_nd "$nd" || { rm -f "$f"; continue; }
    curline="$(line_by_nd "$CURRENT" "$nd")"
    curstate="$(field "$curline" 4)"
    [ "$curstate" = "up" ] || continue

    d="$KZSC_HOME/var/blockcheck/$(safe_id "$nd")"
    source="$(cat "$d/source" 2>/dev/null)"
    state="$(cat "$d/state" 2>/dev/null)"
    if [ "$source" = "wan_reconcile" ]; then
      case "$state" in
        success)
          profile="$(cat "$d/applied_profile" 2>/dev/null)"
          result="$(cat "$d/result_type" 2>/dev/null)"
          valid_success=0
          case "$result" in
            preset_verified|profile_found)
              [ -n "$profile" ] && valid_success=1
              ;;
            no_bypass_needed)
              profile="none-required"
              valid_success=1
              ;;
          esac
          if [ "$valid_success" -eq 1 ]; then
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$nd" "$isp" "$lin" "$profile" "$result" "$now" \
              >"$VALIDATED/$(safe_id "$nd").tsv"
            rm -f "$f"
            validation_msg="$isp otomatik WAN doğrulaması tamamlandı · profil=${profile:-unknown} · sonuç=${result:-unknown}"
            record_validation "$nd" "$isp" "$lin" "$profile" "$result" "$validation_msg" "$now"
            log_event true "$validation_msg"
            continue
          fi
          ;;
        running|queued)
          continue
          ;;
      esac
    fi

    case "$attempted" in ''|*[!0-9]*) attempted=0;; esac
    age=$((now-attempted))
    [ "$age" -ge "$RETRY_SECONDS" ] || continue
    pending_write "$nd" "$isp" "$lin" "$reason" "$force" "$now"
    /opt/kzsc/bin/kzsc-blockcheck.sh auto-start "$nd" "$force" >/dev/null 2>&1 || true
  done
}

baseline(){
  /opt/kzsc/bin/kzsc-wan-registry.sh refresh >/dev/null 2>&1 || true
  snapshot >"$CURRENT"
  mv "$CURRENT" "$LAST"
  global_default_wan >"$DEFAULT_LAST"
  rm -f "$CHANGES"
  write_status "baseline"
  echo "KZSC WAN reconcile baseline oluşturuldu."
}

tick(){
  event=""
  /opt/kzsc/bin/kzsc-wan-registry.sh refresh >/dev/null 2>&1 || true
  snapshot >"$CURRENT"

  if [ ! -s "$LAST" ]; then
    mv "$CURRENT" "$LAST"
    global_default_wan >"$DEFAULT_LAST"
    write_status "initial-baseline"
    return 0
  fi

  # Default WAN changes must immediately be reflected by client/policy discovery,
  # but do not by themselves invalidate already verified DPI profiles.
  def_now="$(global_default_wan)"
  def_old="$(cat "$DEFAULT_LAST" 2>/dev/null)"
  if [ "$def_now" != "$def_old" ]; then
    printf '%s\n' "$def_now" >"$DEFAULT_LAST"
    event="default:${def_old:-none}->${def_now:-none}"
    def_msg="Varsayılan internet bağlantısı değişti: ${def_old:-yok} → ${def_now:-yok}. Cihaz WAN eşlemeleri yenileniyor."
    def_line="$(line_by_nd "$CURRENT" "$def_now")"
    def_lin="$(field "$def_line" 2)"; def_isp="$(field "$def_line" 3)"
    record_change default_changed "$def_now" "$def_lin" "$def_isp" default_changed "$def_msg"
    log_event true "$def_msg"
    /opt/kzsc/bin/kzsc-clients.sh >/dev/null 2>&1 || true
  fi

  : >"$CHANGES"

  # Removed WANs: remove only KZSC-owned datapath/process state recorded for
  # their old binding.
  while IFS="$(printf '\t')" read -r oldnd oldlin oldisp oldstate olddef oldpri oldq oldprof olden; do
    [ -n "$oldnd" ] || continue
    if ! current_has_nd "$oldnd"; then
      # Stop any test worker owned by the removed WAN before deleting its state.
      /opt/kzsc/bin/kzsc-blockcheck.sh stop "$oldnd" >/dev/null 2>&1 || true
      cleanup_binding "$oldlin" "$oldq"
      id="$(safe_id "$oldnd")"
      rm -rf "$KZSC_HOME/var/dpi/engines/$id" "$KZSC_HOME/var/blockcheck/$id"
      rm -f "$KZSC_HOME/var/dpi/wan-registry/$id.profile" "$KZSC_HOME/var/dpi/wan-registry/$id.queue"
      rm -f "$KZSC_HOME/var/dpi/auto-presets/auto_$id.conf" "$VALIDATED/$id.tsv" "$PENDING/$id.pending"
      removed_msg="$oldisp bağlantısı kaldırıldı · eski KZSC DPI bağı temizlendi: $oldnd/$oldlin"
      record_change removed "$oldnd" "$oldlin" "$oldisp" removed "$removed_msg"
      log_event true "$removed_msg"
    fi
  done <"$LAST"

  # Detect new/rebound WANs. Public IPv4 renewal and default-priority changes do
  # not trigger DPI retesting; identity/Linux binding changes do.
  while IFS="$(printf '\t')" read -r nd lin isp state def pri q prof en; do
    [ -n "$nd" ] || continue
    prev="$(line_by_nd "$LAST" "$nd")"
    reason=""
    oldlin=""
    oldq=""
    force="$en"

    if [ -z "$prev" ]; then
      reason="new_wan"
      sameisp="$(line_by_isp "$LAST" "$isp")"
      if [ -n "$sameisp" ]; then
        force="$(field "$sameisp" 9)"
        [ -n "$force" ] || force="$AUTO_ENABLE_NEW"
      else
        force="$AUTO_ENABLE_NEW"
      fi
    else
      prevlin="$(field "$prev" 2)"
      previsp="$(field "$prev" 3)"
      prevstate="$(field "$prev" 4)"
      prevq="$(field "$prev" 7)"
      preven="$(field "$prev" 9)"
      [ -n "$preven" ] && force="$preven"
      if [ "$prevlin" != "$lin" ] || [ "$previsp" != "$isp" ]; then
        reason="binding_changed"
        oldlin="$prevlin"
        oldq="$prevq"
      elif ! profile_valid "$prof"; then
        pf="$(pending_file "$nd")"
        if [ ! -f "$pf" ]; then
          reason="profile_missing"
          oldlin="$lin"
          oldq="$q"
        fi
      fi
    fi

    [ -n "$reason" ] || continue

    if [ "$state" != "up" ]; then
      # attempt=0 means "not tried yet"; pending reconciler will launch it as
      # soon as this exact WAN binding becomes up.
      pending_write "$nd" "$isp" "$lin" "$reason" "$force" 0
      continue
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$nd" "$lin" "$isp" "$reason" "$force" "${oldlin}|${oldq}" >>"$CHANGES"
  done <"$CURRENT"

  if [ -s "$CHANGES" ]; then
    # First remove every stale binding before any Blockcheck worker is launched.
    # This cleanup is mandatory even when automatic validation is disabled.
    while IFS="$(printf '\t')" read -r nd lin isp reason force oldbinding; do
      oldlin="${oldbinding%%|*}"; oldq="${oldbinding#*|}"
      [ "$oldbinding" = "$oldq" ] && oldq=""
      if [ -n "$oldlin" ] && [ -n "$oldq" ]; then
        cleanup_binding "$oldlin" "$oldq"
      else
        curq="$(reg_q "$nd")"
        cleanup_binding "$lin" "$curq"
      fi
      invalidate_nd "$nd"
    done <"$CHANGES"

    /opt/kzsc/bin/kzsc-wan-registry.sh refresh >/dev/null 2>&1 || true
    /opt/kzsc/bin/kzsc-engines.sh refresh >/dev/null 2>&1 || true

    if [ "$AUTO_VALIDATE" = 1 ]; then
      while IFS="$(printf '\t')" read -r nd lin isp reason force oldbinding; do
        queue_validation "$nd" "$isp" "$lin" "$reason" "$force" || true
        event="validate:$isp"
      done <"$CHANGES"
    else
      while IFS="$(printf '\t')" read -r nd lin isp reason force oldbinding; do
        log_event true "$isp WAN bağı değişti; eski DPI bağı temizlendi. Otomatik doğrulama kapalı olduğu için motor hazırlanmış durumda bırakıldı."
      done <"$CHANGES"
      event="validation-disabled"
    fi
  fi

  reconcile_pending

  mv "$CURRENT" "$LAST"
  rm -f "$CHANGES"
  write_status "${event:-steady}"
}

status(){
  [ -f "$STATUS" ] || write_status "unknown"
  cat "$STATUS"
}

case "${1:-tick}" in
  baseline) baseline ;;
  tick|refresh) tick ;;
  status) status ;;
  *)
    echo "Usage: kzsc-reconcile {baseline|tick|status}" >&2
    exit 1
    ;;
esac
