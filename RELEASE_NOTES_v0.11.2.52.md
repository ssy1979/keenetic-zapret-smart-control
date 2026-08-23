# KZSC v0.11.2.52-generic

## Türkçe

- Zapret2 sekmesinde “KZSC DPI motorları” satırının düzenli aralıklarla görünüp kaybolması düzeltildi.
- Genel bakım yenilemesi ile Zapret2 hızlı yenilemesi artık aynı ortak durum çizicisini kullanıyor.
- Geçici bir durum isteği hatasında son doğrulanmış panel bilgisi korunuyor; kart yeniden “yükleniyor” veya eksik içeriğe dönmüyor.
- İki yenileme yolunun ortak çiziciyi kullanmasını doğrulayan arayüz regresyon kontrolleri eklendi.

## English

- Fixed the “KZSC DPI engines” row repeatedly appearing and disappearing on the Zapret2 tab.
- The general maintenance refresh and fast Zapret2 refresh now use the same shared status renderer.
- The last verified panel state is preserved during a transient status request failure instead of reverting to loading or incomplete content.
- Added UI regression checks requiring both refresh paths to use the shared renderer.
