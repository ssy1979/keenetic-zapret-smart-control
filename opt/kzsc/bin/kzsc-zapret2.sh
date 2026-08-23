#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

ROOT="$KZSC_HOME/zapret2"
STATE="$KZSC_HOME/var/zapret2"
STATUS="$KZSC_HOME/www/data/zapret2-status.json"
LOG="$KZSC_HOME/var/log/zapret2.log"
CONF="$KZSC_HOME/etc/kzsc.conf"
API="https://api.github.com/repos/bol-van/zapret2/releases/latest"
TAG_API="https://api.github.com/repos/bol-van/zapret2/releases/tags"

mkdir -p "$STATE" "$KZSC_HOME/www/data" "$KZSC_HOME/var/log"

state_get(){ cat "$STATE/$1" 2>/dev/null | head -n1 | tr -d '\r\n'; }
state_set(){ printf '%s\n' "$2" >"$STATE/$1.tmp.$$" && mv "$STATE/$1.tmp.$$" "$STATE/$1"; }
cfg_get(){ v="$(sed -n "s/^$1=\"\([^\"]*\)\"$/\1/p" "$CONF" 2>/dev/null | tail -n1)"; [ -n "$v" ] || v="$2"; printf '%s' "$v"; }
auto_enabled(){ [ "$(cfg_get KZSC_ZAPRET2_UPDATE_AUTO 0)" = 1 ]; }
version_gt(){ awk -v a="${1#v}" -v b="${2#v}" 'BEGIN{na=split(a,A,".");nb=split(b,B,".");n=(na>nb?na:nb);for(i=1;i<=n;i++){x=A[i]+0;y=B[i]+0;if(x>y)exit 0;if(x<y)exit 1}exit 1}'; }
set_auto(){
  v="$1"; case "$v" in 0|1) ;; *) return 1;; esac
  mkdir -p "$KZSC_HOME/etc"; [ -f "$CONF" ] || : >"$CONF"
  awk -v v="$v" 'BEGIN{d=0} /^KZSC_ZAPRET2_UPDATE_AUTO=/{if(!d){print "KZSC_ZAPRET2_UPDATE_AUTO=\""v"\"";d=1}next}{print} END{if(!d)print "KZSC_ZAPRET2_UPDATE_AUTO=\""v"\""}' "$CONF" >"$CONF.tmp.$$" && mv "$CONF.tmp.$$" "$CONF"
  chmod 600 "$CONF" 2>/dev/null || true
  state_set auto_enabled "$v"
  [ "$v" = 1 ] && echo 'Zapret2 otomatik güncellemesi açıldı.' || echo 'Zapret2 otomatik güncellemesi kapatıldı.'
}

fetch_text(){
  if command -v curl >/dev/null 2>&1; then curl -fsSL --connect-timeout 15 --max-time 60 "$1"
  else wget -qO- "$1"; fi
}
fetch(){
  if command -v curl >/dev/null 2>&1; then curl -fsSL --connect-timeout 15 --max-time 180 -o "$2" "$1"
  else wget -O "$2" "$1"; fi
}
latest_info(){
  json="$(fetch_text "$API")" || return 1
  tag="$(printf '%s\n' "$json" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
  url="$(printf '%s\n' "$json" | sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*\.tar\.gz\)".*/\1/p' | head -n1)"
  [ -n "$tag" ] && [ -n "$url" ] || return 1
  printf '%s|%s\n' "$tag" "$url"
}
release_info(){
  wanted="$1"
  [ -n "$wanted" ] || return 1
  json="$(fetch_text "$TAG_API/$wanted")" || return 1
  tag="$(printf '%s\n' "$json" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
  url="$(printf '%s\n' "$json" | sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*\.tar\.gz\)".*/\1/p' | head -n1)"
  [ "$tag" = "$wanted" ] && [ -n "$url" ] || return 1
  printf '%s|%s\n' "$tag" "$url"
}
binary_exec_ok(){
  bin="$1"
  [ -x "$bin" ] || return 1

  # CLI help exit codes differ between upstream tools. Reject shell execution
  # failures and signal exits (128+) so a wrong-architecture/segfaulting binary
  # can never be accepted as healthy merely because it was not 126/127.
  "$bin" --help >/dev/null 2>&1
  rc=$?
  [ "$rc" -ne 126 ] && [ "$rc" -ne 127 ] && [ "$rc" -lt 128 ]
}

installed(){
  [ -x "$ROOT/nfq2/nfqws2" ] &&
  [ -x "$ROOT/mdig/mdig" ] &&
  [ -x "$ROOT/ip2net/ip2net" ] &&
  [ -f "$ROOT/blockcheck2.sh" ] &&
  [ -f "$ROOT/lua/zapret-lib.lua" ] &&
  [ -f "$ROOT/lua/zapret-antidpi.lua" ] &&
  [ -f "$ROOT/lua/zapret-auto.lua" ] &&
  binary_exec_ok "$ROOT/nfq2/nfqws2" &&
  binary_exec_ok "$ROOT/mdig/mdig" &&
  binary_exec_ok "$ROOT/ip2net/ip2net"
}

ensure_upstream_lua(){
  tag="$1"
  [ -n "$tag" ] || return 1
  mkdir -p "$ROOT/lua" || return 1

  # Some GitHub release assets have been observed without one or more Lua
  # source files. Recover only from the exact same official release tag so
  # C binaries and Lua strategy libraries stay version-matched.
  for f in zapret-lib.lua zapret-antidpi.lua zapret-auto.lua zapret-obfs.lua zapret-pcap.lua zapret-tests.lua; do
    [ -s "$ROOT/lua/$f" ] && continue
    url="https://raw.githubusercontent.com/bol-van/zapret2/$tag/lua/$f"
    echo "recovering missing lua: $f from $tag" >>"$LOG"
    fetch "$url" "$ROOT/lua/$f.tmp" || {
      rm -f "$ROOT/lua/$f.tmp"
      echo "Eksik Lua dosyası indirilemedi: $f" >&2
      return 1
    }
    [ -s "$ROOT/lua/$f.tmp" ] || {
      rm -f "$ROOT/lua/$f.tmp"
      echo "Eksik Lua dosyası boş geldi: $f" >&2
      return 1
    }
    mv "$ROOT/lua/$f.tmp" "$ROOT/lua/$f" || return 1
    chmod 644 "$ROOT/lua/$f" 2>/dev/null || true
  done
  return 0
}

repair_links(){
  arch="$1"
  [ -n "$arch" ] || return 1

  bin="$ROOT/binaries/$arch"
  [ -x "$bin/nfqws2" ] || return 1
  [ -x "$bin/mdig" ] || return 1
  [ -x "$bin/ip2net" ] || return 1

  mkdir -p "$ROOT/nfq2" "$ROOT/mdig" "$ROOT/ip2net" || return 1
  rm -f "$ROOT/nfq2/nfqws2" "$ROOT/mdig/mdig" "$ROOT/ip2net/ip2net"

  ln -s "../binaries/$arch/nfqws2" "$ROOT/nfq2/nfqws2" || return 1
  ln -s "../binaries/$arch/mdig" "$ROOT/mdig/mdig" || return 1
  ln -s "../binaries/$arch/ip2net" "$ROOT/ip2net/ip2net" || return 1

  chmod +x "$ROOT/blockcheck2.sh" "$ROOT/install_bin.sh" 2>/dev/null || true
  return 0
}

diagnose_tree(){
  {
    echo "=== KZSC Zapret2 diagnose ==="
    echo "ROOT=$ROOT"
    echo "uname=$(uname -a 2>/dev/null)"
    echo "-- root --"; ls -la "$ROOT" 2>/dev/null
    echo "-- nfq2 --"; ls -la "$ROOT/nfq2" 2>/dev/null
    echo "-- mdig --"; ls -la "$ROOT/mdig" 2>/dev/null
    echo "-- lua --"; ls -la "$ROOT/lua" 2>/dev/null
    echo "-- binaries --"; ls -la "$ROOT/binaries" 2>/dev/null
    echo "-- selected binaries --"
    [ -n "$1" ] && ls -la "$ROOT/binaries/$1" 2>/dev/null
  } >>"$LOG"
}

install_release(){
  requested_tag="$1"
  if [ -n "$requested_tag" ]; then
    info="$(release_info "$requested_tag")" || {
      echo "Zapret2 $requested_tag release bilgisi alınamadı."
      return 1
    }
  else
    info="$(latest_info)" || {
      echo "Zapret2 release bilgisi alınamadı."
      return 1
    }
  fi
  tag="${info%%|*}"; url="${info#*|}"

  tmp="/opt/tmp/kzsc-z2.$$"
  rm -rf "$tmp"
  mkdir -p "$tmp/stage" || return 1

  fetch "$url" "$tmp/z2.tar.gz" || {
    rm -rf "$tmp"
    echo "İndirme başarısız."
    return 1
  }

  tar -xzf "$tmp/z2.tar.gz" -C "$tmp/stage" || {
    rm -rf "$tmp"
    echo "Zapret2 arşivi açılamadı."
    return 1
  }

  ib="$(find "$tmp/stage" -type f -name install_bin.sh | head -n1)"
  [ -n "$ib" ] || {
    rm -rf "$tmp"
    echo "Release içinde install_bin.sh bulunamadı."
    return 1
  }
  sr="$(dirname "$ib")"

  backup="$ROOT.previous"
  failed="$ROOT.failed"
  rm -rf "$backup" "$failed"
  [ -d "$ROOT" ] && mv "$ROOT" "$backup"

  mkdir -p "$ROOT" && cp -R "$sr"/. "$ROOT"/ || {
    rm -rf "$ROOT"
    [ -d "$backup" ] && mv "$backup" "$ROOT"
    rm -rf "$tmp"
    echo "Zapret2 dosyaları kopyalanamadı."
    return 1
  }

  chmod +x "$ROOT/install_bin.sh" "$ROOT/blockcheck2.sh" 2>/dev/null || true

  # Ask upstream for the exact architecture it considers compatible.
  arch="$(cd "$ROOT" && sh ./install_bin.sh getarch 2>>"$LOG" | tail -n1)"
  case "$arch" in
    my|linux-*|freebsd-*|windows-*) ;;
    *)
      diagnose_tree "$arch"
      mv "$ROOT" "$failed" 2>/dev/null || true
      [ -d "$backup" ] && mv "$backup" "$ROOT"
      rm -rf "$tmp"
      echo "Zapret2 uyumlu mimari belirlenemedi. Tanı ağacı: $failed"
      return 1
      ;;
  esac

  echo "selected arch: $arch" >>"$LOG"

  # Let upstream create its canonical links first.
  (cd "$ROOT" && sh ./install_bin.sh) >>"$LOG" 2>&1 || {
    diagnose_tree "$arch"
    mv "$ROOT" "$failed" 2>/dev/null || true
    [ -d "$backup" ] && mv "$backup" "$ROOT"
    rm -rf "$tmp"
    echo "Zapret2 install_bin.sh başarısız. Tanı ağacı: $failed"
    return 1
  }

  # Ensure the exact release-tag Lua library set exists. This also heals
  # release assets that omit Lua source files.
  ensure_upstream_lua "$tag" || {
    diagnose_tree "$arch"
    mv "$ROOT" "$failed" 2>/dev/null || true
    [ -d "$backup" ] && mv "$backup" "$ROOT"
    rm -rf "$tmp"
    echo "Zapret2 Lua kitaplıkları tamamlanamadı. Tanı ağacı: $failed"
    return 1
  }

  # Embedded/BusyBox filesystems can behave differently with the upstream
  # directory-target ln syntax. Recreate the three links deterministically.
  repair_links "$arch" || {
    diagnose_tree "$arch"
    mv "$ROOT" "$failed" 2>/dev/null || true
    [ -d "$backup" ] && mv "$backup" "$ROOT"
    rm -rf "$tmp"
    echo "Zapret2 binary linkleri doğrulanamadı. Tanı ağacı: $failed"
    return 1
  }

  if ! installed; then
    diagnose_tree "$arch"
    mv "$ROOT" "$failed" 2>/dev/null || true
    [ -d "$backup" ] && mv "$backup" "$ROOT"
    rm -rf "$tmp"
    echo "Zapret2 kurulum doğrulaması başarısız. Tanı ağacı: $failed"
    return 1
  fi

  # Runtime execution validation is mandatory. A selected architecture
  # is accepted only when all core binaries can actually execute.
  binary_exec_ok "$ROOT/nfq2/nfqws2" || {
    diagnose_tree "$arch"
    mv "$ROOT" "$failed" 2>/dev/null || true
    [ -d "$backup" ] && mv "$backup" "$ROOT"
    rm -rf "$tmp"
    echo "nfqws2 cihaz üzerinde çalıştırılamadı. Tanı ağacı: $failed"
    return 1
  }
  binary_exec_ok "$ROOT/mdig/mdig" || {
    diagnose_tree "$arch"
    mv "$ROOT" "$failed" 2>/dev/null || true
    [ -d "$backup" ] && mv "$backup" "$ROOT"
    rm -rf "$tmp"
    echo "mdig cihaz üzerinde çalıştırılamadı. Tanı ağacı: $failed"
    return 1
  }
  binary_exec_ok "$ROOT/ip2net/ip2net" || {
    diagnose_tree "$arch"
    mv "$ROOT" "$failed" 2>/dev/null || true
    [ -d "$backup" ] && mv "$backup" "$ROOT"
    rm -rf "$tmp"
    echo "ip2net cihaz üzerinde çalıştırılamadı. Tanı ağacı: $failed"
    return 1
  }

  echo "runtime validation: nfqws2=OK mdig=OK ip2net=OK" >>"$LOG"
  echo "$tag" >"$STATE/version"
  echo "$arch" >"$STATE/arch"
  rm -rf "$backup" "$failed" "$tmp"
  echo "KZSC Zapret2 $tag kuruldu (mimari: $arch)."
}

status(){
  device_arch="$(uname -m 2>/dev/null)"
  [ -n "$device_arch" ] || device_arch="unknown"

  inst=false
  installed && inst=true

  ver="$(cat "$STATE/version" 2>/dev/null | head -n1)"
  arch="$(cat "$STATE/arch" 2>/dev/null | head -n1)"
  failed=false; [ -d "$ROOT.failed" ] && failed=true

  nfq_exists=false; [ -x "$ROOT/nfq2/nfqws2" ] && nfq_exists=true
  mdig_exists=false; [ -x "$ROOT/mdig/mdig" ] && mdig_exists=true
  ip2net_exists=false; [ -x "$ROOT/ip2net/ip2net" ] && ip2net_exists=true

  nfq_exec=false; binary_exec_ok "$ROOT/nfq2/nfqws2" && nfq_exec=true
  mdig_exec=false; binary_exec_ok "$ROOT/mdig/mdig" && mdig_exec=true
  ip2net_exec=false; binary_exec_ok "$ROOT/ip2net/ip2net" && ip2net_exec=true

  lua_ok=false
  [ -f "$ROOT/lua/zapret-lib.lua" ] &&
  [ -f "$ROOT/lua/zapret-antidpi.lua" ] &&
  [ -f "$ROOT/lua/zapret-auto.lua" ] && lua_ok=true

  auto=false; auto_enabled && auto=true
  last_check="$(state_get auto_last_check)"; case "$last_check" in ''|*[!0-9]*) last_check=0;; esac
  latest="$(state_get auto_latest)"; available=false
  [ -n "$latest" ] && [ -n "$ver" ] && version_gt "$latest" "$ver" && available=true
  printf '{"installed":%s,"version":"%s","device_arch":"%s","selected_arch":"%s","root":"%s","failed_tree":%s,"binary":{"nfqws2":{"exists":%s,"exec":%s},"mdig":{"exists":%s,"exec":%s},"ip2net":{"exists":%s,"exec":%s}},"lua_ok":%s,"auto_update":{"enabled":%s,"interval_seconds":1800,"last_check":%s,"latest":"%s","available":%s,"last_error":"%s"}\n' \
    "$inst" "$(json_escape "$ver")" "$(json_escape "$device_arch")" "$(json_escape "$arch")" \
    "$ROOT" "$failed" \
    "$nfq_exists" "$nfq_exec" "$mdig_exists" "$mdig_exec" "$ip2net_exists" "$ip2net_exec" "$lua_ok" \
    "$auto" "$last_check" "$(json_escape "$latest")" "$available" "$(json_escape "$(state_get auto_error)")" >"$STATUS"

  chmod 644 "$STATUS" 2>/dev/null || true
  cat "$STATUS"
}
check(){
  current="$(cat "$STATE/version" 2>/dev/null | head -n1)"
  info="$(latest_info 2>/dev/null)" || {
    printf '{"ok":false,"error":"Zapret2 release bilgisi alınamadı."}\n'
    return 1
  }
  latest="${info%%|*}"
  url="${info#*|}"
  available=false
  [ -n "$current" ] && [ "$current" != "$latest" ] && available=true
  printf '{"ok":true,"current":"%s","latest":"%s","available":%s,"release_url":"%s"}\n' \
    "$(json_escape "$current")" "$(json_escape "$latest")" "$available" "$(json_escape "$url")"
}

auto_check(){
  auto_enabled || { status >/dev/null; return 0; }
  now="$(date +%s)"; last="$(state_get auto_last_check)"; case "$last" in ''|*[!0-9]*) last=0;; esac
  [ $((now-last)) -ge 1800 ] || { status >/dev/null; return 0; }
  [ -f "$STATE/auto.lock" ] && return 0
  : >"$STATE/auto.lock" || return 0
  trap 'rm -f "$STATE/auto.lock"' EXIT INT TERM
  state_set auto_last_check "$now"; state_set auto_error ""
  info="$(latest_info 2>/dev/null)" || { state_set auto_error 'Zapret2 release bilgisi alınamadı.'; rm -f "$STATE/auto.lock"; trap - EXIT INT TERM; status >/dev/null; return 0; }
  latest="${info%%|*}"; state_set auto_latest "$latest"
  current="$(cat "$STATE/version" 2>/dev/null | head -n1)"
  if [ -n "$current" ] && version_gt "$latest" "$current"; then
    ( native_runtime_pause; install_release; rc=$?; native_runtime_resume || [ "$rc" -ne 0 ] || rc=1; status >/dev/null; rm -f "$STATE/auto.lock" ) >>"$LOG" 2>&1 &
    trap - EXIT INT TERM; status >/dev/null; return 0
  fi
  rm -f "$STATE/auto.lock"; trap - EXIT INT TERM; status >/dev/null
}

native_runtime_pause(){
  # Preserve enabled markers while removing live hooks/processes. This makes
  # a Zapret2 replacement safe for every WAN, not just the current default.
  [ -x /opt/kzsc/bin/kzsc-native-dpi.sh ] || return 0
  /opt/kzsc/bin/kzsc-native-dpi.sh suspend-all >/dev/null 2>&1 || true
}

native_runtime_resume(){
  [ -x /opt/kzsc/bin/kzsc-native-dpi.sh ] || return 0
  [ -x "$ROOT/nfq2/nfqws2" ] || return 0
  /opt/kzsc/bin/kzsc-native-dpi.sh ensure-all >/dev/null 2>&1 || {
    echo 'Zapret2 kuruldu ancak etkin WAN DPI motorlarından biri yeniden başlatılamadı.' >&2
    return 1
  }
}

case "$1" in
  status|refresh) status ;;
  check) check ;;
  auto) set_auto "$2"; status >/dev/null ;;
  auto-check) auto_check ;;
  install|update)
    native_runtime_pause
    install_release
    rc=$?
    native_runtime_resume || [ "$rc" -ne 0 ] || rc=1
    status >/dev/null
    exit "$rc"
    ;;
  repair)
    current_tag="$(cat "$STATE/version" 2>/dev/null | head -n1)"
    [ -n "$current_tag" ] || {
      echo "Kurulu Zapret2 sürümü belirlenemedi; onarım için sürüm bilgisi gerekli."
      exit 1
    }
    echo "repair: exact release reinstall $current_tag" >>"$LOG"
    native_runtime_pause
    install_release "$current_tag"
    rc=$?
    native_runtime_resume || [ "$rc" -ne 0 ] || rc=1
    status >/dev/null
    [ "$rc" -eq 0 ] && echo "KZSC Zapret2 $current_tag onarımı tamamlandı."
    exit "$rc"
    ;;
  remove)
    rm -rf "$ROOT"; rm -f "$STATE/version" "$STATE/arch"
    status >/dev/null
    echo "KZSC Zapret2 kaldırıldı."
    ;;
  *) echo "Usage: kzsc-zapret2 {status|refresh|check|auto 0|1|auto-check|install|update|repair|remove}"; exit 1 ;;
esac
