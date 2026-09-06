# KZSC v0.11.2.55-generic + Hazırlayıcı / Preparer v1.2.8

## Türkçe

Bu ortak sürüm, 0.11.2.54 kurulumunda bildirilen son denetim hatasını ve incelemede bulunan kurulum, servis ve paketleme sorunlarını düzeltir.

- Eksik `kzsc-purity.sh` özgün, salt okunur uygulamayla eklendi. Güncel UI işlevleri ve CGI listesi denetleniyor; eski sürüm metinleri eşitlendi.
- Sıradaki WAN uzlaştırması ve gerçekten devam eden Blockcheck hata sayılmıyor; bozuk durumlar, başarısız işlemler ve durmuş servisler başarısızlık olarak kalıyor.
- Hazırlayıcı paketin tamamını cihazda değişiklikten önce doğrular. Eksik dosya, kapsam dışı manifest, yol kaçışı, özel dosya, sürüm uyuşmazlığı ve boyut sınırı ihlali kurulumu durdurur.
- SSH çıktı/hata akışları birlikte okunur; zaman aşımı kısmi yanıtı başarıya dönüştürmez. Bileşen yeniden başlatması sonrası hazırlayıcı yeniden bağlanır ve gerçek kurulum sonucunu denetler.
- Daemon, web ve güncelleme süreçlerinde PID kimliği doğrulanır. Servis durmuşken başarılı durum kodu döndürülmez.
- Harici uygulamaların dosyaları, önbellekleri ve süreçleri otomatik silinmez/sonlandırılmaz. Etkin çakışma varsa kendi kaldırma yönergeleriyle müdahale istenir.
- Önceden uyarlanmış DPI profilleri ve IPv6 dönüşüm kodu bağımsız uygulamalarla değiştirildi. Yeni genel başlangıç profilleri herhangi bir ISS üzerinde başarı garantisi taşımaz; WAN başına Blockcheck çalıştırın. Eski yayımların lisans bildirimleri geçmişe ilişkin doğruluk için korunur.
- IPv6 başarısızlıkta WAN bazında geri alınır. Cihaz bazlı bir DPI kapatma tercihi varsa, IPv6 adresleri eksiksiz izlenmediği için IPv6 DPI bekletilir; IPv4 cihaz istisnaları korunur.
- Kaynak manifesti artık zorunlu ve tam kapsamlıdır; router paketi yalnız gerekli router dosyalarını içerir. Windows paketi test edilip gerçek TR/EN arayüzü çevrimdışı açılmadan yayımlanmaz.

**Kurulum:** [Hazırlayıcı v1.2.8 ZIP](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/download/v0.11.2.55-generic/KZSC-Hazirlayici-v1.2.8.zip) dosyasını tamamen çıkarın. Eski hazırlayıcıyı kapatıp yenisini açın, mevcut Entware `/opt` hedefini seçin ve kurulumu yeniden başlatın. Router'ı sıfırlamayın, diski biçimlendirmeyin. [Görselli kurulum ve kurtarma](docs/KURULUM.md).

**Doğrulama sınırı:** Otomatik testler, paket bütünlüğü ve Windows açılış testi fiziksel olarak tüm Keenetic modellerinde canlı test yerine geçmez. Uyumluluk cihazın ön denetimine, DPI başarısı ise bağlantıdaki Blockcheck sonucuna bağlıdır.

## English

This joint release fixes the reported 0.11.2.54 final installation audit failure and additional installation, service and packaging defects found during review.

- Restores the missing purity backend with an original read-only implementation; aligns current UI/CGI contracts and version reporting.
- Distinguishes legitimate pending WAN reconciliation and active Blockcheck from failed or malformed state. Stopped services no longer report success.
- Preparer validates the complete release before router changes, including exact manifest coverage, required files, version, paths, archive types and size limits.
- SSH output streams drain together; partial timeout responses do not pass as complete. Component reboots are followed by reconnect and real final verification.
- Process ownership checks prevent stale/reused PIDs from being treated as daemon, web or update workers.
- External application files/caches/processes are not automatically deleted or stopped. Active conflicts require their own shutdown instructions.
- Previously adapted DPI profiles and IPv6 transformation code were independently replaced. Generic conservative baselines require real per-WAN Blockcheck; they are not ISP-validated. Historical license notices remain accurate for older releases.
- Failed IPv6 attachment rolls back per WAN. Optional IPv6 DPI pauses while a device exclusion exists because complete IPv6 client identity is not yet tracked; IPv4 exclusions remain enforced.
- Publication requires the complete source manifest, router-only package readback, regression tests and an offline launch of the packaged Windows TR/EN interface.

**Install:** Fully extract [Preparer v1.2.8 ZIP](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/download/v0.11.2.55-generic/KZSC-Hazirlayici-v1.2.8.zip), close the old preparer, choose your existing Entware `/opt`, and retry. Do not factory-reset or format storage. [Visual installation and recovery guide](docs/INSTALLATION.md).

**Verification scope:** Automated tests, package integrity and Windows launch testing are not live tests on every Keenetic model. Compatibility is capability-gated; DPI effectiveness requires Blockcheck on the actual connection.
