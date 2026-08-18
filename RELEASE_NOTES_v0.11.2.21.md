# KZSC v0.11.2.21-generic

## Türkçe

- Yeni DPI politika CGI'sının kurulum sırasında eski elle tutulan izin listesi tarafından silinmesi düzeltildi. Cihaz bazında Zapret ve Keenetic IP rezervasyonu istekleri artık gerçek JSON uç noktasına ulaşır; kurucu paketteki tüm backend/CGI dosyalarını kaynak ağacından doğrular.
- Cihazlar ekranı “Mevcut IP”, “Zapret Erişimi”, “Keenetic IP Rezervasyonu” ve “WAN DPI Profili” olarak ayrıştırıldı. Mevcut IP artık yanlışlıkla kayıtlı statik IP gibi gösterilmez; rezervasyon durumu ve açık onay ayrı sunulur.
- Arayüz, CGI bulunamadığında HTML hata sayfasını JSON sanmak yerine Türkçe/İngilizce anlaşılır onarım mesajı gösterir.
- KZSC Hazırlayıcı v1.2.5, uzun Entware beklemelerinde kapanan Keenetic SSH 22 oturumunu güvenle yeniden kurar; rc.unslung ve Dropbear/SSH 222 için sınırlı otomatik kurtarma uygular.
- Keenetic CLI'nin `\xHH` biçimindeki Türkçe UTF-8 bağlantı adları güvenli biçimde çözülür. Canlı ve yapılandırılmış WAN kaynakları arayüz kimliğine göre birleştirilir; “Broadband connection” yerine “VODAFONE FİBER” gibi gerçek sağlayıcı adı korunur.
- CGI POST/JSON/kuyruk akışı, cihaz politikası arayüzü, 1–4 WAN ve Hazırlayıcı WAN/SSH senaryoları için regresyon kapsamı genişletildi.

## English

- Fixed the installer deleting the new DPI policy CGI through a stale hand-maintained allowlist. Per-device Zapret and Keenetic IP-reservation requests now reach the JSON endpoint, and installation verifies every packaged backend/CGI file from the source tree.
- Clarified the Devices table with separate Current IP, Zapret Access, Keenetic IP Reservation, and WAN DPI Profile areas. A current address no longer appears to be an existing reservation; saved state and explicit confirmation are shown separately.
- The UI now reports a clear bilingual repair message when the CGI is missing instead of parsing an HTML error page as JSON.
- KZSC Preparer v1.2.5 reconnects a Keenetic SSH 22 session closed during long Entware waits and performs bounded rc.unslung and Dropbear/SSH 222 recovery.
- Safely decodes Turkish UTF-8 WAN labels emitted as `\xHH` by the Keenetic CLI. Live and configured WAN sources are merged by interface ID, preserving provider names such as “VODAFONE FİBER” over “Broadband connection”.
- Expanded regression coverage for CGI POST/JSON/queue behavior, the device-policy UI, 1–4 WAN topologies, and Preparer WAN/SSH recovery.
