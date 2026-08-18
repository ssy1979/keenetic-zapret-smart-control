# KZSC v0.11.2.30-generic

## Türkçe

- DPI motoru başlamadan önce eksik `xt_multiport` ve `xt_connbytes` modüllerini otomatik yükler; gerçek multiport/connbytes/NFQUEUE çalışma testi yapar.
- Zapret2 Lua dosyalarının servis kullanıcısı tarafından okunabilmesini otomatik sağlar; böylece motorun başlatılıp hemen durması önlenir.
- Sol Fiber ve TT Fiber bağlantıları için DPI profil önerileri eklendi; profil seçimi arayüzde anında kaydedilir.
- Router yeniden başladıktan sonra eski Blockcheck işleri ve sayaçları güvenli biçimde temizlenir.
- KZSC v0.11.2.30-generic için iki dilli sürüm ve kurulum belgeleri güncellendi.

## English

- Automatically loads missing `xt_multiport` and `xt_connbytes` modules before starting DPI and performs a real multiport/connbytes/NFQUEUE runtime probe.
- Ensures Zapret2 Lua files are readable by the service account, preventing engines from starting and immediately stopping.
- Adds DPI profile recommendations for Sol Fiber and TT Fiber; profile selection is saved immediately in the UI.
- Safely reconciles stale Blockcheck jobs and counters after a router reboot.
- Updates bilingual release and installation documentation for KZSC v0.11.2.30-generic.
