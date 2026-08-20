# KZSC v0.11.2.43

## Türkçe

- macOS uygulaması ve ilgili GitHub Actions/release varlıkları kaldırıldı.
- macOS ve Windows için Entware + SSH üzerinden manuel kurulum rehberleri eklendi.
- Kaynak sahipliği/purity denetimi tamamen kaldırıldı; bu denetim artık güncellemeyi geri aldırmaz.
- IPv6 olmayan WAN'larda IPv6 etkinleştirme artık hata üretmez; IPv6 otomatik olarak IPv4-only moda düşer ve DPI motorları çalışır.
- IPv6 destekli WAN'larda per-WAN IPv6 davranışı korunur.

## English

- Removed the macOS application and its GitHub Actions/release assets.
- Added manual Entware + SSH installation guides for macOS and Windows.
- Removed the source-ownership/purity checker completely; it can no longer trigger an update rollback.
- Enabling IPv6 on WANs without IPv6 now succeeds as a safe IPv4-only fallback, keeping DPI engines running.
- Per-WAN IPv6 behavior remains available on IPv6-capable connections.
