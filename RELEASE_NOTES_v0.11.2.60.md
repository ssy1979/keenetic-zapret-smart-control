# KZSC v0.11.2.60-generic

## Türkçe

- Sıfır kurulumda Blockcheck, ISS adına göre karar vermeden tüm hazır DPI profillerini gerçek HTTP ve HTTPS erişimiyle dener.
- Hedeflerin tamamında çalışan profil otomatik kaydedilir; hiçbir profil geçmezse normal Blockcheck taraması başlar.
- Çok hızlı tamamlanan hazır-profil testleri artık yanlışlıkla “Blockcheck worker başlatılamadı” hatası göstermez.
- Otomatik çalışma modunda Zapret ile erişilen/öğrenilen alan adları arayüzde görünür; tek tek silinebilir veya elle eklenebilir.
- Otomatik modun hostlist parametreleri, Zapret2'nin desteklediği global/profil sırasına alındı. DPI motorları artık otomatik modda da başlatılabilir.
- Çalışma modu değiştirilirken DPI motorunun etkin durumu korunur. Yeni mod uygulanamazsa eski mod ve çalışan motor geri yüklenir.

## English

- On a fresh installation, Blockcheck tries each bundled DPI profile against real HTTP and HTTPS connectivity instead of deciding from the ISP name.
- A profile that works for every target is saved automatically; the regular Blockcheck scan starts only when none succeeds.
- Fast preset checks no longer produce a false “Blockcheck worker failed to start” notice after a successful result.
- In automatic mode, domains accessed/learned through Zapret are visible in the UI; they can be removed individually or added manually.
- Automatic-mode hostlist parameters now use the Zapret2-supported global/profile order, so DPI engines can start in automatic mode.
- DPI enabled state is preserved while switching modes. If the new mode cannot be applied, the prior mode and working engine are restored.
