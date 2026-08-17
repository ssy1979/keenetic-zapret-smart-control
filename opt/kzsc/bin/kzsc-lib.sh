#!/opt/bin/sh
PATH=/opt/bin:/opt/sbin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
KZSC_HOME="${KZSC_HOME:-/opt/kzsc}"
KZSC_CONF="$KZSC_HOME/etc/kzsc.conf"
KZSC_STATE="$KZSC_HOME/var/status.json"
KZSC_CLIENTS="$KZSC_HOME/var/clients.json"
KZSC_TOPOLOGY="$KZSC_HOME/var/topology.json"
KZSC_LOG="$KZSC_HOME/var/log/kzsc.log"
KZSC_PID="$KZSC_HOME/var/run/daemon.pid"
KZSC_HTTP_PID="$KZSC_HOME/var/run/httpd.pid"
KZSC_POLICY_DIR="$KZSC_HOME/var/lib/policies"
[ -f "$KZSC_CONF" ] && . "$KZSC_CONF"

log(){ mkdir -p "$KZSC_HOME/var/log"; printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$KZSC_LOG"; }
json_escape(){ printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g;s/	/\\t/g'; }
have(){ command -v "$1" >/dev/null 2>&1; }

# lighttpd executes CGI handlers as an unprivileged account on some Keenetic
# models. The queue itself may be writable while an inherited 0700 parent still
# prevents CGI traversal, so prepare and validate the complete path together.
kzsc_prepare_maintenance_queue(){
  queue="$KZSC_HOME/var/run/maintenance-queue"
  mkdir -p "$queue" || return 1
  chmod 711 "$KZSC_HOME/var" "$KZSC_HOME/var/run" || return 1
  chmod 733 "$queue" || return 1
}

ndmc_cmd(){
  if have ndmc; then LD_LIBRARY_PATH= ndmc -c "$*" 2>/dev/null; return $?; fi
  return 1
}

show_interfaces(){ ndmc_cmd 'show interface'; }

router_model(){
  out="$(ndmc_cmd 'show version')"
  v="$(printf '%s\n' "$out" | sed -n 's/.*model[^:]*:[[:space:]]*//Ip' | head -1)"
  [ -n "$v" ] || v="$(printf '%s\n' "$out" | grep -Eio 'KN-[0-9]{4}' | head -1)"
  [ -n "$v" ] || v="unknown"
  printf '%s' "$v"
}

keenetic_version(){
  out="$(ndmc_cmd 'show version')"
  v="$(printf '%s\n' "$out" | sed -n 's/.*release[^:]*:[[:space:]]*//Ip' | head -1)"
  [ -n "$v" ] || v="$(printf '%s\n' "$out" | grep -Eo '[0-9]+\.[0-9]+([.A-Za-z0-9-]+)?' | head -1)"
  [ -n "$v" ] || v="unknown"
  printf '%s' "$v"
}

# Parse an NDMC interface block by interface-name.
iface_block(){
  target="$1"
  show_interfaces | awk -v t="$target" '
    /^Interface, name = / {
      if (inblock) exit
      line=$0
      gsub(/^Interface, name = "/,"",line); gsub(/".*$/,"",line)
      if (line==t) inblock=1
    }
    inblock {print}
  '
}

# Supported Internet uplinks:
# - PPPoE sessions terminated by the Keenetic;
# - wired IPoE/Ethernet uplinks, including DHCP/static private IPv4 received
#   from an upstream router;
# - Keenetic Wireless ISP station uplinks (WISP).
#
# Tunnel and mobile uplinks are intentionally outside KZSC scope.
# Requiring role=inet prevents private LAN bridges/ports from being treated as
# WANs.  Wired type names vary between Keenetic generations.
internet_wans(){
  show_interfaces | awk '
    function supported(t) {
      return t=="PPPoE" || t=="Ethernet" || t=="GigabitEthernet" ||
             t=="FastEthernet" || t=="Vlan" || t=="IP" || t=="Ip" ||
             t=="WifiStation"
    }
    function flush() {
      if (name!="" && role=="inet" && supported(type)) print name
    }
    /^Interface, name = / {
      flush()
      name=$0; gsub(/^Interface, name = "/,"",name); gsub(/".*$/,"",name)
      type=""; role=""
    }
    /^[[:space:]]*type:/ {x=$0; sub(/^[^:]*:[[:space:]]*/,"",x); type=x}
    /^[[:space:]]*role:/ {x=$0; sub(/^[^:]*:[[:space:]]*/,"",x); role=x}
    END {flush()}
  '
}

internet_wan_kind(){
  case "$(iface_type "$1")" in
    PPPoE) printf '%s' pppoe ;;
    Ethernet|GigabitEthernet|FastEthernet|Vlan|IP|Ip) printf '%s' ipoe ;;
    WifiStation) printf '%s' wisp ;;
    *) printf '%s' unsupported ;;
  esac
}

iface_field(){
  i="$1"; key="$2"
  iface_block "$i" | awk -F: -v k="$key" '
    {
      left=$1; gsub(/^[ \t]+|[ \t]+$/,"",left)
      if (left==k) {
        sub(/^[^:]*:[[:space:]]*/,"")
        print; exit
      }
    }'
}

iface_description(){ iface_field "$1" description; }

# Read the user-visible interface description from Keenetic running-config.
# Some KeeneticOS builds do not expose `description` in `show interface`,
# while it is present in `show running-config`.
iface_config_description(){
  ifc="$1"
  [ -n "$ifc" ] || return 0
  ndmc_cmd 'show running-config' | awk -v want="$ifc" '
    /^interface[[:space:]]+/ {
      cur=$2; inif=(cur==want); next
    }
    inif && /^[[:space:]]+description[[:space:]]+/ {
      x=$0
      sub(/^[[:space:]]+description[[:space:]]+/,"",x)
      if (x ~ /^".*"$/) { sub(/^"/,"",x); sub(/"$/,"",x) }
      print x; exit
    }
    inif && /^![[:space:]]*$/ { exit }
  '
}
iface_address(){ iface_field "$1" address; }
iface_state(){ iface_field "$1" state; }
iface_defaultgw(){ iface_field "$1" defaultgw; }
iface_priority(){ iface_field "$1" priority; }
iface_type(){ iface_field "$1" type; }

detect_lan_iface(){
  # Parse exactly one private Bridge interface with an IPv4 address.
  show_interfaces | awk '
    function flush() {
      if (!found && name!="" && type=="Bridge" && sec=="private" && addr!="") {
        print name
        found=1
      }
    }
    /^Interface, name = / {
      flush()
      name=$0
      gsub(/^Interface, name = "/,"",name)
      gsub(/".*$/,"",name)
      type=""; sec=""; addr=""
      next
    }
    /^[[:space:]]*type:/ {
      x=$0; sub(/^[^:]*:[[:space:]]*/,"",x); type=x; next
    }
    /^[[:space:]]*security-level:/ {
      x=$0; sub(/^[^:]*:[[:space:]]*/,"",x); sec=x; next
    }
    /^[[:space:]]*address:/ {
      x=$0; sub(/^[^:]*:[[:space:]]*/,"",x); addr=x; next
    }
    END { flush() }
  ' | head -n 1
}

detect_lan_ip(){
  li="$(detect_lan_iface | head -n 1 | tr -d '
')"
  if [ -n "$li" ]; then
    ipx="$(iface_address "$li" | head -n 1 | tr -d '
')"
    [ -n "$ipx" ] && { printf '%s
' "$ipx"; return; }
  fi
  # fallback for nonstandard/older KeeneticOS
  ip -4 -o addr show 2>/dev/null | awk '{print $2,$4}' | while read i c; do
    a="${c%%/*}"
    case "$i" in lo|ppp*|wwan*|tun*|wg*|nwg*|eth*) continue;; esac
    case "$a" in 10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) echo "$a"; break;; esac
  done
}

isp_label(){
  ifc="$1"

  # Prefer the live Keenetic connection description. Interface-number based
  # maps can become stale when WAN connections are recreated/reordered.
  d="$(iface_description "$ifc")"
  [ -n "$d" ] && { printf '%s' "$d"; return; }
  d="$(iface_config_description "$ifc")"
  [ -n "$d" ] && { printf '%s' "$d"; return; }

  # Manual map is retained only as a fallback for builds that do not expose a
  # user-visible connection description.
  if [ -f "$KZSC_HOME/etc/isp-map.conf" ]; then
    x="$(awk -F= -v i="$ifc" '$1==i {sub(/^[^=]*=/,"");print;exit}' "$KZSC_HOME/etc/isp-map.conf")"
    [ -n "$x" ] && { printf '%s' "$x"; return; }
  fi
  printf '%s' "$ifc"
}

# Resolve the actual Linux WAN device from the live IPv4 address first.  This
# works for pppN as well as Ethernet/VLAN interfaces whose Linux names are not
# derivable from their NDMC names.  The last reconcile binding keeps a wired
# WAN addressable during a short DHCP/link outage. PPPoE0->ppp0 is the final
# compatibility fallback.
linux_if_for_ndmc(){
  n="$1"
  addr="$(iface_address "$n" | head -n1 | tr -d '\r\n')"
  addr="${addr%%/*}"
  if [ -n "$addr" ]; then
    lin="$(ip -4 -o addr show 2>/dev/null | awk -v a="$addr" '
      $2 != "lo" {
        split($4,x,"/")
        if (x[1]==a) {print $2; exit}
      }')"
    [ -n "$lin" ] && { printf '%s' "$lin"; return; }
  fi

  # Reuse only a live interface from the last successful topology snapshot.
  map="$KZSC_HOME/var/reconcile/wan-bindings.tsv"
  if [ -f "$map" ]; then
    lin="$(awk -F '\t' -v n="$n" '$1==n {print $2; exit}' "$map" 2>/dev/null)"
    if [ -n "$lin" ] && ip link show "$lin" >/dev/null 2>&1; then
      printf '%s' "$lin"
      return
    fi
  fi

  idx="$(printf '%s' "$n" | sed -n 's/^PPPoE\([0-9][0-9]*\)$/\1/p')"
  [ -n "$idx" ] && { printf 'ppp%s' "$idx"; return; }
  return 1
}

wan_identity(){
  nd="$1"
  label="$(isp_label "$nd")"
  [ -n "$label" ] || label="$nd"
  printf '%s' "$label"
}

client_name_from_leases(){
  ipx="$1"; macx="$2"
  for f in /tmp/dhcp.leases /var/lib/misc/dnsmasq.leases /opt/var/lib/misc/dnsmasq.leases; do
    [ -f "$f" ] || continue
    n="$(awk -v ip="$ipx" -v mac="$macx" 'tolower($2)==tolower(mac)||$3==ip {print $4;exit}' "$f")"
    [ -n "$n" ] && [ "$n" != "*" ] && { printf '%s' "$n"; return; }
  done
  printf '%s' "$ipx"
}

# Current Linux route fallback when NDMC policy mapping is unavailable.
route_for_client(){
  cip="$1"
  ip route get 1.1.1.1 from "$cip" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1);exit}}'
}

ndmc_for_linux_wan(){
  lin="$1"
  for w in $(internet_wans); do
    [ "$(linux_if_for_ndmc "$w")" = "$lin" ] && { printf '%s' "$w"; return; }
  done
}

zapret_status(){
  root="$KZSC_HOME/zapret2"
  if [ -x "$root/nfq2/nfqws2" ]; then
    for p in $(pidof nfqws2 2>/dev/null); do
      [ -r "/proc/$p/cmdline" ] || continue
      tr '\000' ' ' <"/proc/$p/cmdline" | grep -q "$root/nfq2/nfqws2" && { echo running; return; }
    done
    echo ready
  else
    echo not-installed
  fi
}

ensure_policy_dirs(){ mkdir -p "$KZSC_POLICY_DIR"; }
policy_filename(){ printf '%s' "$1" | tr ' /:' '___' | tr -cd 'A-Za-z0-9_.-'; }

policy_sync_client(){
  mac="$1"; ipx="$2"; ifc="$3"; conf="$4"
  [ "${KZSC_MODE:-auto_safe}" = "observe" ] && return 0
  # v0.10.0.2-generic still requires HIGH confidence before changing policy membership.
  [ "$conf" = "high" ] || return 0
  ensure_policy_dirs
  for f in "$KZSC_POLICY_DIR"/*.clients; do
    [ -f "$f" ] || continue
    grep -viE "^(${mac}|${ipx})[[:space:]]" "$f" > "$f.tmp" 2>/dev/null || true
    mv "$f.tmp" "$f"
  done
  isp="$(isp_label "$ifc")"
  pf="$KZSC_POLICY_DIR/$(policy_filename "$isp").clients"
  touch "$pf"
  printf '%s %s %s %s\n' "$mac" "$ipx" "$ifc" "$(date +%s)" >> "$pf"
}

policy_export_ipsets(){
  ensure_policy_dirs
  out="$KZSC_HOME/var/lib/ipset-plan.sh"
  {
    echo '#!/opt/bin/sh'
    echo '# Auto-generated by KZSC. KZSC-owned sets only.'
    echo 'command -v ipset >/dev/null 2>&1 || exit 0'
    for f in "$KZSC_POLICY_DIR"/*.clients; do
      [ -f "$f" ] || continue
      base="$(basename "$f" .clients)"
      setname="kzsc_$(printf '%s' "$base" | cut -c1-24)"
      echo "ipset create $setname hash:ip family inet -exist"
      echo "ipset flush $setname"
      awk -v s="$setname" 'NF>=2 && $2 ~ /^[0-9]+\./ {print "ipset add " s " " $2 " -exist"}' "$f"
    done
  } > "$out"
  chmod 700 "$out"
}


show_hotspot(){
  # KeeneticOS emits registered host records here, including name/ip/mac/policy.
  ndmc_cmd 'show ip hotspot'
}

global_default_wan(){
  ndmc_cmd 'show ip route' | awk '
    $1=="0.0.0.0/0" {print $3; exit}
  '
}

policy_default_wan(){
  pol="$1"
  [ -n "$pol" ] || { global_default_wan; return; }
  ndmc_cmd "show ip policy $pol" | awk '
    /destination:[[:space:]]*0\.0\.0\.0\/0/ {want=1; next}
    want && /interface:/ {
      x=$0; sub(/^[^:]*:[[:space:]]*/,"",x); print x; exit
    }
  '
}

policy_description(){
  pol="$1"
  [ -n "$pol" ] || return
  ndmc_cmd "show ip policy $pol" | sed -n 's/.*policy, name = [^,]*, description = \(.*\):/\1/p' | head -n1
}

host_records_tsv(){
  # Outputs:
  # ip<TAB>mac<TAB>name<TAB>hostname<TAB>policy<TAB>active<TAB>system_mode
  #
  # Keenetic places policy/active fields after nested interface/dhcp sections,
  # therefore only name/hostname are restricted to the host header scope.
  show_hotspot | awk '
    function emit(){
      if (ip!="" && mac!="") {
        print ip "	" mac "	" name "	" hostname "	" policy "	" active "	" system_mode
      }
    }

    /^[[:space:]]*host:/ {
      if (inhost) emit()
      inhost=1
      host_header=1
      ip=""; mac=""; name=""; hostname=""; policy=""; active=""; system_mode=""
      next
    }

    inhost && /^[[:space:]]*(interface|dhcp|mws|traffic-shape|ssdp):/ {
      host_header=0
      next
    }

    inhost && /^[[:space:]]*mac:/ && mac=="" {
      x=$0; sub(/^[^:]*:[[:space:]]*/,"",x); mac=x; next
    }

    inhost && /^[[:space:]]*ip:/ && ip=="" {
      x=$0; sub(/^[^:]*:[[:space:]]*/,"",x); ip=x; next
    }

    inhost && host_header && /^[[:space:]]*hostname:/ {
      x=$0; sub(/^[^:]*:[[:space:]]*/,"",x); hostname=x; next
    }

    inhost && host_header && /^[[:space:]]*name:/ {
      x=$0; sub(/^[^:]*:[[:space:]]*/,"",x); name=x; next
    }

    # These are host-level attributes even though they occur after interface/dhcp.
    inhost && /^[[:space:]]*policy:/ {
      x=$0; sub(/^[^:]*:[[:space:]]*/,"",x); policy=x; next
    }

    inhost && /^[[:space:]]*active:/ {
      x=$0; sub(/^[^:]*:[[:space:]]*/,"",x); active=x; next
    }

    inhost && /^[[:space:]]*system-mode:/ {
      x=$0; sub(/^[^:]*:[[:space:]]*/,"",x); system_mode=x; next
    }

    END { if (inhost) emit() }
  '
}

resolve_client_policy(){
  cip="$1"; cmac="$2"
  host_records_tsv | awk -F'\t' -v ip="$cip" -v mac="$cmac" '
    $1==ip || tolower($2)==tolower(mac) {print $5; exit}
  '
}

resolve_client_name(){
  cip="$1"; cmac="$2"
  host_records_tsv | awk -F'	' -v ip="$cip" -v mac="$cmac" '
    $1==ip || tolower($2)==tolower(mac) {
      if ($3!="") print $3
      else if ($4!="") print $4
      else print $1
      exit
    }
  '
}

resolve_client_system_mode(){
  cip="$1"; cmac="$2"
  host_records_tsv | awk -F'\t' -v ip="$cip" -v mac="$cmac" '
    $1==ip || tolower($2)==tolower(mac) {print $7; exit}
  '
}

detect_client_wan(){
  cip="$1"; cmac="${2:-}"
  pol="$(resolve_client_policy "$cip" "$cmac")"
  if [ -n "$pol" ]; then
    wan="$(policy_default_wan "$pol")"
    [ -n "$wan" ] && { printf '%s|high|ndmc-policy|%s' "$wan" "$pol"; return; }
  fi
  wan="$(global_default_wan)"
  [ -n "$wan" ] && { printf '%s|high|ndmc-global-default|' "$wan"; return; }
  printf '|unknown|none|'
}


kzsc_lock_acquire(){
  name="$1"
  lockdir="$KZSC_HOME/var/run/lock.$name"
  mkdir -p "$KZSC_HOME/var/run" 2>/dev/null || return 1
  tries=0
  empty_tries=0
  while ! mkdir "$lockdir" 2>/dev/null; do
    tries=$((tries+1))
    owner="$(cat "$lockdir/pid" 2>/dev/null)"
    case "$owner" in
      ''|*[!0-9]*)
        # Total wait time cannot be used here: a long-waiting contender may
        # observe the tiny mkdir->pid window of a brand-new valid owner. Only
        # remove a lock whose owner file stayed empty for three observations.
        empty_tries=$((empty_tries+1))
        if [ "$empty_tries" -ge 3 ] && [ ! -s "$lockdir/pid" ]; then
          rm -rf "$lockdir" 2>/dev/null || true
          empty_tries=0
        fi
        ;;
      *)
        empty_tries=0
        if ! kill -0 "$owner" 2>/dev/null \
          && [ "$(cat "$lockdir/pid" 2>/dev/null)" = "$owner" ]; then
          rm -rf "$lockdir" 2>/dev/null || true
        fi
        ;;
    esac
    [ "$tries" -ge 50 ] && return 1
    sleep 1
  done
  printf '%s\n' "$$" > "$lockdir/pid"
  return 0
}

kzsc_lock_release(){
  name="$1"
  rm -rf "$KZSC_HOME/var/run/lock.$name" 2>/dev/null || true
}
