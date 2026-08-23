# KZSC v0.11.2.51-generic

## Türkçe

- Zapret2 otomatik güncelleme durumu eklendikten sonra bozuk üretilen panel JSON'u düzeltildi.
- Hem Zapret2 durum nesnesi hem de otomatik güncelleme CGI yanıtı artık eksiksiz ve geçerli JSON döndürüyor.
- Durum dosyası geçici dosyaya yazılıp atomik olarak yayımlanıyor; panel yarım yazılmış veri okumuyor.
- Gerçek backend ve CGI çıktısını JSON ayrıştırıcısıyla doğrulayan regresyon testi eklendi.

## English

- Fixed malformed panel JSON introduced with the Zapret2 automatic-update status fields.
- Both the Zapret2 status object and automatic-update CGI response now return complete, valid JSON.
- The status artifact is written to a temporary file and published atomically, preventing partial reads by the panel.
- Added a regression test that parses the real backend and CGI output with a JSON parser.
