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

### A. Kalıcı `/opt` hedefini hazırlayın

Bu bölümde yalnızca KeeneticOS’un kendi web arayüzü kullanılır. Bilgisayarınızı router’ın yerel ağına bağlayın ve tarayıcıda `http://my.keenetic.net` veya router IP’sini (`http://192.168.1.1` gibi) açın.

1. **Yönetim → Genel sistem ayarları → Bileşen seçenekleri** yolunu açın.
2. **Open Package support (OPKG)** bileşenini kurun. Aynı yerde **SSH sunucusu** bileşeni de kurulu ve etkin olmalıdır.

![KeeneticOS bileşen seçeneklerinde OPKG kurulumu](https://support.keenetic.com/asset/images/uuid-3a0506eb-881c-a993-eef9-c1bacce647c9.png)

3. EXT4 tercih edilen USB diski router’a takın. Disk **Depolamalar ve cihazlar** ekranında; eski arayüzlerde **Uygulamalar → USB aygıtları** altında görünmelidir.
4. **Uygulamalar → OPKG Paket Yöneticisi** sayfasını açın. **Sürücü / Drive** alanında bu USB bölümü seçiliyken OPKG erişim iznini etkinleştirip **Kaydet/Uygula** düğmesine basın.

![KeeneticOS bağlı USB depolama görünümü](https://support.keenetic.com/asset/images/uuid-214a480a-7b40-9a66-7523-9f68cbbeb167.jpg)

![KeeneticOS OPKG sayfasında sürücü seçimi](https://support.keenetic.com/asset/images/uuid-8a297160-bd75-8450-49bf-c08bf74c7e73.png)

5. İşlem bittiğinde seçilen USB bölümünün bağlı göründüğünü doğrulayın. OPKG bu bölümü kalıcı olarak `/opt` konumuna bağlar. Router yeniden başlarsa tamamen açılmasını bekleyin.

> [!IMPORTANT]
> USB diski yalnızca güvenli kaldırma yaptıktan sonra çıkarın. Disk çıkarılırsa `/opt` ve KZSC çalışmaz; diski yeniden takıp router’ın tanımasını bekleyin.

### B. SSH 222’yi doğrulayın

Entware hedefi bağlıyken bilgisayardan router’a **SSH 222** ile bağlanın. Windows kullanıyorsanız [PuTTY’nin resmi indirme sayfasından](https://www.putty.org/) Windows MSI yükleyicisini indirip kurun.

PuTTY’de **Host Name** alanına router IP’sini, **Port** alanına `222` yazın; **SSH** seçiliyken **Open** düğmesine basın. İlk bağlantıda parmak izini yalnızca kendi router’ınıza aitse onaylayın.

Giriş ekranında varsayılan Entware bilgileri şunlardır:

```text
login as: root
password: keenetic
```

Parolayı yazarken ekranda karakter görünmez; bu normaldir. Daha önce Entware parolasını değiştirdiyseniz kendi parolanızı kullanın. SSH’ı internete açmayın.

Router SSH oturumunda şu dört komutu çalıştırın:

```sh
test -x /opt/bin/opkg && echo 'OK: opkg'
test -x /opt/bin/sh && echo 'OK: Entware shell'
test -x /opt/etc/init.d/rc.unslung && echo 'OK: Entware startup'
opkg update
```

İlk üç komutun her biri `OK` yazmalı; `opkg update` hata vermeden paket listelerini indirmeli. Herhangi biri başarısızsa `/opt` kalıcı değildir veya SSH 222 hazır değildir: kuruluma geçmeyin, depolama hedefini düzeltip router’ı yeniden başlatın ve tekrar kontrol edin.

### C. KZSC arşivini yükleyip kurun

#### 1) Dosyaları bilgisayara indirin

1. [Son sürüm](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest) sayfasını açın.
2. **Assets** altında adı `keenetic-zapret-smart-control-v...-generic.tar.gz` olan router arşivini ve **aynı ada** sahip `.sha256` dosyasını indirin. İki dosya aynı klasörde dursun.
3. Arşivi açmayın ve dosya adlarını değiştirmeyin. `.sha256` dosyası arşivin bütünlük kontrolü içindir.

#### 2) Keenetic arayüzünden `/opt/tmp` klasörüne yükleyin

OPKG’nin bağlı olduğu diskin kökü router’da `/opt` olarak görünür. Dolayısıyla KeeneticOS dosya yöneticisinde oluşturacağınız `tmp` klasörü, komut satırında `/opt/tmp` olacaktır.

1. Keenetic arayüzünde **Uygulamalar** sayfasını açın.
2. Bağlı USB disk satırına tıklayın. KeeneticOS’un yerleşik dosya yöneticisi açılır.
3. Disk kökünde **Yeni klasör** simgesiyle `tmp` adlı klasörü oluşturun ve içine girin.
4. **Dosya yükle** simgesine basın; indirdiğiniz `.tar.gz` ve `.sha256` dosyalarını birlikte seçip yükleme tamamlanana kadar bekleyin.

![KeeneticOS yerleşik USB dosya yöneticisi](https://support.keenetic.com/asset/images/uuid-b7f23f41-a232-db0b-1dd8-45677a0a1425.png)

Yükleme bittiğinde `tmp` klasöründe **iki dosya** görünmelidir: router arşivi ve aynı ada sahip `.sha256` dosyası. Dosyalardan biri eksikse veya adını değiştirdiyseniz sonraki adıma geçmeyin.

#### 3) Router’da doğrulayıp kurun

```sh
cd /opt/tmp
sha256sum -c keenetic-zapret-smart-control-v*-generic.tar.gz.sha256
tar -xzf keenetic-zapret-smart-control-v*-generic.tar.gz
cd keenetic-zapret-smart-control-v*-generic
/opt/bin/sh install.sh
```

Kurucu router’ın gerçek yeteneklerini denetler; desteklenmeyen kurulumlarda güvenli biçimde durur.
