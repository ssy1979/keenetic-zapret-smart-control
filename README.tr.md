**Türkçe** · [English](README.md)

# Keenetic Zapret Smart Control

KZSC; Keenetic router'larda Zapret2, WAN başına DPI, Blockcheck, güvenli DNS, Telegram bildirimleri, yedekleme ve Türkçe/İngilizce web panelini yöneten yetenek tabanlı bir uygulamadır. Aynı proje içindeki **KZSC Hazırlayıcı**, Windows üzerinden gerekli KeeneticOS/OPKG/Entware tabanını kurar; güvenli DNS ayarları kurulumdan sonra KZSC tarafından yönetilir.

Güncel sürüm: `v0.11.2.41-generic`

<!-- KZSC_HAZIRLAYICI_START: Sürüm belgeleri güncellenirken bu bloğu koruyun. -->
## Önerilen kolay kurulum

![KZSC kurulum akışı](docs/images/kurulum-akisi.svg)

1. [Son GitHub sürümünü](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest) açın.
2. Assets bölümünden `KZSC-Hazirlayici-v1.2.7.zip` dosyasını indirin ve tamamen çıkartın.
3. `KZSC-Hazirlayici.exe` dosyasını çalıştırın.
4. Keenetic'i otomatik buldurun, SSH 22 yönetici bilgileriyle analiz edin.
5. USB/dahili depolama hedefini seçin; DNS ve WAN ayarları kurulumdan sonra KZSC'den yönetilir.
6. Planı okuyup uygulayın. Hazırlayıcı Entware SSH 222 tabanını ve KZSC'yi tamamlar.
7. Kurulumdan sonra `http://ROUTER_IP:9090/` adresini açın.

Hiç SSH/Entware deneyimi olmayan kullanıcılar için ekran görüntülü, adım adım anlatım: **[KZSC görselli kolay kurulum rehberi](docs/KURULUM.md)**

![KZSC genel bakış](docs/images/kzsc-genel-bakis.png)

### Projenin iki parçası

- **Windows: KZSC Hazırlayıcı** — ağda cihaz bulma, SSH 22 analizi, eksik KeeneticOS bileşenleri, USB/dahili OPKG, Entware SSH 222 ve otomatik KZSC kurulumu. DNS ayarlarına dokunmaz.
- **Router: KZSC** — `/opt/kzsc` altında çalışan web paneli, WAN/DPI/Blockcheck, Zapret2 yönetimi, DNS, Telegram, yedekleme ve güvenli güncelleme.

Hazırlayıcı kaynakları: [`tools/kzsc-hazirlayici`](tools/kzsc-hazirlayici)
<!-- KZSC_HAZIRLAYICI_END -->

## Desteklenen router topolojisi

Kurucu router'ı sabit bir model listesinden onaylamaz. Mevcut kurulumu değiştirmeden önce cihazın gerçek yeteneklerini denetler:

- KeeneticOS Open Package desteği ve `/opt` altında Entware
- `dns-tls` ve `dns-https` KeeneticOS bileşenleri
- `mod_cgi` ile lighttpd
- iptables mangle/filter, NFQUEUE ve queue bypass desteği
- cihazda başarıyla çalıştırılabilen uyumlu Zapret2 CPU ikilisi
- bir veya daha fazla desteklenen internet bağlantısı

Desteklenen WAN türleri PPPoE, kablolu IPoE/Ethernet (upstream router'dan DHCP/statik, özel veya genel IPv4 dahil) ve Keenetic WISP'tir. L2TP/PPTP ile mobil/USB modem WAN'ları bu sürümün bilinçli olarak kapsamı dışındadır.

KN-1811, KN-1812, KN-1012, KN-3610 ve KN-3611 gibi modeller aynı keşif yolu ile ele alınır. Bir model yalnız cihaz üzerindeki pre-flight kontrolü geçtiğinde uyumlu kabul edilir; böylece test edilmemiş yalnız-model-adı vaadinde bulunulmaz.

## Elle kurulum

Yeni kullanıcılar için yukarıdaki Windows hazırlayıcı önerilir. Elle kurulumda çalışan bir OPKG/Entware `/opt` tabanı yeterlidir; kurucu eksik KeeneticOS DNS/netfilter bileşenlerini ve gerekli Entware paketlerini kendisi belirleyip kurar. KeeneticOS bileşen değişikliği router'ı yeniden başlatırsa aynı doğrulanmış kurulum açılıştan sonra otomatik devam eder.

Release arşivini Keenetic arayüzünden `/opt/tmp` dizinine yükleyin, SSH ile bağlanın ve çalıştırın:

```sh
cd /opt/tmp
sha256sum -c keenetic-zapret-smart-control-v0.11.2.41-generic.tar.gz.sha256
tar -xzf keenetic-zapret-smart-control-v0.11.2.41-generic.tar.gz
cd keenetic-zapret-smart-control-v0.11.2.41-generic
sh install.sh
```

Kurucu önce yalnız eksik bağımlılıkları tamamlar, ardından servisleri durdurmadan salt-okunur uyumluluk kontrolü yapar. Yükseltme sonraki bir aşamada başarısız olursa önceki KZSC kodu ve ayarları otomatik geri yüklenir. Bileşen kurulumu nedeniyle yeniden başlatma gerekirse ilerleme `/opt/tmp/kzsc-bootstrap-resume.log` dosyasından izlenebilir.

Kurulumdan sonra:

```sh
kzsc status
kzsc preflight
kzsc audit full
```

Varsayılan panel adresi `http://ROUTER_LAN_IP:9090/` şeklindedir.

> Tek seferlik yükseltme notu: v0.11.2.14 ve v0.11.2.15 içindeki güncelleyicide BusyBox `ash` değişken kapsamı hatası vardır. Güncel sürümü yukarıdaki doğrulanmış arşivle elle kurun. v0.11.2.16 ve sonraki sürümlerde otomatik güncelleme normal çalışır.

## KZSC güncellemeleri

Türkçe/İngilizce **Güncelleme** sekmesi, güvenilir `ssy1979/keenetic-zapret-smart-control` GitHub release kanalını kontrol eder ve daha yeni bir `-generic` sürümü elle kurabilir. Otomatik kurulum açık rıza gerektirir ve varsayılan olarak kapalıdır; açıldığında daemon her 30 dakikada bir kontrol eder.

KZSC kurulumdan önce tam release dosya adlarını ve güvenilir GitHub adreslerini zorunlu tutar; dış SHA-256 dosyasını doğrular, güvensiz arşiv yollarını/linklerini ve aşırı büyük arşivleri reddeder, ardından arşiv içindeki `SHA256SUMS` manifestini doğrular. Eski sürüme dönüş önerilmez, Blockcheck çalışırken kurulum engellenir ve yükseltme başarısız olursa kurucu önceki kodu/ayarları geri yükler.

Kontrol, ayar ve sonuçlar üst bildirim kutularında görünür. Eski Olay Günlüğü sekmesi web panelinden kaldırılmıştır; korunan arka plan denetim kaydı tanılama ve Telegram senkronizasyonu için çalışmaya devam eder. Telegram sistem bildirimleri açıksa yeni bulunan sürüm her sürüm için yalnız bir kez bildirilir ve güncellemenin nihai sonucu bota gönderilir.

Telegram komutları etkinleştirildiğinde `/kzsc_update` güncelleme menüsünü açar. Yetkili sohbet yeni sürümü kontrol edebilir, durumu görebilir, otomatik güncellemeyi açıp kapatabilir ve açık onay butonundan sonra mevcut güncellemeyi başlatabilir.

CLI karşılıkları:

```sh
kzsc update status
kzsc update check
kzsc update install
kzsc update auto on   # veya: off
```

**Ayarlar** sekmesindeki onaylı **KZSC'yi Yeniden Başlat** işlemi yalnız KZSC daemon ve web arayüzünü yeniden başlatır ve health endpoint tekrar hazır olana kadar bekler. Yanındaki ayrı **Router'ı Yeniden Başlat** düğmesi ise açık kullanıcı onayından sonra Keenetic `ndmc` üzerinden 30 saniyelik planlı sistem yeniden başlatması oluşturur; bu işlem internet ve yerel ağ bağlantılarını geçici olarak keser.

## Testler

POSIX geliştirme sisteminde:

```sh
sh tests/test-adaptive-wan.sh
sh tests/test-updater.sh
```

Test paketleri; birden dört WAN'a kadar karma PPPoE/IPoE/WISP keşfi ve eşlemesini, WAN başına queue ve CGI üretimini, queue tükenmesini, desteklenmeyen WAN reddini, mutlak Blockcheck süre sınırını, güvenilir release sabitlemesini, eski sürüm reddini, otomatik güncelleme açık-rıza davranışını ve güncelleme güvenlik korumalarını kapsar.

## Zapret2 ilişkisi

Zapret2 bu depoya veya KZSC release arşivine dahil edilmez. Operatör istediğinde KZSC, resmi `bol-van/zapret2` release'ini indirir, upstream mimari seçicisinden uyumlu ikiliyi ister ve seçilen araçların router üzerinde çalıştığını doğrular. Ayrıntılar için [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) dosyasına bakın.

KZSC bağımsız bir topluluk projesidir; Keenetic veya Zapret2 projesi ile bağlantılı/resmî değildir. Yalnız hukuka, internet sağlayıcınızın koşullarına ve yerel kurallara uygun biçimde kullanın.

Güvenlik bildirimleri: [SECURITY.md](SECURITY.md). Katkı rehberi: [CONTRIBUTING.md](CONTRIBUTING.md). Ayrıntılı sürüm geçmişi: [README.txt](README.txt).

KZSC [MIT Lisansı](LICENSE) ile yayımlanır. Üçüncü taraf yazılımlar kendi lisanslarını korur.
