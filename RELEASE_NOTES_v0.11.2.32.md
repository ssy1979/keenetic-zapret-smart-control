# KZSC v0.11.2.32-generic

## Türkçe

- v0.11.2.31 güncellemesinin purity denetimi nedeniyle geri alınmasına yol açan preset kimliği hatası düzeltildi.
- DPI presetleri nötr dahili kimliklerle sunulur; arayüzde KZM2 öneki gösterilmez.
- Eski `tt.conf` ve `sol.conf` dosyaları kurulum sırasında temizlenir.
- KABLONET korunur; Türk Telekom Fiber, Superonline Fiber ve Vodafone türevleri güncel preset kataloğuyla gelir.
- Blockcheck, güncel presetleri geniş taramadan önce kontrol etmeye devam eder.
- İngilizce/Türkçe sürüm notları ve kurulum doğrulamaları güncellendi.

## English

- Fixes the preset-identifier purity check that caused the v0.11.2.31 update to roll back.
- Ships DPI presets with neutral internal identifiers; the KZM2 prefix is not shown in the UI.
- Removes legacy `tt.conf` and `sol.conf` files during installation.
- Keeps Kablonet and includes the current Türk Telekom Fiber, Superonline Fiber, and Vodafone variants.
- Blockcheck continues to test the current presets before broad scanning.
- Updates bilingual release notes and installation validation.
