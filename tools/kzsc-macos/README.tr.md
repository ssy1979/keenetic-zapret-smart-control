# KZSC macOS

Bu klasör, KZSC için yerel SwiftUI/macOS uygulaması geliştirme alanıdır.
Yönlendirici kodundan ayrı tutulur.

> **Test durumu:** macOS uygulaması şu anda erken test sürümündedir. Henüz
> desteklenen üretim sürümü değildir. Router kurulumu veya kontrolü için
> kullanmadan önce macOS üzerinde Xcode ile derlenip doğrulanmalıdır.

## Kapsam

- Yerel `/24` ağında Keenetic cihazlarını bulma;
- SSH 222 ED25519 SHA-256 parmak izini doğrulama;
- Güvenilir KZSC GitHub sürümünü ve SHA-256 dosyasını doğrulama;
- Kurulum başladığında paketi yalnızca geçici dizine indirip doğrulama (ayrı
  bir manuel indirme adımı gösterilmez);
- SSH 222 henüz yoksa Keenetic SSH 22 üzerinden Entware'ı kontrol edip
  hazırlama ve router parolalarını kaydetmeden KZSC'yi doğrudan kurma;
- Yeniden başlatma sonrası `kzsc status`, `kzsc preflight` ve `kzsc audit full`
  kontrollerini yapma;
- Mevcut KZSC panelini WAN, DPI, DNS, Zapret2, Blockcheck, Telegram, güncelleme
  ve ayarlarla birlikte `WKWebView` içinde açma.

Kurulum akışı macOS OpenSSH araçlarını uygulamanın içinde çalıştırır. SSH 222
henüz hazır değilse Keenetic SSH 22 yönetici parolası Entware hazırlığı için,
web panelinde kullandığınız aynı parola olarak girilir. Yeni Entware
kurulumlarında root/`keenetic` varsayılandır; özel Entware parolası belirlediyseniz
bu alanı değiştirin. Hiçbir parola komut satırına, günlüğe, tercihlere veya arşive
yazılmaz. Uygulama ED25519 anahtarını doğrular, en son GitHub sürümünü alır,
eksik bileşenleri kurar veya sıraya alır, gerekirse yeniden başlatmayı bekler
ve panel erişimini kontrol eder.

## Derleme

macOS 13 veya daha yeni bir sistemde bu klasörü Xcode ile açıp `KZSCMacOS`
şemasını çalıştırın. Windows ortamında Xcode/SwiftUI çalıştırılamadığı için
burada yalnızca kaynak doğrulaması yapılabilir. GitHub yayını ayrıca onay
verilmeden yapılmaz.

Repository içinde ayrıca **KZSC macOS test uygulaması** iş akışı bulunur. Bu
iş akışı GitHub macOS runner'ında imzasız/ad-hoc imzalı `KZSCMacOS.app`
paketini derler ve ZIP ile SHA-256 dosyasını Actions artifact olarak yükler.
En son artifact'i indirip ZIP'i açın; Gatekeeper onay isterse sağ tıklayıp
**Aç** seçeneğini kullanın. Bu paket yalnızca geri bildirim içindir; notarize
edilmemiştir ve üretim sürümü değildir.
