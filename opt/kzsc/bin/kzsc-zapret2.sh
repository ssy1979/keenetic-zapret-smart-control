#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

ROOT="$KZSC_HOME/zapret2"
STATE="$KZSC_HOME/var/zapret2"
STATUS="$KZSC_HOME/www/data/zapret2-status.json"
LOG="$KZSC_HOME/var/log/zapret2.log"
API="https://api.github.com/repos/bol-van/zapret2/releases/latest"
TAG_API="https://api.github.com/repos/bol-van/zapret2/releases/tags"

mkdir -p "$STATE" "$KZSC_HOME/www/data" "$KZSC_HOME/var/log"

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

  printf '{"installed":%s,"version":"%s","device_arch":"%s","selected_arch":"%s","root":"%s","failed_tree":%s,"binary":{"nfqws2":{"exists":%s,"exec":%s},"mdig":{"exists":%s,"exec":%s},"ip2net":{"exists":%s,"exec":%s}},"lua_ok":%s}\n' \
    "$inst" "$(json_escape "$ver")" "$(json_escape "$device_arch")" "$(json_escape "$arch")" \
    "$ROOT" "$failed" \
    "$nfq_exists" "$nfq_exec" "$mdig_exists" "$mdig_exec" "$ip2net_exists" "$ip2net_exec" "$lua_ok" >"$STATUS"

  chmod 644 "$STATUS" 2>/dev/null || true
  cat "$STATUS"
}
case "$1" in
  status|refresh) status ;;
  install|update) install_release; rc=$?; status >/dev/null; exit "$rc" ;;
  repair)
    current_tag="$(cat "$STATE/version" 2>/dev/null | head -n1)"
    [ -n "$current_tag" ] || {
      echo "Kurulu Zapret2 sürümü belirlenemedi; onarım için sürüm bilgisi gerekli."
      exit 1
    }
    echo "repair: exact release reinstall $current_tag" >>"$LOG"
    install_release "$current_tag"
    rc=$?
    status >/dev/null
    [ "$rc" -eq 0 ] && echo "KZSC Zapret2 $current_tag onarımı tamamlandı."
    exit "$rc"
    ;;
  remove)
    rm -rf "$ROOT"; rm -f "$STATE/version" "$STATE/arch"
    status >/dev/null
    echo "KZSC Zapret2 kaldırıldı."
    ;;
  *) echo "Usage: kzsc-zapret2 {status|refresh|install|update|repair|remove}"; exit 1 ;;
esac
