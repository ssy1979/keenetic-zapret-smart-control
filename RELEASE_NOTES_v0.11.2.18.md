# KZSC v0.11.2.18-generic

## Türkçe

Bu bakım sürümü, v0.11.2.17 yükseltmesinden sonra gerçek daemon durmuşken `kzsc start` komutunun stale bir PID nedeniyle başarılı görünmesini düzeltir ve servis yaşam döngüsünü SSH/güncelleme kabuğundan bağımsızlaştırır.

### Değişiklikler

- Kalıcı `daemon.pid` ve `daemon.lock/pid` değerleri artık yalnız PID canlı olduğu için güvenilir sayılmaz; süreç komut satırının gerçekten `/opt/kzsc/bin/kzsc-daemon.sh` olduğu da doğrulanır.
- Kernel eski PID'yi başka bir sürece verdiğinde KZSC ilgisiz süreci daemon sanmaz, o sürece sinyal göndermez ve yalnız stale KZSC çalışma dosyalarını temizleyerek gerçek daemon'u başlatır.
- Aynı süreç kimliği kontrolü daemon'un kendi atomik singleton kilidinde ve `kzsc status` sonucunda da kullanılır.
- Daemon standart girdisi çağıran kabuktan ayrılır ve SSH oturumu ya da güncelleme üst süreci kapanırken gelen `HUP` sinyalini yok sayar. Normal `kzsc stop/restart` işlemleri `TERM` üzerinden temiz kapanmaya devam eder.
- Güncelleme işçisinin PID kaydı da aynı boot içinde başka sürece verilmiş bir PID ile karıştırılmaz; PID'nin updater komut satırıyla eşleşmesi zorunludur.
- Başarılı manuel `kzsc update check`, önceki `failed` veya `success` kurulum sonucunu boş hata metniyle taşımak yerine yeni kontrolü `idle` durumunda yayımlar.
- PID reuse, yanlış süreç kimliği, HUP dayanıklılığı ve stdin ayrıştırması ayrı daemon yaşam döngüsü regresyon testiyle hem CI hem release kapısına eklendi.
- KZSC Hazırlayıcı v1.2.4, iki dilli kurulum belgeleri, README koruma işaretleri ve repository ownership testi değiştirilmeden korunur.

### Güncelleme

v0.11.2.17 üzerinde otomatik güncelleme açıksa bu sürüm 30 dakikalık kontrol sırasında doğrulanarak kurulabilir. Manuel kurulum için:

```sh
kzsc update check
kzsc update install
```

## English

This maintenance release fixes a stale-PID condition where `kzsc start` could appear successful even though the real daemon remained stopped after upgrading to v0.11.2.17. It also detaches the service lifecycle from the parent SSH/update shell.

### Changes

- Persisted `daemon.pid` and `daemon.lock/pid` values are no longer trusted merely because the numeric PID is alive; the process command line must identify the exact `/opt/kzsc/bin/kzsc-daemon.sh` service.
- If the kernel reuses a stale PID for an unrelated process, KZSC neither mistakes it for the daemon nor signals it. Only stale KZSC runtime files are cleared before the real daemon starts.
- The same process-identity guard is used by the daemon's atomic singleton lock and by `kzsc status`.
- Daemon stdin is detached from the caller and the service ignores `HUP` when an SSH session or update parent exits. Normal `kzsc stop/restart` operations continue to terminate cleanly through `TERM`.
- An updater worker PID must also match the updater command line, preventing a reused PID in the same boot from blocking or impersonating an update worker.
- A successful manual `kzsc update check` now publishes a fresh `idle` operation instead of retaining an old `failed` or `success` apply result with an empty error message.
- A dedicated daemon-lifecycle regression suite covers PID reuse, exact process identity, HUP resilience, and stdin detachment in both CI and the release gate.
- KZSC Preparer v1.2.4, bilingual installation guides, protected README markers, and the repository ownership test remain unchanged and protected.

### Update

When automatic updates are enabled on v0.11.2.17, this release can be verified and installed during the 30-minute check. For a manual update:

```sh
kzsc update check
kzsc update install
```
