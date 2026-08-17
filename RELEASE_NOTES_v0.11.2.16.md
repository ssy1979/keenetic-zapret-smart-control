# KZSC v0.11.2.16-generic

## Türkçe

Bu düzeltme sürümü, v0.11.2.14 ve v0.11.2.15 güncelleyicilerinde BusyBox `ash` altında oluşan değişken kapsamı hatasını giderir. Durum JSON'unu yayımlayan fonksiyon, güncelleme işçisinin geçici dizinini; arşiv güvenlik denetimi de arşiv adını ezebiliyordu. Arşiv indirilip SHA-256 doğrulamasından geçse bile `tar` bu nedenle yanlış bir yola yöneliyordu.

### Değişiklikler

- Güncelleyicinin bütün fonksiyon değişkenleri BusyBox `ash` için yerelleştirildi.
- Durum dosyası, arşiv adı ve güncelleme çalışma dizini birbirinden bağımsız adlarla korunuyor.
- Geçici dizin temizliği yalnız `kzsc-self-update.<pid>` kalıbıyla eşleşen güvenli hedefte çalışıyor.
- Regresyon testi artık gerçek bir release fixture arşivini indiriyor, dış SHA-256 ile iç `SHA256SUMS` manifestini doğruluyor, arşivi açıyor, fixture kurucusunu çalıştırıyor, başarı durumunu yayımlıyor ve geçici dosya temizliğini denetliyor.
- Telegram botuna `/kzsc_update`, `/kzsc_update_check`, `/kzsc_update_install`, `/kzsc_update_auto_on` ve `/kzsc_update_auto_off` komutları eklendi.
- Telegram inline menüsünden sürüm kontrolü, durum görüntüleme, otomatik güncelleme aç/kapat ve ikinci bir onay butonundan sonra kurulum başlatma destekleniyor.
- v0.11.2.15 bakım kuyruğu izin düzeltmesi, uyarlamalı WAN keşfi, Blockcheck sınırları, Zapret2, DNS ve bildirim işlevleri korunuyor.

### Tek seferlik kurulum gereksinimi

v0.11.2.14/v0.11.2.15 üzerindeki hatalı güncelleyici kendi düzeltmesini otomatik kuramaz. Bu sürümü bir kez Keenetic arayüzünden `/opt/tmp` dizinine yükleyip elle kurun:

```sh
cd /opt/tmp
sha256sum -c keenetic-zapret-smart-control-v0.11.2.16-generic.tar.gz.sha256
tar -xzf keenetic-zapret-smart-control-v0.11.2.16-generic.tar.gz
cd keenetic-zapret-smart-control-v0.11.2.16-generic
sh install.sh
```

Kurulumdan sonra:

```sh
kzsc status
kzsc update status
kzsc audit full
kzsc update auto on
```

v0.11.2.16 ve sonraki sürümlerde manuel, web, Telegram ve 30 dakikalık otomatik güncelleme yolları aynı doğrulanan backend'i kullanır.

## English

This patch fixes a BusyBox `ash` variable-scope bug in the v0.11.2.14 and v0.11.2.15 updaters. The status publisher could overwrite the update worker's temporary directory, while the archive safety check could overwrite the archive name. Even after a successful download and SHA-256 verification, `tar` was therefore pointed at an invalid path.

### Changes

- All updater function variables are now local under BusyBox `ash`.
- Status output, archive naming, and the update workspace use independent variables.
- Temporary cleanup is restricted to a safe `kzsc-self-update.<pid>` path pattern.
- The regression suite now downloads a real release fixture, verifies the external SHA-256 and internal `SHA256SUMS`, extracts it, runs its fixture installer, publishes success, and verifies cleanup.
- Telegram commands `/kzsc_update`, `/kzsc_update_check`, `/kzsc_update_install`, `/kzsc_update_auto_on`, and `/kzsc_update_auto_off` are included.
- The Telegram inline menu supports release checks, status, automatic-update toggling, and installation after a second confirmation button.
- The v0.11.2.15 maintenance-queue permission fix, adaptive WAN discovery, Blockcheck limits, Zapret2, DNS, and notification behavior remain intact.

### One-time installation requirement

The faulty updater on v0.11.2.14/v0.11.2.15 cannot install its own repair. Upload this release once through the Keenetic interface to `/opt/tmp` and install it manually:

```sh
cd /opt/tmp
sha256sum -c keenetic-zapret-smart-control-v0.11.2.16-generic.tar.gz.sha256
tar -xzf keenetic-zapret-smart-control-v0.11.2.16-generic.tar.gz
cd keenetic-zapret-smart-control-v0.11.2.16-generic
sh install.sh
```

After installation:

```sh
kzsc status
kzsc update status
kzsc audit full
kzsc update auto on
```

From v0.11.2.16 onward, manual, web, Telegram, and 30-minute automatic updates all use the same verified backend.
