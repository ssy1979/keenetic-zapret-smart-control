# KZSC v0.11.2.40-generic

## Türkçe

- KZSC arka plan işlemleri iki güvenli döngüye ayrıldı: WAN/DPI toparlama hızlı kalırken, yoğun cihaz envanteri ve arayüz yenilemeleri 60 saniyelik aralığa alındı. Bu değişiklik Keenetic `ndmc` oturum yoğunluğunu ve işlemci yükünü azaltır.
- Zapret2 sekmesine küresel **Zapret2'yi Durdur** ve **Zapret2'yi Başlat** denetimleri eklendi. Durdurma WAN profillerini korur; başlatma tüm etkin WAN motorlarını yeniden doğrular.
- IPv6 Zapret2 etkinleştirmesi artık seçili WAN üzerinden gerçek IPv6 HTTPS bağlantısıyla doğrulanır. Doğrulama başarısız olursa kurallar güvenli şekilde geri alınır; internet erişimi için yarım kalmış IPv6 yönlendirmesi bırakılmaz.
- Windows ve macOS hazırlayıcı paketleri ortak Keenetic uygulama simgesini kullanır. macOS paketi GitHub sürüm varlığı olarak hazırlanır; ad-hoc imzalıdır ve notarize edilmemiştir.
- macOS hazırlayıcısı doğrudan kurulumda bağlantı, Entware hazırlığı, SSH 222 bekleme, arşiv yükleme ve router kurucusu aşamalarını canlı gösterir. SSH bağlantıları sınırlı zaman aşımıyla sonlanır; panel henüz hazır değilse durum açıkça bildirilir.

### macOS bilinen sınırlama

- macOS hazırlayıcısı yayımlanmıştır ancak erken geri bildirim aşamasındadır. Bazı router'larda doğru parola girilse dahi SSH 222 parola doğrulaması başarısız olabilir. Bu durumda Windows Hazırlayıcı veya mevcut SSH kurulumu kullanılabilir; bu uyumluluk sorunu sonraki güncellemede ele alınacaktır.
- IPv6 canlı trafik testi başarısız olduğunda Zapret2 artık tüm motorları durdurmak yerine IPv6'yı güvenli şekilde devre dışı bırakıp IPv4 DPI motorlarını yeniden başlatır.
- Türkçe ve İngilizce kurulum rehberleri macOS hazırlayıcı akışıyla güncellendi.

## English

- KZSC background work is split into two safe loops: WAN/DPI recovery remains fast while expensive client inventory and UI refresh work runs every 60 seconds. This reduces Keenetic `ndmc` session churn and CPU load.
- The Zapret2 tab now includes global **Stop Zapret2** and **Start Zapret2** controls. Stopping preserves WAN profiles; starting revalidates every enabled WAN engine.
- IPv6 Zapret2 activation now verifies real IPv6 HTTPS connectivity through the selected WAN. If validation fails, rules are safely rolled back so no partial IPv6 redirection remains to disrupt internet access.
- Windows and macOS preparer packages use the shared Keenetic app icon. The macOS package is built as a GitHub release asset; it is ad-hoc signed and not notarized.
- During direct installation, the macOS preparer now reports connection, Entware bootstrap, SSH 222 wait, archive upload, and router-installer phases live. SSH connections use bounded timeouts and the app clearly reports when the panel is not ready yet.

### Known macOS limitation

- The macOS preparer is published but remains in an early-feedback stage. On some routers, SSH 222 password authentication can reject a correct password. In that case, use the Windows Preparer or the existing SSH installation path; this compatibility issue will be addressed in a subsequent update.
- If the IPv6 live-traffic probe fails, Zapret2 now safely disables IPv6 and restarts the IPv4 DPI engines instead of leaving all engines stopped.
- Turkish and English installation guides now include the macOS preparer flow.
