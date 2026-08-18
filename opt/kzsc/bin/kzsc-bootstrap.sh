#!/opt/bin/sh

# Complete the router-side prerequisites that can be installed safely once an
# Entware /opt is available.  The package and component names are fixed here;
# no caller-controlled command or repository is accepted.

PATH="${KZSC_OPT_ROOT:-/opt}/bin:${KZSC_OPT_ROOT:-/opt}/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH

OPT_ROOT="${KZSC_OPT_ROOT:-/opt}"
REQUIRED_COMPONENTS="opkg dns-tls dns-https opkg-kmod-netfilter opkg-kmod-netfilter-addons"
REQUIRED_PACKAGES="ca-certificates wget-ssl curl dropbear coreutils-sha256sum lighttpd lighttpd-mod-cgi iptables ip-full findutils gawk sed grep tar gzip procps-ng-ps"

say(){ printf '%s\n' "$*"; }
die(){ printf 'HATA: %s\n' "$*" >&2; exit 1; }

allowed_component(){
  want="$1"
  for item in $REQUIRED_COMPONENTS; do [ "$item" != "$want" ] || return 0; done
  return 1
}

ndmc_bin(){
  if [ -n "${KZSC_NDMC:-}" ] && [ -x "$KZSC_NDMC" ]; then
    printf '%s\n' "$KZSC_NDMC"
    return 0
  fi
  for candidate in /bin/ndmc /opt/bin/ndmc /usr/bin/ndmc /sbin/ndmc /usr/sbin/ndmc; do
    [ -x "$candidate" ] || continue
    printf '%s\n' "$candidate"
    return 0
  done
  return 1
}

show_version(){
  if [ -n "${KZSC_BOOTSTRAP_VERSION_FILE:-}" ]; then
    cat "$KZSC_BOOTSTRAP_VERSION_FILE"
    return
  fi
  ndmc="$(ndmc_bin)" || die 'ndmc bulunamadı; KeeneticOS bileşenleri denetlenemiyor.'
  LD_LIBRARY_PATH= "$ndmc" -c 'show version' 2>/dev/null
}

component_present(){
  token="$1"
  # Keep this intentionally identical to the pre-flight component parser.
  # Keenetic's `show version` output does not require quoted component names;
  # accepting quote delimiters here made this check differ from pre-flight on
  # BusyBox grep and could incorrectly schedule an unnecessary reboot.
  printf '%s\n' "$VERSION_OUT" | grep -Eq "(^|[,:[:space:]])${token}([,[:space:]]|$)"
}

missing_components(){
  VERSION_OUT="$(show_version)" || die 'KeeneticOS sürüm/bileşen bilgisi alınamadı.'
  missing=""
  for component in $REQUIRED_COMPONENTS; do
    component_present "$component" || missing="$missing $component"
  done
  printf '%s\n' "${missing# }"
}

cli_has_error(){
  printf '%s\n' "$1" | grep -Eqi 'error\[|not found:|unknown command|invalid argument|request failed|permission denied|erişim reddedildi|hata\['
}

install_components(){
  [ "$#" -gt 0 ] || return 0
  ndmc="$(ndmc_bin)" || die 'ndmc bulunamadı; KeeneticOS bileşenleri kurulamıyor.'
  for component in "$@"; do
    allowed_component "$component" || die "İzin verilmeyen KeeneticOS bileşeni: $component"
    say "KeeneticOS bileşeni sıraya alınıyor: $component"
    out="$(LD_LIBRARY_PATH= "$ndmc" -c "components install $component" 2>&1)" || {
      printf '%s\n' "$out" >&2
      die "KeeneticOS bileşeni sıraya alınamadı: $component"
    }
    cli_has_error "$out" && { printf '%s\n' "$out" >&2; die "KeeneticOS bileşeni reddedildi: $component"; }
  done
  preview="$(LD_LIBRARY_PATH= "$ndmc" -c 'components preview' 2>&1)" || {
    printf '%s\n' "$preview" >&2
    die 'KeeneticOS bileşen önizlemesi başarısız.'
  }
  cli_has_error "$preview" && { printf '%s\n' "$preview" >&2; die 'KeeneticOS bileşen önizlemesi reddedildi.'; }
  say 'KeeneticOS bileşenleri uygulanıyor; router yeniden başlatılabilir.'
  commit="$(LD_LIBRARY_PATH= "$ndmc" -c 'components commit' 2>&1)" || {
    printf '%s\n' "$commit" >&2
    die 'KeeneticOS bileşen kurulumu başlatılamadı.'
  }
  cli_has_error "$commit" && { printf '%s\n' "$commit" >&2; die 'KeeneticOS bileşen kurulumu reddedildi.'; }
  # components commit stages the KeeneticOS payload but does not reboot every
  # model automatically.  Schedule a short, explicit reboot so the durable
  # resume hook can complete the installation consistently across models.
  LD_LIBRARY_PATH= "$ndmc" -c 'system reboot 30' >/dev/null 2>&1 || true
  return 0
}

opkg_bin(){
  if [ -n "${KZSC_OPKG:-}" ] && [ -x "$KZSC_OPKG" ]; then
    printf '%s\n' "$KZSC_OPKG"
    return 0
  fi
  for candidate in "$OPT_ROOT/bin/opkg" "$OPT_ROOT/sbin/opkg"; do
    [ -x "$candidate" ] || continue
    printf '%s\n' "$candidate"
    return 0
  done
  command -v opkg 2>/dev/null
}

installed_packages(){
  "$OPKG_BIN" list-installed 2>/dev/null | awk '{print $1}'
}

package_present(){
  printf '%s\n' "$INSTALLED_PACKAGES" | grep -Fxq "$1"
}

ensure_packages(){
  OPKG_BIN="$(opkg_bin)" || die 'Entware opkg bulunamadı. Önce Keenetic Open Package depolamasını etkinleştirin.'
  INSTALLED_PACKAGES="$(installed_packages)" || die 'Kurulu Entware paketleri okunamadı.'
  missing=""
  for package in $REQUIRED_PACKAGES; do
    package_present "$package" || missing="$missing $package"
  done
  if [ -z "$missing" ]; then
    say 'OK   Gerekli Entware paketleri hazır.'
    return 0
  fi

  missing="${missing# }"
  say "Eksik Entware paketleri kuruluyor: $missing"
  [ "${KZSC_BOOTSTRAP_SKIP_UPDATE:-0}" = 1 ] || "$OPKG_BIN" update || die 'Entware paket listesi güncellenemedi.'
  # Word splitting is intentional: every value comes from REQUIRED_PACKAGES.
  "$OPKG_BIN" install $missing || die 'Gerekli Entware paketleri kurulamadı.'

  INSTALLED_PACKAGES="$(installed_packages)" || die 'Entware paket kurulumu doğrulanamadı.'
  unresolved=""
  for package in $missing; do
    package_present "$package" || unresolved="$unresolved $package"
  done
  [ -z "$unresolved" ] || die "Kurulumdan sonra hâlâ eksik Entware paketleri:${unresolved}"
  say 'OK   Gerekli Entware paketleri kuruldu ve doğrulandı.'
}

case "${1:-}" in
  missing-components)
    missing_components
    ;;
  install-components)
    shift
    install_components "$@"
    ;;
  ensure-packages)
    ensure_packages
    ;;
  requirements)
    printf 'components:%s\npackages:%s\n' "$REQUIRED_COMPONENTS" "$REQUIRED_PACKAGES"
    ;;
  *)
    echo 'Kullanım: kzsc-bootstrap.sh {missing-components|install-components COMPONENT...|ensure-packages|requirements}' >&2
    exit 2
    ;;
esac
