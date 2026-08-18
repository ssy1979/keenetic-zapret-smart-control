#!/opt/bin/sh
. "${KZSC_LIB:-/opt/kzsc/bin/kzsc-lib.sh}"

REPO="ssy1979/keenetic-zapret-smart-control"
API="https://api.github.com/repos/$REPO/releases/latest"
STATE="$KZSC_HOME/var/update"
STATUS="$KZSC_HOME/www/data/update-status.json"
LOG="$KZSC_HOME/var/log/update.log"
CONF="$KZSC_HOME/etc/kzsc.conf"
SELF="${KZSC_UPDATER_SELF:-$0}"
FIXTURE_DIR="${KZSC_UPDATE_FIXTURE_DIR:-}"
UPDATE_SHELL="${KZSC_UPDATE_SHELL:-/opt/bin/sh}"
MAX_ARCHIVE_BYTES=10485760
KZSC_APPLY_TMP=""
mkdir -p "$STATE" "$KZSC_HOME/www/data" "$KZSC_HOME/var/log"

state_get(){ local state_key="$1"; cat "$STATE/$state_key" 2>/dev/null | head -n1 | tr -d '\r\n'; }
state_set(){ local state_key="$1" state_value="$2"; printf '%s\n' "$state_value" >"$STATE/$state_key.tmp.$$" && mv "$STATE/$state_key.tmp.$$" "$STATE/$state_key"; }
cfg_get(){
  local key def value
  key="$1"; def="$2"
  value="$(sed -n "s/^${key}=\"\([^\"]*\)\"$/\1/p" "$CONF" 2>/dev/null | tail -n1)"
  [ -n "$value" ] || value="$def"
  printf '%s' "$value"
}
current_version(){
  local v
  v="$(sed -n 's/^VERSION="\([^"]*\)"$/\1/p' "$KZSC_HOME/bin/kzsc-maintenance.sh" 2>/dev/null | head -n1)"
  [ -n "$v" ] || v="${KZSC_CURRENT_VERSION:-0.11.2.22-generic}"
  printf '%s' "$v"
}
numeric_version(){ printf '%s' "${1%-generic}" | sed 's/^v//'; }
valid_release_tag(){ printf '%s\n' "$1" | grep -Eq '^v[0-9]+(\.[0-9]+){2,3}-generic$'; }
version_gt(){
  local version_a="$1" version_b="$2"
  awk -v a="$(numeric_version "$version_a")" -v b="$(numeric_version "$version_b")" 'BEGIN{
    na=split(a,A,"."); nb=split(b,B,"."); n=(na>nb?na:nb)
    for(i=1;i<=n;i++){x=A[i]+0;y=B[i]+0;if(x>y)exit 0;if(x<y)exit 1}
    exit 1
  }'
}
auto_enabled(){ [ "$(cfg_get KZSC_UPDATE_AUTO 0)" = 1 ]; }
interval_seconds(){
  local v
  v="$(cfg_get KZSC_UPDATE_CHECK_INTERVAL 1800)"
  case "$v" in ''|*[!0-9]*) v=1800;; esac
  [ "$v" -ge 1800 ] 2>/dev/null || v=1800
  [ "$v" -le 86400 ] 2>/dev/null || v=86400
  printf '%s' "$v"
}
apply_active(){
  case "$(state_get apply_state)" in queued|downloading|verifying|installing) return 0;; *) return 1;; esac
}
apply_worker_live(){
  local p saved_boot current_boot
  p="$(state_get apply_pid)"
  case "$p" in ''|*[!0-9]*) return 1;; esac
  kzsc_pid_matches "$p" "$SELF" || return 1
  saved_boot="$(state_get apply_boot_id)"
  current_boot="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null | head -n1 | tr -d '\r\n')"
  [ -z "$saved_boot" ] || [ -z "$current_boot" ] || [ "$saved_boot" = "$current_boot" ]
}
recover_stale_apply(){
  local queued_at now
  apply_active || return 0
  queued_at="$(state_get apply_queued_at)"; now="$(date +%s)"
  case "$queued_at:$now" in *[!0-9:]*) :;; *) [ "$now" -ge "$queued_at" ] 2>/dev/null && [ $((now-queued_at)) -lt 60 ] 2>/dev/null && return 0;; esac
  apply_worker_live && return 0
  rm -f "$STATE/apply_pid" "$STATE/apply_boot_id" "$STATE/apply_queued_at"
  state_set apply_state failed
  state_set last_error 'KZSC güncellemesi yeniden başlatma veya güç kesintisi nedeniyle yarım kaldı.'
}
publish_status(){
  local current latest last error release_url apply_state available auto applying status_tmp
  current="$(current_version)"; latest="$(state_get latest)"; last="$(state_get last_check)"
  error="$(state_get last_error)"; release_url="$(state_get release_url)"; apply_state="$(state_get apply_state)"
  [ -n "$last" ] || last=0
  [ -n "$apply_state" ] || apply_state=idle
  available=false
  [ -n "$latest" ] && version_gt "$latest" "$current" && available=true
  auto=false; auto_enabled && auto=true
  applying=false; apply_active && applying=true
  status_tmp="$STATUS.tmp.$$"
  printf '{"repo":"%s","current":"%s","latest":"%s","available":%s,"auto":%s,"interval_seconds":%s,"last_check":%s,"applying":%s,"apply_state":"%s","release_url":"%s","last_error":"%s"}\n' \
    "$(json_escape "$REPO")" "$(json_escape "$current")" "$(json_escape "$latest")" "$available" "$auto" \
    "$(interval_seconds)" "$last" "$applying" "$(json_escape "$apply_state")" \
    "$(json_escape "$release_url")" "$(json_escape "$error")" >"$status_tmp" && mv "$status_tmp" "$STATUS"
  chmod 644 "$STATUS" 2>/dev/null || true
  cat "$STATUS"
}
fail_check(){
  local message="$1"
  state_set last_error "$message"
  state_set last_check "$(date +%s)"
  publish_status >/dev/null
  echo "$message" >&2
  return 1
}
fetch_text(){
  local url
  url="$1"
  if [ -n "$FIXTURE_DIR" ] && [ "$url" = "$API" ]; then cat "$FIXTURE_DIR/release.json"; return $?; fi
  if command -v curl >/dev/null 2>&1; then curl -fsSL --connect-timeout 10 --max-time 30 "$url"
  else wget -q -T 30 -O- "$url"; fi
}
fetch_file(){
  local url dest
  url="$1"; dest="$2"
  if [ -n "$FIXTURE_DIR" ]; then cp "$FIXTURE_DIR/${url##*/}" "$dest"; return $?; fi
  if command -v curl >/dev/null 2>&1; then curl -fsSL --connect-timeout 15 --max-time 180 -o "$dest" "$url"
  else wget -q -T 180 -O "$dest" "$url"; fi
}
check_unlocked(){
  local json tag archive checksum urls asset_url sha_url expected_prefix release_url
  json="$(fetch_text "$API" 2>/dev/null)" || { fail_check 'GitHub release bilgisi alınamadı.'; return 1; }
  tag="$(printf '%s\n' "$json" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
  valid_release_tag "$tag" || { fail_check 'GitHub latest release etiketi geçersiz.'; return 1; }
  archive="keenetic-zapret-smart-control-$tag.tar.gz"
  checksum="$archive.sha256"
  urls="$(printf '%s\n' "$json" | sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*\)".*/\1/p')"
  asset_url="$(printf '%s\n' "$urls" | awk -v s="/$archive" 'substr($0,length($0)-length(s)+1)==s {print;exit}')"
  sha_url="$(printf '%s\n' "$urls" | awk -v s="/$checksum" 'substr($0,length($0)-length(s)+1)==s {print;exit}')"
  expected_prefix="https://github.com/$REPO/releases/download/$tag/"
  [ "$asset_url" = "$expected_prefix$archive" ] || { fail_check 'Beklenen KZSC release arşivi bulunamadı.'; return 1; }
  [ "$sha_url" = "$expected_prefix$checksum" ] || { fail_check 'Beklenen KZSC SHA-256 dosyası bulunamadı.'; return 1; }
  release_url="$(printf '%s\n' "$json" | sed -n 's/.*"html_url":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
  case "$release_url" in "https://github.com/$REPO/releases/tag/$tag") :;; *) release_url="https://github.com/$REPO/releases/tag/$tag";; esac
  state_set latest "${tag#v}"
  state_set asset_url "$asset_url"
  state_set sha_url "$sha_url"
  state_set release_url "$release_url"
  state_set last_check "$(date +%s)"
  rm -f "$STATE/last_error"
  publish_status >/dev/null
  if version_gt "${tag#v}" "$(current_version)"; then
    if [ "$(state_get notified_latest)" != "${tag#v}" ]; then
      state_set notified_latest "${tag#v}"
      if [ -x /opt/kzsc/bin/kzsc-oplog.sh ]; then
        /opt/kzsc/bin/kzsc-oplog.sh append kzsc_update_available true \
          "Yeni KZSC sürümü bulundu: ${tag#v} (mevcut: $(current_version))." \
          "kzsc-update-available-${tag#v}" >/dev/null 2>&1 || true
      fi
    fi
    echo "Yeni KZSC sürümü bulundu: ${tag#v}"
  else
    echo "KZSC güncel: $(current_version)"
  fi
}
check(){
  local rc
  kzsc_lock_acquire updater || { echo 'Güncelleme kontrolü zaten çalışıyor.' >&2; return 1; }
  trap 'kzsc_lock_release updater' EXIT
  trap 'kzsc_lock_release updater; exit 130' INT TERM HUP
  check_unlocked; rc=$?
  # A completed manual check is a new operation. Do not keep an old failed or
  # successful apply result paired with a now-cleared error message.
  if [ "$rc" -eq 0 ]; then
    case "$(state_get apply_state)" in failed|success) state_set apply_state idle;; esac
    publish_status >/dev/null
  fi
  kzsc_lock_release updater; trap - EXIT INT TERM HUP
  return "$rc"
}
set_auto(){
  local value
  value="$1"; case "$value" in 0|1) :;; *) return 1;; esac
  mkdir -p "$KZSC_HOME/etc"
  [ -f "$CONF" ] || : >"$CONF"
  awk -v v="$value" 'BEGIN{done=0} /^KZSC_UPDATE_AUTO=/{if(!done){print "KZSC_UPDATE_AUTO=\"" v "\"";done=1}next} {print} END{if(!done)print "KZSC_UPDATE_AUTO=\"" v "\""}' "$CONF" >"$CONF.tmp.$$" && mv "$CONF.tmp.$$" "$CONF" || return 1
  chmod 600 "$CONF" 2>/dev/null || true
  publish_status >/dev/null
  [ "$value" = 1 ] && echo 'Otomatik KZSC güncellemesi açıldı.' || echo 'Otomatik KZSC güncellemesi kapatıldı.'
}
update_safe_now(){
  local f p
  [ ! -f "$KZSC_HOME/var/run/installing" ] || { echo 'Başka bir KZSC kurulumu devam ediyor.' >&2; return 1; }
  for f in "$KZSC_HOME"/var/blockcheck/*/pid; do
    [ -f "$f" ] || continue
    p="$(cat "$f" 2>/dev/null)"
    [ -n "$p" ] && kill -0 "$p" 2>/dev/null && { echo 'Blockcheck çalışırken KZSC güncellenemez.' >&2; return 1; }
  done
  return 0
}
install_async(){
  local p boot_id
  update_safe_now || return 1
  apply_worker_live && { echo 'KZSC güncellemesi zaten çalışıyor.' >&2; return 1; }
  state_set apply_queued_at "$(date +%s)"
  state_set apply_state queued; rm -f "$STATE/last_error"; publish_status >/dev/null
  ( "$UPDATE_SHELL" "$SELF" _apply >>"$LOG" 2>&1 ) &
  p=$!; state_set apply_pid "$p"
  boot_id="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null | head -n1 | tr -d '\r\n')"
  [ -z "$boot_id" ] || state_set apply_boot_id "$boot_id"
  echo "KZSC güncelleme işçisi başlatıldı: pid=$p"
}
archive_safe(){
  local archive_path archive_root list_path
  archive_path="$1"; archive_root="$2"; list_path="$3"
  tar -tzf "$archive_path" >"$list_path" 2>/dev/null || return 1
  awk -v r="$archive_root/" '
    NF==0 {bad=1}
    $0!=r && index($0,r)!=1 {bad=1}
    /^\// {bad=1}
    {n=split($0,a,"/"); for(i=1;i<=n;i++) if(a[i]==".."||a[i]==".") bad=1; count++}
    END{exit bad || count>500}
  ' "$list_path" || return 1
  tar -tvzf "$archive_path" 2>/dev/null | awk 'substr($1,1,1)=="l" || substr($1,1,1)=="h" {bad=1} END{exit bad}' || return 1
  return 0
}
apply_update(){
  local apply_tmp latest tag archive root asset_url sha_url bytes expected actual
  kzsc_lock_acquire updater || { state_set apply_state failed; state_set last_error 'Başka bir güncelleme işlemi çalışıyor.'; publish_status >/dev/null; return 1; }
  apply_tmp="${KZSC_UPDATE_TMP_BASE:-/opt/tmp}/kzsc-self-update.$$"
  KZSC_APPLY_TMP="$apply_tmp"
  cleanup_apply(){
    local cleanup_tmp="$KZSC_APPLY_TMP"
    case "$cleanup_tmp" in */kzsc-self-update.[0-9]*) rm -rf "$cleanup_tmp";; esac
    KZSC_APPLY_TMP=""
    rm -f "$STATE/apply_pid" "$STATE/apply_boot_id" "$STATE/apply_queued_at"
    kzsc_lock_release updater
  }
  trap 'cleanup_apply' EXIT
  trap 'cleanup_apply; exit 130' INT TERM HUP
  update_safe_now || { state_set apply_state failed; state_set last_error 'Blockcheck çalışırken güncelleme ertelendi.'; publish_status >/dev/null; return 1; }
  check_unlocked || { state_set apply_state failed; publish_status >/dev/null; return 1; }
  latest="$(state_get latest)"
  if ! version_gt "$latest" "$(current_version)"; then
    state_set apply_state idle; publish_status >/dev/null; echo 'Kurulacak daha yeni KZSC sürümü yok.'; return 0
  fi
  tag="v$latest"; archive="keenetic-zapret-smart-control-$tag.tar.gz"; root="keenetic-zapret-smart-control-$tag"
  asset_url="$(state_get asset_url)"; sha_url="$(state_get sha_url)"
  case "$apply_tmp" in */kzsc-self-update.[0-9]*) rm -rf "$apply_tmp";; *) return 1;; esac
  mkdir -p "$apply_tmp" || return 1
  state_set apply_state downloading; publish_status >/dev/null
  fetch_file "$asset_url" "$apply_tmp/$archive" || { state_set apply_state failed; state_set last_error 'KZSC arşivi indirilemedi.'; publish_status >/dev/null; return 1; }
  fetch_file "$sha_url" "$apply_tmp/$archive.sha256" || { state_set apply_state failed; state_set last_error 'KZSC SHA-256 dosyası indirilemedi.'; publish_status >/dev/null; return 1; }
  bytes="$(wc -c <"$apply_tmp/$archive" 2>/dev/null | tr -d ' ')"
  case "$bytes" in ''|*[!0-9]*) bytes=0;; esac
  [ "$bytes" -gt 0 ] && [ "$bytes" -le "$MAX_ARCHIVE_BYTES" ] || { state_set apply_state failed; state_set last_error 'KZSC arşiv boyutu güvenlik sınırını aşıyor.'; publish_status >/dev/null; return 1; }
  state_set apply_state verifying; publish_status >/dev/null
  expected="$(awk -v n="$archive" '$2==n || $2=="*"n {print $1;exit}' "$apply_tmp/$archive.sha256")"
  printf '%s\n' "$expected" | grep -Eq '^[0-9a-fA-F]{64}$' || { state_set apply_state failed; state_set last_error 'Release SHA-256 içeriği geçersiz.'; publish_status >/dev/null; return 1; }
  actual="$(sha256sum "$apply_tmp/$archive" | awk '{print $1}')"
  [ "$actual" = "$expected" ] || { state_set apply_state failed; state_set last_error 'KZSC arşivi SHA-256 doğrulamasını geçemedi.'; publish_status >/dev/null; return 1; }
  archive_safe "$apply_tmp/$archive" "$root" "$apply_tmp/list" || { state_set apply_state failed; state_set last_error 'KZSC arşiv yapısı güvenli değil.'; publish_status >/dev/null; return 1; }
  tar -xzf "$apply_tmp/$archive" -C "$apply_tmp" || { state_set apply_state failed; state_set last_error 'KZSC arşivi açılamadı.'; publish_status >/dev/null; return 1; }
  [ -f "$apply_tmp/$root/install.sh" ] && [ -f "$apply_tmp/$root/SHA256SUMS" ] || { state_set apply_state failed; state_set last_error 'KZSC release içeriği eksik.'; publish_status >/dev/null; return 1; }
  (cd "$apply_tmp/$root" && sha256sum -c SHA256SUMS >/dev/null 2>&1) || { state_set apply_state failed; state_set last_error 'KZSC iç kaynak manifesti doğrulanamadı.'; publish_status >/dev/null; return 1; }
  state_set apply_state installing; publish_status >/dev/null
  if (cd "$apply_tmp/$root" && "$UPDATE_SHELL" install.sh); then
    state_set apply_state success; rm -f "$STATE/last_error"; state_set latest "$latest"; publish_status >/dev/null
    /opt/kzsc/bin/kzsc-oplog.sh append kzsc_update_install true "KZSC $latest sürümüne güncellendi." "kzsc-update-$(date +%s)-$$" >/dev/null 2>&1 || true
    echo "KZSC $latest sürümüne güncellendi."
    return 0
  fi
  state_set apply_state failed; state_set last_error 'KZSC kurulumu başarısız oldu; önceki sürüm geri yüklendi.'; publish_status >/dev/null
  /opt/kzsc/bin/kzsc-oplog.sh append kzsc_update_install false 'KZSC güncellemesi başarısız; önceki sürüm geri yüklendi.' "kzsc-update-$(date +%s)-$$" >/dev/null 2>&1 || true
  return 1
}
tick(){
  local now last
  recover_stale_apply
  publish_status >/dev/null
  now="$(date +%s)"; last="$(state_get last_check)"; case "$last" in ''|*[!0-9]*) last=0;; esac
  [ $((now-last)) -ge "$(interval_seconds)" ] || return 0
  check || return 0
  if auto_enabled && version_gt "$(state_get latest)" "$(current_version)"; then install_async || true; fi
}

case "${1:-status}" in
  status|json|publish) recover_stale_apply; publish_status ;;
  check) check ;;
  tick) tick ;;
  auto) set_auto "$2" ;;
  install) install_async ;;
  _apply) apply_update ;;
  *) echo 'Usage: kzsc-updater {status|check|tick|auto 0|1|install}' >&2; exit 1 ;;
esac
