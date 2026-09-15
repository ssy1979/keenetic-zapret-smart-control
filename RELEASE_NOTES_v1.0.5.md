# KZSC v1.0.5-generic / Windows Hazırlayıcı 1.0.5

## Türkçe

- Güvenli DNS akışı sadeleştirildi: DNS kapatma seçeneği ve ISS DNS tercihi kaldırıldı.
- KZSC DNS Uygula, router'da kayıtlı tüm IPv4/IPv6 DNS, DoT ve DoH upstream kayıtlarını önce snapshot alarak temizler.
- Etkin tüm WAN'larda ISS'den otomatik DNS alma kapatılır; ardından yalnız seçilen DoT ve/veya DoH sağlayıcısı kurulur.
- Güncelleme işçisi, kurulum komutu başarılı dönse bile kurulu sürümün hedef sürüme ulaştığını doğrular. Doğrulama yoksa güncelleme başarılı gösterilmez.

## English

- Simplified secure DNS: the DNS disable action and ISP-DNS preference were removed.
- Apply snapshots and clears all configured IPv4/IPv6 DNS, DoT and DoH upstream records on the router.
- Automatic ISP DNS is disabled on every active WAN, then only the selected DoT and/or DoH provider is configured.
- The update worker now verifies the installed version after a successful installer exit and never reports success when that verification fails.

## Assets

- `keenetic-zapret-smart-control-v1.0.5-generic.tar.gz` and its SHA-256 file — router package.
- `KZSC-Hazirlayici-v1.0.5.zip` and its SHA-256 file — Windows setup assistant.
