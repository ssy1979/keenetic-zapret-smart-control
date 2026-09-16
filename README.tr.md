<p align="center">
  <img src="docs/images/kzsc-genel-bakis.png" alt="KZSC router paneli" width="820">
</p>

<h1 align="center">Keenetic Zapret Smart Control</h1>

<p align="center">Keenetic router üzerinde Zapret2 kurulumu ve yönetimi için sade çözüm.</p>

<p align="center">
  <a href="https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest"><img src="https://img.shields.io/github/v/release/ssy1979/keenetic-zapret-smart-control?display_name=tag&style=for-the-badge&color=2ea44f" alt="Güncel sürüm"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/lisans-MIT-7c3aed?style=for-the-badge" alt="MIT lisansı"></a>
  <img src="https://img.shields.io/badge/KeeneticOS-destekli-0ea5e9?style=for-the-badge" alt="KeeneticOS">
</p>

<p align="center"><strong>🇹🇷 Türkçe rehber</strong> · <a href="README.md">🇬🇧 English guide</a></p>

> [!IMPORTANT]
> **İlk kurulum için Windows’taki KZSC Hazırlayıcı’yı kullanın.** Komut yazmadan ilerlemenin önerilen yolu budur.

<!-- KZSC_HAZIRLAYICI_START: Windows hazırlayıcı sözleşmesi -->
## Hangi parçayı kullanacağım?

| İhtiyacınız | Kullanacağınız araç |
| --- | --- |
| Windows bilgisayardan ilk KZSC kurulumu | **KZSC Hazırlayıcı** |
| Sonrasında Zapret2, DNS, WAN, cihaz ve güncellemeleri yönetmek | **KZSC Router Paneli** |
| Windows bilgisayar olmadan kurulum | [Manuel alternatif](docs/KURULUM.md#manuel-alternatif) |

## 4 kolay adımda kurulum

1. Router’da **Genel sistem ayarları → Bileşen seçenekleri** bölümünden **SSH sunucusu** bileşenini etkinleştirin. SSH yalnız yerel ağda açık kalsın.
2. [Son sürüm](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest) sayfasını açın, **`KZSC-Hazirlayici-*.zip`** dosyasını indirin ve ZIP’in tamamını çıkartın.
3. `KZSC-Hazirlayici.exe` dosyasını açın, router yönetici bilgilerini girin ve **Bağlan ve cihazı analiz et** seçeneğine basın.
4. Planı okuyun, ardından **Planı uygula** seçeneğine basın. İşlem tamamlandığında `http://ROUTER_IP:9090/` adresini açın.

![KZSC Hazırlayıcı başlangıç ekranı](docs/images/kzsc-hazirlayici-baslangic.png)

**Hepsi bu kadar.** Hazırlayıcı uyumluluğu denetler, gerekirse OPKG/Entware tabanını hazırlar ve KZSC’yi kurar. Disk biçimlendirmez, parolaları kaydetmez.

Tüm ekranların kısa açıklaması ve olası sorunlar için [görselli kolay kurulum rehberini](docs/KURULUM.md) açın.
<!-- KZSC_HAZIRLAYICI_END -->

## Kurulumdan sonra

Yerel ağdan `http://ROUTER_IP:9090/` adresini açın.

| Sayfa | Ne yaparsınız? |
| --- | --- |
| **Genel Bakış** | KZSC ve WAN’ların sağlıklı olduğunu kontrol edersiniz. |
| **Zapret2 / DPI** | Filtrelemeyi açar ve ayarlarsınız. |
| **Cihazlar** | Çevrimiçi veya Keenetic’e kayıtlı çevrimdışı cihazları dahil eder ya da dışarıda bırakırsınız. Tercih MAC adresine göre saklanır. |
| **Güncelleme** | Doğrulanmış yeni sürümleri denetler ve kurarsınız. |

![KZSC güncelleme sayfası](docs/images/kzsc-guncelleme.png)

## Başlamadan önce

- Bilgisayar ve router aynı yerel ağda olmalı.
- Router yönetici kullanıcı adı ve parolası gerekli.
- Router’ın internet bağlantısı çalışıyor olmalı.
- Yeni Entware kurulacaksa EXT2/EXT3/EXT4 biçimli desteklenen bir USB bölümünü takın veya desteklenen dahili depolamayı kullanın.

Hazırlayıcı router’ı değiştirmeden önce gerçek yeteneklerini denetler. Uyumlu PPPoE, IPoE/Ethernet ve WISP bağlantıları desteklenir; desteklenmeyen bir yapı sessizce değiştirilmez, planda gösterilir.

## Yardım

- [Görselli kolay kurulum rehberi](docs/KURULUM.md)
- [English guide](docs/INSTALLATION.md)
- [Sürüm notları](RELEASE_NOTES_v1.0.6.md)
- [Güvenlik politikası](SECURITY.md)

Router parolasını, Telegram token’ını, yedekleri, genel IP’yi veya KeenDNS adresini public issue içinde paylaşmayın. KZSC bağımsız bir topluluk projesidir; Keenetic veya Zapret2’nin resmî ürünü değildir.
