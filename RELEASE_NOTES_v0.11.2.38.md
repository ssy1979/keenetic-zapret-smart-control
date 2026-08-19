# KZSC v0.11.2.38-generic

## Türkçe

- DPI motorlarında eski veya yeniden kullanılan PID'lerin geçerli motor sanılmasını engeller.
- WAN geçişlerinde ve motor yeniden başlatmalarında gerçek nfqws2 süreci doğrulanır.
- CRLF biçimli yerleşik DPI presetleri doğru okunur ve tüm presetler arayüzde görünür.
- Preset yenileme ve profil işlemleri sonrası motor durumu güvenilir biçimde güncellenir.

## English

- Prevents stale or reused PIDs from being mistaken for a live DPI engine.
- Validates the actual nfqws2 process during WAN transitions and engine restarts.
- Parses CRLF-formatted built-in DPI presets correctly so the complete catalog appears in the UI.
- Refreshes authoritative engine state after preset and profile operations.
