# KZSC v0.11.2.23-generic

## Türkçe

- **Çalışma Modu alan adı girişi düzeltildi.** Otomatik ve Zapret dışında bırakılacak alan adı kutularındaki yazı, periyodik arayüz yenilemelerinde artık silinmez. Odak ve imleç konumu korunur; başarılı kayıt sonrasında yalnız ilgili kutu temizlenir.
- **Audit yanlış hataları giderildi.** KZSC ve router yeniden başlatma akışları güncel `ACTION` tabanlı bakım kuyruğuna göre denetlenir. Sabit yollardan güvenli `ndmc` keşfi ve güncel `dpi_policy.cgi` / `refresh.cgi` uç noktaları allow-list kapsamındadır.
- Kaldırılmış Olay Günlüğü sekmesine ait eski test yerine görünür arayüzün çift dilli mesaj ve yerel tarih yardımcıları doğrulanır.
- Cihaz bazlı Zapret istisnası iki bağımsız WAN üzerinde canlı olarak doğrulandı: her iki NFQUEUE giriş/çıkış zincirinde ve gerekli TCP-only QUIC zincirinde cihaz IP'si için `RETURN` kuralları bulunur.
- KZSC Hazırlayıcı **1.2.6** aynı doğrulanmış WAN ayrıştırma ve yeniden bağlantı düzeltmeleriyle birlikte yayımlanır.

## English

- **Operating Mode domain input is fixed.** Text entered into automatic and Zapret-exclusion domain fields now survives periodic UI refreshes. Focus and caret position are preserved, and only the submitted field is cleared after a successful save.
- **False audit failures are removed.** KZSC and router restart checks now follow the current `ACTION`-based maintenance queue. Fixed-path `ndmc` discovery and the current `dpi_policy.cgi` / `refresh.cgi` endpoints are included in the audit contract.
- The obsolete Event Log panel assertion is replaced with validation of the visible UI's bilingual message and localized-date helpers.
- Per-device Zapret bypass was validated live across two independent WANs, including inbound/outbound NFQUEUE chains and the applicable TCP-only QUIC chain.
- KZSC Preparer **1.2.6** is published unchanged with its previously validated WAN parsing and reconnect fixes.
