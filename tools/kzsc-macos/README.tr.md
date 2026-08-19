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
- Doğrulanmış paketi `~/Downloads/KZSC` klasörüne indirme;
- Router parolasını kaydetmeden Entware yükleme komutu hazırlama;
- Yeniden başlatma sonrası `kzsc status`, `kzsc preflight` ve `kzsc audit full`
  kontrollerini yapma;
- Mevcut KZSC panelini WAN, DPI, DNS, Zapret2, Blockcheck, Telegram, güncelleme
  ve ayarlarla birlikte `WKWebView` içinde açma.

Kurulum akışı SSH parolasını yalnızca Terminal'in etkileşimli istemine bırakır.
Parola komut satırına, günlüğe, tercihlere veya arşive yazılmaz. Uygulama
gizli bir parola istemi çalıştırmaz ve router üzerinde kendiliğinden servis
oluşturmaz.

## Derleme

macOS 13 veya daha yeni bir sistemde bu klasörü Xcode ile açıp `KZSCMacOS`
şemasını çalıştırın. Windows ortamında Xcode/SwiftUI çalıştırılamadığı için
burada yalnızca kaynak doğrulaması yapılabilir. GitHub yayını ayrıca onay
verilmeden yapılmaz.
