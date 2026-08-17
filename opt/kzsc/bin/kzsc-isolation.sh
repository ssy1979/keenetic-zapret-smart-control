#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

BCROOT="$KZSC_HOME/var/blockcheck"
LOCK="$KZSC_HOME/var/run/isolation.lock"
mkdir -p "$BCROOT" "$KZSC_HOME/var/run"

safe_id(){ local v="$1"; printf '%s' "$v" | tr ' A-Z/:.' '_a-z___' | tr -cd 'a-z0-9_-'; }
idir(){ local nd="$1"; echo "$BCROOT/$(safe_id "$nd")/isolation"; }

lock_take(){
  local n=0
  while ! mkdir "$LOCK" 2>/dev/null; do
    n=$((n+1)); [ "$n" -ge 50 ] && return 1; sleep 1
  done
  echo $$ >"$LOCK/pid" 2>/dev/null || true
}
lock_drop(){ rm -rf "$LOCK" 2>/dev/null || true; }

# Analyze the mangle table as a graph.  NFQUEUE commonly lives in a custom
# chain while the WAN selector (-i/-o) lives in a built-in hook that jumps to
# that chain.  Treating the custom-chain NFQUEUE rule as "unscoped" is wrong;
# isolation must remove/restore the interface-scoped hook instead.
analyze_rules(){
  local ifc="$1" mode="$2" raw
  raw="$(idir _global)/iptables-s.$$"
  mkdir -p "$(dirname "$raw")"
  iptables -t mangle -S >"$raw" 2>/dev/null || { rm -f "$raw"; return 1; }
  awk -v i="$ifc" -v mode="$mode" '
    function target_of(s,  n,a,k) {
      n=split(s,a," ")
      for(k=1;k<n;k++) if(a[k]=="-j") return a[k+1]
      return ""
    }
    function scoped(s) {
      return index(s," -i " i " ") || index(s," -o " i " ")
    }
    function any_scoped(s) {
      return s ~ / -(i|o) [^ ]+/
    }
    function builtin(c) {
      return c=="PREROUTING" || c=="INPUT" || c=="FORWARD" || c=="OUTPUT" || c=="POSTROUTING"
    }
    $1=="-A" {
      chain=$2; count[chain]++
      line[NR]=$0; ch[NR]=chain; pos[NR]=count[chain]
      args[NR]=$0; sub(/^-A [^ ]+ /,"",args[NR])
      tgt[NR]=target_of($0)
      if(tgt[NR]=="NFQUEUE") reaches[chain]=1
    }
    END {
      changed=1
      while(changed) {
        changed=0
        for(k=1;k<=NR;k++) {
          if(ch[k]!="" && tgt[k]!="" && tgt[k]!="NFQUEUE" && reaches[tgt[k]] && !reaches[ch[k]]) {
            reaches[ch[k]]=1; changed=1
          }
        }
      }
      if(mode=="snapshot") {
        for(k=1;k<=NR;k++) {
          if(ch[k]!="" && scoped(line[k]) && (tgt[k]=="NFQUEUE" || reaches[tgt[k]]))
            printf "%s\t%d\t%s\n",ch[k],pos[k],args[k]
        }
      } else if(mode=="unscoped") {
        for(k=1;k<=NR;k++) {
          if(ch[k]!="" && builtin(ch[k]) && !any_scoped(line[k]) && (tgt[k]=="NFQUEUE" || reaches[tgt[k]])) {
            print line[k]; found=1
          }
        }
        exit(found?7:0)
      }
    }
  ' "$raw"
  rc=$?
  rm -f "$raw"
  return "$rc"
}

snapshot_rules(){
  local ifc="$1" out="$2"
  analyze_rules "$ifc" snapshot >"$out"
}

nfqueue_on_iface(){
  local ifc="$1" tmp rc
  tmp="$(idir _global)/nfq-iface.$$"
  mkdir -p "$(dirname "$tmp")"
  snapshot_rules "$ifc" "$tmp" || { rm -f "$tmp"; return 1; }
  [ -s "$tmp" ]; rc=$?
  rm -f "$tmp"
  return "$rc"
}

unscoped_nfqueue_exists(){
  local ifc="$1"
  analyze_rules "$ifc" unscoped >/dev/null 2>&1
  [ $? -ne 7 ]
}

snapshot_safe(){
  local f="$1"
  [ -f "$f" ] || return 1
  grep -E '["'"'"'`\\]|--comment' "$f" >/dev/null 2>&1 && return 1
  return 0
}

delete_snapshot(){
  local f="$1" rev chain pos args
  rev="$f.rev.$$"
  awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' "$f" >"$rev"
  while IFS="$(printf '\t')" read -r chain pos args; do
    [ -n "$chain" ] || continue
    case "$pos" in ''|*[!0-9]*) rm -f "$rev"; return 1;; esac
    iptables -t mangle -D "$chain" "$pos" 2>/dev/null || { rm -f "$rev"; return 1; }
  done <"$rev"
  rm -f "$rev"
}

restore_snapshot(){
  local f="$1" chain pos args count insert_pos
  [ -f "$f" ] || return 0
  snapshot_safe "$f" || return 1
  while IFS="$(printf '\t')" read -r chain pos args; do
    [ -n "$chain" ] || continue
    case "$pos" in ''|*[!0-9]*) return 1;; esac
    set -- $args
    # Idempotent: an already restored rule is success.
    iptables -t mangle -C "$chain" "$@" 2>/dev/null && continue

    # During a long Blockcheck other mangle rules can legitimately change.
    # iptables -I rejects an index greater than current_length+1, which caused
    # rc=70 even though the original KZSC hook itself was perfectly valid.
    # Preserve the original position when possible; otherwise insert at the
    # closest valid position. As a final safe fallback append the exact hook.
    count="$(iptables -t mangle -S "$chain" 2>/dev/null | awk '$1=="-A"{n++} END{print n+0}')"
    case "$count" in ''|*[!0-9]*) count=0;; esac
    insert_pos="$pos"
    [ "$insert_pos" -le $((count+1)) ] || insert_pos=$((count+1))
    [ "$insert_pos" -ge 1 ] || insert_pos=1
    iptables -t mangle -I "$chain" "$insert_pos" "$@" 2>/dev/null || \
      iptables -t mangle -A "$chain" "$@" 2>/dev/null || return 1
  done <"$f"
}

can_isolate(){
  local nd="$1" ifc="$2" d tmp
  [ -n "$nd" ] && [ -n "$ifc" ] || return 1

  if ! unscoped_nfqueue_exists "$ifc"; then
    echo "Interface ile sınırlandırılmamış NFQUEUE yolu var; güvenli WAN izolasyonu reddedildi." >&2
    return 2
  fi

  d="$(idir "$nd")"; mkdir -p "$d"
  tmp="$d/can-isolate.$$"
  snapshot_rules "$ifc" "$tmp" || { rm -f "$tmp"; echo "mangle kural seti okunamadı." >&2; return 1; }
  snapshot_safe "$tmp" || {
    rm -f "$tmp"
    echo "Seçilen WAN'ın NFQUEUE hook kuralları güvenli otomatik izolasyona uygun değil." >&2
    return 1
  }
  rm -f "$tmp"
  return 0
}

activate(){
  local nd="$1" ifc="$2" owner="$3" d f oldpid
  [ -n "$nd" ] && [ -n "$ifc" ] && [ -n "$owner" ] || return 1
  d="$(idir "$nd")"; mkdir -p "$d"; f="$d/rules.tsv"

  lock_take || { echo "Isolation firewall lock alınamadı." >&2; return 1; }
  trap 'lock_drop' EXIT INT TERM HUP

  if [ -f "$d/active" ]; then
    oldpid="$(cat "$d/owner_pid" 2>/dev/null)"
    if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
      echo "$nd zaten izole edilmiş (pid $oldpid)." >&2
      lock_drop; trap - EXIT INT TERM HUP; return 1
    fi
    restore_snapshot "$f" >/dev/null 2>&1 || true
    rm -f "$d/active" "$d/owner_pid"
  fi

  snapshot_rules "$ifc" "$f" || {
    lock_drop; trap - EXIT INT TERM HUP
    echo "NFQUEUE hook snapshot alınamadı." >&2; return 1
  }
  snapshot_safe "$f" || {
    lock_drop; trap - EXIT INT TERM HUP
    echo "NFQUEUE hook snapshot güvenli biçimde ayrıştırılamıyor; izolasyon reddedildi." >&2; return 1
  }

  echo "$ifc" >"$d/iface"
  echo "$owner" >"$d/owner_pid"
  date +%s >"$d/started"

  if [ -s "$f" ] && ! delete_snapshot "$f"; then
    restore_snapshot "$f" >/dev/null 2>&1 || true
    rm -f "$d/owner_pid"
    lock_drop; trap - EXIT INT TERM HUP
    echo "Seçilen WAN'ın NFQUEUE hook kuralları geçici kaldırılamadı." >&2; return 1
  fi

  if nfqueue_on_iface "$ifc"; then
    restore_snapshot "$f" >/dev/null 2>&1 || true
    rm -f "$d/owner_pid"
    lock_drop; trap - EXIT INT TERM HUP
    echo "WAN üzerinde NFQUEUE'ya giden hook kaldı; Blockcheck izolasyonu güvenli değil." >&2; return 1
  fi

  touch "$d/active"
  lock_drop; trap - EXIT INT TERM HUP
  echo "$nd / $ifc izole edildi. $(wc -l <"$f" 2>/dev/null) NFQUEUE hook kuralı askıya alındı."
}

restore(){
  local nd="$1" d f
  d="$(idir "$nd")"; f="$d/rules.tsv"
  lock_take || { echo "Isolation restore lock alınamadı." >&2; return 1; }
  trap 'lock_drop' EXIT INT TERM HUP

  restore_snapshot "$f" || {
    lock_drop; trap - EXIT INT TERM HUP
    echo "$nd NFQUEUE hook kuralları geri yüklenemedi." >&2; return 1
  }

  rm -f "$d/active" "$d/owner_pid"
  date +%s >"$d/restored"
  lock_drop; trap - EXIT INT TERM HUP
  echo "$nd NFQUEUE hook kuralları geri yüklendi."
}

is_active(){ local nd="$1" d; d="$(idir "$nd")"; [ -f "$d/active" ]; }

iface_isolated(){
  local want="$1" d ifc
  for d in "$BCROOT"/*/isolation; do
    [ -d "$d" ] || continue
    [ -f "$d/active" ] || continue
    ifc="$(cat "$d/iface" 2>/dev/null)"
    [ "$ifc" = "$want" ] && return 0
  done
  return 1
}

recover_all(){
  local d nd owner
  for d in "$BCROOT"/*/isolation; do
    [ -d "$d" ] || continue
    [ -f "$d/active" ] || continue
    owner="$(cat "$d/owner_pid" 2>/dev/null)"
    [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null && continue
    nd="$(basename "$(dirname "$d")")"
    restore "$nd" >/dev/null 2>&1 || log "isolation recovery failed for $nd"
  done
}

case "$1" in
  can-isolate) can_isolate "$2" "$3" ;;
  activate) activate "$2" "$3" "$4" ;;
  restore) restore "$2" ;;
  is-active) is_active "$2" ;;
  iface-isolated) iface_isolated "$2" ;;
  recover-all) recover_all ;;
  nfqueue-on-iface) nfqueue_on_iface "$2" ;;
  *) echo "Usage: kzsc-isolation {can-isolate NDMC IFACE|activate NDMC IFACE OWNERPID|restore NDMC|is-active NDMC|iface-isolated IFACE|recover-all} | nfqueue-on-iface IFACE"; exit 1 ;;
esac
