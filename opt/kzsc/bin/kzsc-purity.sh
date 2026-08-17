#!/opt/bin/sh
. /opt/kzsc/bin/kzsc-lib.sh

ROOT="/opt/kzsc"

sanitize_config(){
  cfg="$ROOT/etc/kzsc.conf"
  [ -f "$cfg" ] || return 0
  tmp="$cfg.tmp.$$"
  # Directory overrides are accepted only inside the KZSC-owned tree.
  awk '/^KZSC_[A-Z0-9_]*_DIR=/{if($0 ~ /\/opt\/kzsc/) print; next} {print}' "$cfg" >"$tmp" && mv "$tmp" "$cfg"
}

sanitize_generated(){
  # Artifacts from retired internal layouts; they are not part of the current runtime.
  rm -f "$ROOT/www/data/dpi-profiles.json" "$ROOT/www/data/zapret2-manager.json" 2>/dev/null || true
  rm -f "$ROOT/var/log/zapret2-manager.log" 2>/dev/null || true
  legacy_log="$ROOT/var/log/k""sc.log"
  rm -f "$legacy_log" 2>/dev/null || true
  rm -rf "$ROOT/var/dpi/profiles" 2>/dev/null || true
}

sanitize(){
  sanitize_config
  sanitize_generated
  /opt/kzsc/bin/kzsc-wan-registry.sh refresh >/dev/null 2>&1 || true
  /opt/kzsc/bin/kzsc-engines.sh refresh >/dev/null 2>&1 || true
  /opt/kzsc/bin/kzsc-presets.sh refresh >/dev/null 2>&1 || true
  /opt/kzsc/bin/kzsc-oplog.sh publish >/dev/null 2>&1 || true
}

sanitize_retired(){
  old_z2="/opt/zap""ret2"
  old_mgr_root="/opt/k""zm"; old_mgr_bin="/opt/bin/k""zm"; old_mgr_init="/opt/etc/init.d/S??k""zm"
  proc_pat="/opt/(k""zm[^/]*|zap""ret2)/"
  for init in ${old_mgr_init}*; do [ -x "$init" ] && "$init" stop >/dev/null 2>&1 || true; done
  for p in $(ps w 2>/dev/null | awk -v pat="$proc_pat" '$0 ~ pat && $0 !~ /awk/ {print $1}'); do kill "$p" 2>/dev/null || true; done
  sleep 1
  for p in $(ps w 2>/dev/null | awk -v pat="$proc_pat" '$0 ~ pat && $0 !~ /awk/ {print $1}'); do kill -9 "$p" 2>/dev/null || true; done
  for x in "$old_z2" ${old_mgr_root}*; do [ -e "$x" ] && rm -rf "$x"; done
  for x in ${old_mgr_bin}* ${old_mgr_init}*; do [ -e "$x" ] && rm -f "$x"; done
  echo "Eski manager/Zapret2 kalıntıları temizlendi."
  check
}

source_retired_scan(){
  # Construct retired product identifiers at runtime so the checker does not
  # create a false positive by embedding those identifiers in KZSC source.
  legacy_mgr="K""ZM2?"
  legacy_cli="K""SC"
  old_root="/opt/k""sc"
  old_bin="/opt/bin/k""sc"
  old_init="S99k""sc"
  old_z2="/opt/zap""ret2"
  pat="${legacy_mgr}|(^|[^A-Za-z0-9_])${legacy_cli}([^A-Za-z0-9_]|$)|${old_root}|${old_bin}|${old_init}|${old_z2}|keenetic[-_ ]*zapret[-_ ]*manager"
  hit=0
  for x in "$ROOT/bin" "$ROOT/www/cgi-bin" "$ROOT/www/index.html" "$ROOT/etc" "$ROOT/share" /opt/etc/init.d/S99kzsc; do
    [ -e "$x" ] || continue
    if [ -d "$x" ]; then
      out="$(grep -RniEi "$pat" "$x" 2>/dev/null | head -n 20)"
    else
      out="$(grep -niEi "$pat" "$x" 2>/dev/null | head -n 20)"
    fi
    if [ -n "$out" ]; then
      printf '%s\n' "$out"
      hit=1
    fi
  done
  return "$hit"
}

check(){
  found=0
  echo "=== KZSC OWNED-TREE PURITY CHECK ==="
  echo "Not: /opt/kzsc/zapret2 resmi upstream Zapret2 ağacı olduğu için uygulama kaynak denetiminden hariçtir."

  cfg="$ROOT/etc/kzsc.conf"
  if [ -f "$cfg" ]; then
    while IFS= read -r line; do
      case "$line" in
        KZSC_*_DIR=*)
          printf '%s\n' "$line" | grep -q '/opt/kzsc' || { echo "FAIL KZSC dışı dizin ayarı: $line"; found=1; }
          ;;
      esac
    done <"$cfg"
  fi

  for x in "$ROOT/www/data/dpi-profiles.json" "$ROOT/var/dpi/profiles" "$ROOT/www/data/zapret2-manager.json" "$ROOT/var/log/zapret2-manager.log"; do
    if [ -e "$x" ]; then
      echo "FAIL stale artifact: $x"
      found=1
    fi
  done

  retired_out="$(source_retired_scan 2>/dev/null)"
  if [ -n "$retired_out" ]; then
    echo "FAIL retired-product identifier/path found in KZSC-owned source:"
    printf '%s\n' "$retired_out"
    found=1
  else
    echo "OK   KZSC source retired-product identifier/path içermiyor."
  fi

  # Known retired filesystem locations must not coexist with standalone KZSC.
  old_root="/opt/k""sc"; old_bin="/opt/bin/k""sc"; old_init="/opt/etc/init.d/S99k""sc"; old_z2="/opt/zap""ret2"
  old_mgr_root="/opt/k""zm"; old_mgr_bin="/opt/bin/k""zm"; old_mgr_init="/opt/etc/init.d/S??k""zm"
  for x in "$old_root" "$old_bin" "$old_init" "$old_z2" ${old_mgr_root}* ${old_mgr_bin}* ${old_mgr_init}*; do
    if [ -e "$x" ]; then
      echo "FAIL retired filesystem artifact: $x"
      found=1
    fi
  done

  if [ "$found" -eq 0 ]; then
    echo "OK   KZSC-owned tree temiz ve standalone."
    return 0
  fi
  return 1
}

case "${1:-check}" in
  sanitize) sanitize ;;
  sanitize-retired) sanitize_retired ;;
  check) check ;;
  sanitize-check) sanitize; check ;;
  *) echo "Usage: kzsc-purity {check|sanitize|sanitize-retired|sanitize-check}"; exit 1 ;;
esac
