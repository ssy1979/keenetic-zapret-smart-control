# KZSC v0.11.2.61-generic

## Türkçe

- Otomatik DPI modunda hostlist ve otomatik öğrenme seçenekleri doğru filtre profili içinde oluşturulur; `nfqws2` doğrulama hatası giderildi.
- Blockcheck hazır profilleri denerken her aday değişikliğinden sonra çalışan DPI motoru yeniden yapılandırılır. Böylece sonraki adaylar önceki profilin süreciyle test edilmez.
- Motorlar başlangıçta kapalı olsa bile hazır profil doğrulaması doğru profili seçer; doğrulama başarısızsa mevcut motor durumu korunur.

## English

- Automatic DPI mode now places hostlist and auto-learning options inside the correct filter profile, fixing `nfqws2` validation failures.
- Blockcheck reconfigures the running DPI engine after each candidate profile change, so later candidates are tested with their own arguments instead of the first profile's process.
- Preset-first validation works correctly when engines start disabled and preserves the original engine state when probing finishes.
