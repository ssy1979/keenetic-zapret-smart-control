# KZSC v0.11.2.31-generic

## Türkçe

- DNS sağlayıcısı seçildiğinde varsayılan protokol artık DoT + DoH birlikte uygulanır.
- DNS ekranındaki protokol seçimi temiz ve anlaşılır biçimde “Her ikisi / Both” seçeneğini öne çıkarır.
- DPI profili seçiminde kullanıcı seçimi, “Profili Kaydet” düğmesine basılana kadar korunur; erken otomatik yenileme kaldırıldı.
- DNS ve DPI arayüz davranışları için regresyon testleri doğrulandı.

## English

- Selecting a DNS provider now defaults to applying both DoT and DoH together.
- The DNS UI clearly prioritizes the “Both” protocol option.
- DPI profile selections remain unchanged until the user presses “Save Profile”; premature auto-refresh was removed.
- DNS and DPI UI behavior was covered by regression validation.
