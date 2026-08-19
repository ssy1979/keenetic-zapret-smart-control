# KZSC v0.11.2.39-generic

## Türkçe

- KZSC arka plan işlemleri iki güvenli döngüye ayrıldı: WAN/DPI toparlama hızlı kalırken, yoğun cihaz envanteri ve arayüz yenilemeleri 60 saniyelik aralığa alındı. Bu değişiklik Keenetic `ndmc` oturum yoğunluğunu ve işlemci yükünü azaltır.
- Zapret2 sekmesine küresel **Zapret2'yi Durdur** ve **Zapret2'yi Başlat** denetimleri eklendi. Durdurma WAN profillerini korur; başlatma tüm etkin WAN motorlarını yeniden doğrular.
- IPv6 Zapret2 etkinleştirmesi artık seçili WAN üzerinden gerçek IPv6 HTTPS bağlantısıyla doğrulanır. Doğrulama başarısız olursa kurallar güvenli şekilde geri alınır; internet erişimi için yarım kalmış IPv6 yönlendirmesi bırakılmaz.
- Windows ve macOS hazırlayıcı paketleri ortak Keenetic uygulama simgesini kullanır. macOS paketi GitHub sürüm varlığı olarak hazırlanır; ad-hoc imzalıdır ve notarize edilmemiştir.
- Türkçe ve İngilizce kurulum rehberleri macOS hazırlayıcı akışıyla güncellendi.

## English

- KZSC background work is split into two safe loops: WAN/DPI recovery remains fast while expensive client inventory and UI refresh work runs every 60 seconds. This reduces Keenetic `ndmc` session churn and CPU load.
- The Zapret2 tab now includes global **Stop Zapret2** and **Start Zapret2** controls. Stopping preserves WAN profiles; starting revalidates every enabled WAN engine.
- IPv6 Zapret2 activation now verifies real IPv6 HTTPS connectivity through the selected WAN. If validation fails, rules are safely rolled back so no partial IPv6 redirection remains to disrupt internet access.
- Windows and macOS preparer packages use the shared Keenetic app icon. The macOS package is built as a GitHub release asset; it is ad-hoc signed and not notarized.
- Turkish and English installation guides now include the macOS preparer flow.
