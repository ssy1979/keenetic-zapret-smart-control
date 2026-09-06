# KZSC v0.11.2.56-generic

## Türkçe

- WAN DPI profil adlarından “KZSC temel / baseline” ibareleri kaldırıldı.
- Blockcheck artık WAN için daha önce kaydedilmiş profili ilk sırada doğrular.
- Kayıtlı profil çalışıyorsa uzun genel tarama başlatılmaz; profil korunarak sonuç uygulanır.
- Kayıtlı profil başarısız olursa ISS önerisi ve diğer hazır profiller sırayla denenir.

## English

- Removed “KZSC temel / baseline” suffixes from WAN DPI profile labels.
- Blockcheck now validates the profile previously saved for each WAN first.
- When the saved profile works, the long broad scan is skipped and the working profile is preserved.
- If it fails, the ISP recommendation and remaining bundled profiles are tested in order.
