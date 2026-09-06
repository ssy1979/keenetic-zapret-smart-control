# KZSC v0.11.2.63-generic

## Türkçe

- DPI profilleri KZM2 v26.9.2 (commit `b9fc3f7c18b2f5f8978f16488ad9125a7b161455`) ile güncellendi; profil kimlikleri KZSC uyumluluğu için korunmuştur.
- Superonline için TTL6/hostcase, Türk Telekom için TTL2 sahte TLS ve QUIC stratejileri dahil güncel profil aileleri eklendi.
- Blockcheck artık önce en kısa KZM2-türevi strateji ailesini ve yalnızca HTTPS hedef testini dener; ISP adına göre varsayım yapmaz.
- Sabit 30 dakikalık Blockcheck duvar saati sınırı kaldırıldı. İşlem, upstream testleri bitene veya kullanıcı Durdur düğmesine basana kadar devam eder.
- Kayıtlı profili olan ve hedefi gerçekten açılan WAN'larda uzun tarama başlatılmaz. Superonline'da seçilen hedef erişilemiyorsa tarama yapılması beklenen davranıştır; erişilen bir hedef girilmelidir.

## English

- DPI profiles were synchronized with KZM2 v26.9.2 (commit `b9fc3f7c18b2f5f8978f16488ad9125a7b161455`); KZSC profile IDs remain stable.
- Updated profile families include Superonline TTL6/hostcase and Türk Telekom TTL2 fake-TLS/QUIC strategies.
- Blockcheck first probes the shortest KZM2-derived strategy family using HTTPS-only target checks; it does not rely on ISP-name guesses.
- The fixed 30-minute Blockcheck wall-clock limit has been removed. A job runs until upstream tests finish or the user presses Stop.
- A WAN with a saved profile skips the long scan only when the configured target is actually reachable. If the target itself is unreachable on Superonline, scanning is expected; choose a reachable target.
