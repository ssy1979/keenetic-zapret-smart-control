# KZSC v1.0.6-generic

## Türkçe

- Güvenli DNS uygulaması DNS kapatma seçeneğini kaldırır.
- Uygula işlemi önce router'daki kayıtlı IPv4/IPv6 DNS, DoT ve DoH upstream kayıtlarını snapshot alarak temizler; tüm etkin WAN'larda ISS DNS otomatik alımını kapatır ve yalnız seçilen DoT/DoH sağlayıcısını kurar.
- Kurulum komutu sıfır koduyla bitse bile güncelleme işçisi kurulu KZSC sürümünü hedef sürümle doğrular; doğrulama başarısızsa güncelleme başarılı sayılmaz.

## English

- The Secure DNS flow removes the DNS disable action.
- Apply snapshots and clears configured IPv4/IPv6 DNS, DoT and DoH upstream records, disables automatic ISP DNS on every active WAN, and configures only the selected DoT/DoH provider.
- Even after a successful installer exit, the update worker verifies that the installed KZSC version matches the target; a failed verification is never reported as a successful update.
