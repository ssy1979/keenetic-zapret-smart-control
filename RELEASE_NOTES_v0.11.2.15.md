# KZSC v0.11.2.15-generic

## Türkçe

Bu düzeltme sürümü, web arayüzündeki **Güncelleme** sekmesinde görülen `maintenance_queue_unavailable` hatasını giderir. Bazı yükseltmelerde `/opt/kzsc/var` veya `/opt/kzsc/var/run` dizinleri 0700 izniyle kalıyor ve lighttpd CGI kullanıcısı, bakım kuyruğunun kendisi yazılabilir olsa bile üst dizinlerden geçemiyordu.

### Değişiklikler

- Kurucu, servis ve daemon bakım kuyruğunun tüm yolunu güvenli izinlerle hazırlar: üst dizinler 0711, listeleme kapalı yazma kuyruğu 0733.
- Health CGI bakım kuyruğuna gerçek bir probe dosyası yazıp siler; `kzsc audit http` ve `kzsc audit full` artık bu koşulu doğrular.
- Arayüzdeki **Her 30 dakikada bir kontrol et ve yeni sürümü otomatik kur** kutusunun açma ve kapatma eylemleri regresyon testine eklendi.
- Ham hata kodları yerine anlaşılır Türkçe ve İngilizce bildirimler gösterilir.
- Mevcut ayarlar, WAN keşfi, DPI/Blockcheck, Zapret2, DNS ve Telegram güncelleme bildirimleri korunur.

### Kurulum

```sh
cd /opt/tmp
sha256sum -c keenetic-zapret-smart-control-v0.11.2.15-generic.tar.gz.sha256
tar -xzf keenetic-zapret-smart-control-v0.11.2.15-generic.tar.gz
cd keenetic-zapret-smart-control-v0.11.2.15-generic
sh install.sh
```

Mevcut v0.11.2.14 kurulumunda CLI güncelleyici de kullanılabilir:

```sh
kzsc update check
kzsc update install
kzsc update auto on
```

## English

This patch fixes the `maintenance_queue_unavailable` error in the web **Update** tab. On some upgraded installations, `/opt/kzsc/var` or `/opt/kzsc/var/run` retained mode 0700. This prevented the unprivileged lighttpd CGI user from traversing the parent path even when the queue itself was writable.

### Changes

- The installer, service, and daemon now prepare the complete maintenance-queue path with safe permissions: 0711 on traversal-only parents and 0733 on the non-listable write queue.
- The health CGI writes and removes a real probe file; `kzsc audit http` and `kzsc audit full` now verify this runtime condition.
- Regression coverage now includes both actions behind the **Check every 30 minutes and install new releases automatically** toggle.
- Raw error codes are replaced with clear Turkish and English notifications.
- Existing settings, WAN discovery, DPI/Blockcheck, Zapret2, DNS, and Telegram update notifications are preserved.

### Installation

```sh
cd /opt/tmp
sha256sum -c keenetic-zapret-smart-control-v0.11.2.15-generic.tar.gz.sha256
tar -xzf keenetic-zapret-smart-control-v0.11.2.15-generic.tar.gz
cd keenetic-zapret-smart-control-v0.11.2.15-generic
sh install.sh
```

An existing v0.11.2.14 installation can also use the CLI updater:

```sh
kzsc update check
kzsc update install
kzsc update auto on
```
