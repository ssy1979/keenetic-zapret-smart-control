**Türkçe** · [English](README.md)

# Keenetic Zapret Smart Control

KZSC; Keenetic router'larda Zapret2, WAN başına DPI, Blockcheck, güvenli DNS, Telegram bildirimleri, yedekleme ve Türkçe/İngilizce web panelini yöneten yetenek tabanlı bir uygulamadır.

Güncel sürüm: `v0.11.2.14-generic`

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

## Kurulum

Release arşivini Keenetic arayüzünden `/opt/tmp` dizinine yükleyin, SSH ile bağlanın ve çalıştırın:

```sh
cd /opt/tmp
sha256sum -c keenetic-zapret-smart-control-v0.11.2.14-generic.tar.gz.sha256
tar -xzf keenetic-zapret-smart-control-v0.11.2.14-generic.tar.gz
cd keenetic-zapret-smart-control-v0.11.2.14-generic
sh install.sh
```

Kurucu, servisleri durdurmadan önce salt-okunur uyumluluk kontrolü yapar. Yükseltme sonraki bir aşamada başarısız olursa önceki KZSC kodu ve ayarları otomatik geri yüklenir.

Kurulumdan sonra:

```sh
kzsc status
kzsc preflight
kzsc audit full
```

Varsayılan panel adresi `http://ROUTER_LAN_IP:9090/` şeklindedir.

## KZSC güncellemeleri

Türkçe/İngilizce **Güncelleme** sekmesi, güvenilir `ssy1979/keenetic-zapret-smart-control` GitHub release kanalını kontrol eder ve daha yeni bir `-generic` sürümü elle kurabilir. Otomatik kurulum açık rıza gerektirir ve varsayılan olarak kapalıdır; açıldığında daemon her 30 dakikada bir kontrol eder.

KZSC kurulumdan önce tam release dosya adlarını ve güvenilir GitHub adreslerini zorunlu tutar; dış SHA-256 dosyasını doğrular, güvensiz arşiv yollarını/linklerini ve aşırı büyük arşivleri reddeder, ardından arşiv içindeki `SHA256SUMS` manifestini doğrular. Eski sürüme dönüş önerilmez, Blockcheck çalışırken kurulum engellenir ve yükseltme başarısız olursa kurucu önceki kodu/ayarları geri yükler.

Kontrol, ayar ve sonuçlar hem üst bildirim kutularında hem Olay Günlüğü'nde görünür. Telegram sistem bildirimleri açıksa yeni bulunan sürüm her sürüm için yalnız bir kez bildirilir ve güncellemenin nihai sonucu bota gönderilir.

CLI karşılıkları:

```sh
kzsc update status
kzsc update check
kzsc update install
kzsc update auto on   # veya: off
```

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
