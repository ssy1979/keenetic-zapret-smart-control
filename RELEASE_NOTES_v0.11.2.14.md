# KZSC v0.11.2.14-generic

## Türkçe

### Öne çıkanlar

- Model-listesi yerine gerçek cihaz yeteneklerini kullanan salt-okunur kurulum pre-flight kontrolü.
- Tek veya çok WAN için PPPoE, kablolu IPoE/Ethernet ve Keenetic WISP desteği.
- WAN başına dinamik Linux arayüz eşlemesi, benzersiz NFQUEUE, DPI/Blockcheck ve CGI üretimi.
- KeeneticOS `dns-tls` (DoT) ve `dns-https` (DoH), Entware, lighttpd/mod_cgi ve firewall yetenek doğrulaması.
- Blockcheck'in işçi girişinde başlayan ve hiçbir aşamada sıfırlanmayan mutlak 30 dakika sınırı; backend'de en fazla 10 hedef/240 karakter.
- Queue tükenmesinde güvenli kapanma; yanlış mimari veya segfault eden Zapret2 ikilisini reddetme.
- Başarısız yükseltmede önceki çalışan KZSC kodu ve ayarlarına otomatik geri dönüş.
- Ayrı Türkçe/İngilizce Güncelleme sekmesi; manuel kontrol/kurulum ve varsayılan kapalı, 30 dakikalık otomatik kontrol/kurulum seçeneği.
- Güvenilir GitHub repository/asset sabitlemesi, SHA-256 + iç manifest, güvenli arşiv yapısı/boyutu ve downgrade kontrolleri.
- Güncelleme işlemlerinin üst bildirimler, Olay Günlüğü ve Telegram sistem bildirimleriyle senkronizasyonu; yeni sürüm mesajı sürüm başına tekilleştirilir.
- 1–4 WAN karma PPPoE/IPoE/WISP ve güvenli updater regresyon testleri ile GitHub CI.

### Kurulum

Arşiv ile `.sha256` dosyasını Keenetic üzerinde `/opt/tmp` dizinine yükleyin:

```sh
cd /opt/tmp
sha256sum -c keenetic-zapret-smart-control-v0.11.2.14-generic.tar.gz.sha256
tar -xzf keenetic-zapret-smart-control-v0.11.2.14-generic.tar.gz
cd keenetic-zapret-smart-control-v0.11.2.14-generic
sh install.sh
kzsc audit full
```

Eski bağımsız manager/Zapret2 kalıntısı bilerek kaldırılacaksa yalnız ne yaptığınızdan eminseniz `sh install.sh --remove-retired` kullanın.

---

## English

### Highlights

- Read-only installation pre-flight based on actual device capabilities instead of a model allow-list.
- PPPoE, wired IPoE/Ethernet, and Keenetic WISP support for single- or multi-WAN routers.
- Dynamic per-WAN Linux interface mapping, unique NFQUEUE allocation, DPI/Blockcheck, and CGI generation.
- Validation of KeeneticOS `dns-tls` (DoT) and `dns-https` (DoH), Entware, lighttpd/mod_cgi, and firewall capabilities.
- An absolute 30-minute Blockcheck limit starting at worker entry and never reset by later phases; backend limit of 10 targets/240 characters.
- Fail-closed queue exhaustion and rejection of wrong-architecture or signal-crashing Zapret2 binaries.
- Automatic restoration of the previous working KZSC code and configuration after a failed upgrade.
- A separate bilingual Update tab with manual check/install and an opt-in 30-minute automatic check/install option that is off by default.
- Trusted GitHub repository/asset pinning, SHA-256 plus internal-manifest verification, safe archive structure/size checks, and downgrade prevention.
- Update synchronization across top operation notices, Event Log, and Telegram system notifications, with one new-release notification per version.
- Mixed 1–4 WAN PPPoE/IPoE/WISP and secure-updater regression tests with GitHub CI.

### Installation

Upload the archive and its `.sha256` file to `/opt/tmp` on the Keenetic:

```sh
cd /opt/tmp
sha256sum -c keenetic-zapret-smart-control-v0.11.2.14-generic.tar.gz.sha256
tar -xzf keenetic-zapret-smart-control-v0.11.2.14-generic.tar.gz
cd keenetic-zapret-smart-control-v0.11.2.14-generic
sh install.sh
kzsc audit full
```

Use `sh install.sh --remove-retired` only when you intentionally want to remove a detected retired standalone manager/Zapret2 tree and understand the effect.
