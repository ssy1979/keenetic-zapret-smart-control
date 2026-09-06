# KZSC v0.11.2.62-generic

## Türkçe

- Blockcheck artık kayıtlı ve açık bir DPI profilini canlı ağ testi yapmadan başarılı saymaz.
- Hazır profil doğrulamasında tüm hedeflerin normal HTTPS erişimi başarı ölçütüdür. ISS'nin düz HTTP bağlantısını sıfırlaması, çalışan HTTPS profilini yanlışlıkla elemez.
- Düz HTTP ve HTTPS sonuçları ayrı kaydedilir; arayüzde HTTPS başarısı ve olası HTTP kısıtı açıkça gösterilir.
- Geniş tarama sırasında motorun trafikten geçici olarak ayrıldığı ve işlem sonunda önceki durumuna döndürüldüğü Türkçe ve İngilizce arayüzde belirtilir.

## English

- Blockcheck no longer trusts an enabled saved DPI profile without a live network probe.
- A ready preset is accepted when every configured target is reachable over normal HTTPS. An ISP resetting plain HTTP no longer rejects a working HTTPS profile.
- Plain HTTP and HTTPS outcomes are recorded separately, and the UI clearly reports HTTPS success and any HTTP limitation.
- The Turkish and English UI now explains that broad scanning temporarily detaches the engine from traffic and restores its previous state afterward.
