# KZSC v0.11.2.47-generic

## Türkçe

- Zapret2 sekmesi, daemon ilk durum döngüsünü tamamlamadan açıldığında artık boşta kalan “Yükleniyor…” ekranına takılmaz.
- Durum dosyası hazır değilse panel, güvenli CGI durum geri dönüşüyle bilgileri doğrudan üretir.
- Zapret2 durum CGI’si ve Türkçe/İngilizce panel akışı doğrulandı.

## English

- The Zapret2 tab no longer remains stuck on “Loading…” when opened before the daemon completes its first status cycle.
- If the cached status file is unavailable, the panel falls back to a safe CGI status response.
- The Zapret2 status CGI and bilingual panel flow were validated.
