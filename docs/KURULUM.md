# KZSC görselli kolay kurulum rehberi

[← Ana sayfa](../README.tr.md) · [🇬🇧 English guide](INSTALLATION.md) · [Son sürüm](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest)

> [!TIP]
> Bu rehber, Windows için önerilen ve en kolay yöntem olan **KZSC Hazırlayıcı** içindir. Terminal komutu yazmanız gerekmez.

## Gerekenler

- Windows 10/11 bilgisayar ile Keenetic router aynı yerel ağda olmalı.
- Router yönetici kullanıcı adı ve parolası gerekli.
- Router’ın internet bağlantısı çalışıyor olmalı.
- Yeni Entware kurulacaksa desteklenen dahili depolama ya da EXT2/EXT3/EXT4 biçimli USB bölümünü takın.

## 1 — Router’da SSH’ı açın

Keenetic web arayüzünde **Genel sistem ayarları → Bileşen seçenekleri** bölümünü açın. **SSH sunucusu** bileşenini kurun veya etkinleştirin. SSH yalnızca yerel ağdan erişilebilir kalsın.

Hazırlayıcıyı çalıştırmadan önce router’da yapılması gereken tek hazırlık budur.

## 2 — KZSC Hazırlayıcı’yı indirin ve açın

1. [Son sürüm](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest) sayfasını açın.
2. **Assets** bölümünden `KZSC-Hazirlayici-*.zip` dosyasını indirin.
3. ZIP dosyasına sağ tıklayıp **Tümünü ayıkla** seçeneğine basın.
4. Çıkardığınız klasörde `KZSC-Hazirlayici.exe` dosyasını çalıştırın.

> [!IMPORTANT]
> `KZSC-Hazirlayici.exe` ile `_internal` klasörü birlikte kalmalıdır. EXE dosyasını tek başına taşımayın.

## 3 — Bağlanın ve analiz edin

![KZSC Hazırlayıcı bağlantı ekranı](images/kzsc-hazirlayici-baslangic.png)

1. Dili seçin.
2. Bulunan router’ı seçin; bulunamazsa yerel IP adresini yazın (çoğu kurulumda `192.168.1.1`).
3. **KeeneticOS SSH (22)** bölümüne router yönetici bilgilerini girin.
4. **Bağlan ve cihazı analiz et** düğmesine basın.
5. SSH anahtar parmak izini yalnız kendi router’ınıza ait olduğundan eminseniz onaylayın.

Uygulama router’ı değiştirmeden önce denetler. Parolalar diske kaydedilmez.

## 4 — Depolamayı seçin ve plan oluşturun

![KZSC Hazırlayıcı kurulum seçenekleri](images/kzsc-hazirlayici-kurulum-secenekleri.png)

Uygulamada görünen uygun hedefi seçin:

- **Mevcut Entware /opt**: çalışan Entware kurulumunu korur.
- **USB bölümü**: yalnız algılanan EXT2/EXT3/EXT4 bölümler gösterilir.
- **Dahili depolama**: yalnız uyumlu router’larda görünür.

**KZSC’nin son sürümünü otomatik kur** seçeneğini açık bırakın. Ardından **Plan ve kurulum** bölümünü açın ve **Kurulum planını oluştur** seçeneğine basın.

## 5 — Planı uygulayın

![KZSC Hazırlayıcı plan ekranı](images/kzsc-hazirlayici-plan.png)

Router ve depolama hedefi doğruysa **Planı uygula** düğmesine basın.

Hazırlayıcı yalnız eksik parçaları kurar; KeeneticOS bileşenleri değişecekse router yeniden başlayabilir. Ardından KZSC’yi kurar ve doğrular. Plan çalışırken router’ın elektriğini kesmeyin, uygulamayı kapatmayın.

## 6 — KZSC’yi açın

Plan tamamlandığında yerel ağdan şu adresi açın:

```text
http://ROUTER_IP:9090/
```

Örnek: `http://192.168.1.1:9090/`

![KZSC genel bakış](images/kzsc-genel-bakis.png)

**Genel Bakış** sayfasında KZSC ve WAN’ların sağlıklı olduğunu kontrol edin. Sonrasında Zapret2/DPI, DNS ve cihaz ayarlarını yapabilirsiniz.

## Sık sorulanlar

### Router bulunamadı

Bilgisayarın ana yerel ağda olduğundan emin olun. VPN istemcisini geçici kapatın, sonra router’ın yerel IP adresini elle yazın. Misafir Wi‑Fi router yönetimine erişimi engelleyebilir.

### SSH 22 bağlanmıyor

KeeneticOS **SSH sunucusu** bileşeninin açık olduğunu, yönetici bilgilerinin doğru olduğunu ve yerel SSH portunun 22 olduğunu kontrol edin. SSH’ı internete açmayın.

### USB listede yok

Hazırlayıcı diski biçimlendirmez. Bölümün EXT2, EXT3 veya EXT4 olduğundan ve KeeneticOS tarafından bağlı göründüğünden emin olun.

### Panel açılmıyor

Yerel ağdan `http://ROUTER_IP:9090/` adresini kullanın. Paneli doğrudan internete açmayın. Kurulum raporunda hata varsa gizli bilgiler maskelenmiş günlüğü kaydedin; parola veya token paylaşmadan issue açın.

## Manuel alternatif

Yalnız Windows Hazırlayıcı kullanılamıyorsa uygulayın:

![Kalıcı Entware /opt hazırlama akışı](images/entware-opt-akisi.svg)

### A. Kalıcı `/opt` hedefini hazırlayın

1. Keenetic web arayüzünde **Genel sistem ayarları → Bileşen seçenekleri** bölümünü açın.
2. **Open Package support (OPKG)** bileşenini kurun. Aynı ekranda **SSH sunucusu** da etkin olmalı.
3. **Uygulamalar / Open Package** (bazı modellerde **Depolama**) ekranında hedef olarak bağlı USB bölümünü veya desteklenen dahili depolamayı seçin.
4. USB kullanıyorsanız bölüm **EXT2, EXT3 veya EXT4** olmalı; tercihen EXT4 kullanın. Hazırlayıcı diski biçimlendirmez.
5. **Uygula** düğmesine basın ve KeeneticOS’un işlemi tamamlamasını bekleyin. Router yeniden başlarsa tamamen açılmasını bekleyin.
6. Aynı depolama ekranında bölümün **bağlı/mounted** ve OPKG hedefinin **aktif** göründüğünü kontrol edin.

![Hazırlayıcıda görünen depolama hedefleri](images/kzsc-hazirlayici-kurulum-secenekleri.png)

> Bu ekran görüntüsü Hazırlayıcı’daki karşılığı gösterir: çalışan bir `/opt` varsa **Mevcut Entware /opt**, yeni taban kurulacaksa algılanan USB veya dahili depolama seçilir.

### B. SSH 222’yi doğrulayın

Entware hedefi bağlıyken bilgisayardan router’a **SSH 222** ile bağlanın. Windows PowerShell veya macOS Terminal’de:

```sh
ssh -p 222 root@ROUTER_IP
```

Yeni Entware kurulumunda ilk parola bazı Keenetic kurulumlarında `keenetic` olabilir; mevcut kurulumda kendi Entware root parolanızı kullanın. Parolayı değiştirmeden internete açık SSH kullanmayın.

Router SSH oturumunda şu dört komutu çalıştırın:

```sh
test -x /opt/bin/opkg && echo 'OK: opkg'
test -x /opt/bin/sh && echo 'OK: Entware shell'
test -x /opt/etc/init.d/rc.unslung && echo 'OK: Entware startup'
opkg update
```

İlk üç komutun her biri `OK` yazmalı; `opkg update` hata vermeden paket listelerini indirmeli. Herhangi biri başarısızsa `/opt` kalıcı değildir veya SSH 222 hazır değildir: kuruluma geçmeyin, depolama hedefini düzeltip router’ı yeniden başlatın ve tekrar kontrol edin.

### C. KZSC arşivini yükleyip kurun

![Manuel yükleme ve PuTTY akışı](images/manual-upload-putty-akisi.svg)

#### 1) Dosyaları bilgisayara indirin

1. [Son sürüm](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest) sayfasını açın.
2. **Assets** altında adı `keenetic-zapret-smart-control-v...-generic.tar.gz` olan router arşivini ve **aynı ada** sahip `.sha256` dosyasını indirin. İki dosya aynı klasörde dursun.
3. Arşivi açmayın ve dosya adlarını değiştirmeyin. `.sha256` dosyası arşivin bütünlük kontrolü içindir.

#### 2) Grafik arayüzle `/opt/tmp` klasörüne yükleyin (WinSCP)

Windows’ta [WinSCP’yi resmi sitesinden indirin](https://winscp.net/eng/download.php) ve kurun. WinSCP, komut yazmadan dosya sürükleyip bırakabileceğiniz güvenli SFTP arayüzüdür.

![WinSCP alanları ve dosya yönü](images/manual-winscp-putty-ekran.svg)

1. WinSCP’yi açın; **File protocol: SFTP**, **Host name: ROUTER_IP**, **Port number: 222**, **User name: root** girin.
2. **Login** düğmesine basın. İlk bağlantıda görünen anahtar parmak izini yalnız kendi router’ınıza aitse **Accept** ile onaylayın.
3. Sol panel bilgisayarı, sağ panel router’ı gösterir. Sağ panelde `/opt/tmp` klasörünü açın. Klasör yoksa PuTTY ile bağlandıktan sonra `mkdir -p /opt/tmp` komutunu çalıştırın.
4. Sol panelden indirdiğiniz `.tar.gz` ve `.sha256` dosyalarını sağdaki `/opt/tmp` paneline sürükleyin. Kopyalama bitmeden WinSCP’yi kapatmayın.

> **Güvenlik:** WinSCP’de port **222** seçilmelidir; KeeneticOS yönetim SSH’ı olan port **22** ile karıştırmayın. SSH/SFTP’yi yalnızca yerel ağda kullanın.

#### 3) PuTTY ile SSH 222’ye bağlanın

[PuTTY’nin resmi indirme sayfasını açın](https://www.putty.org/), Windows için **MSI installer** sürümünü indirip kurun.

Yukarıdaki görselin sağ tarafı, doldurulacak PuTTY alanlarını gösterir: IP adresi, `222` portu ve **SSH**.

1. PuTTY’yi açın ve **Session** ekranında **Host Name (or IP address)** alanına router’ın yerel IP’sini (`192.168.1.1` gibi) yazın.
2. **Port** alanına `222`, bağlantı türüne **SSH** seçin ve **Open** düğmesine basın.
3. İlk bağlantıda güvenlik uyarısı gelirse parmak izi kendi router’ınıza aitse **Accept** seçin.
4. Terminalde `login as:` sorusuna `root`, parola sorusuna Entware root parolanızı yazın. Yazarken parola ekranda görünmez; bu normaldir.

Bağlantı başarılıysa komut satırı açılır. Bağlanamıyorsanız PuTTY’de portun `222`, router IP’sinin doğru ve OPKG/SSH bileşenlerinin etkin olduğunu tekrar kontrol edin.

#### 4) Router’da doğrulayıp kurun

```sh
cd /opt/tmp
sha256sum -c keenetic-zapret-smart-control-v*-generic.tar.gz.sha256
tar -xzf keenetic-zapret-smart-control-v*-generic.tar.gz
cd keenetic-zapret-smart-control-v*-generic
/opt/bin/sh install.sh
```

Kurucu router’ın gerçek yeteneklerini denetler; desteklenmeyen kurulumlarda güvenli biçimde durur.
