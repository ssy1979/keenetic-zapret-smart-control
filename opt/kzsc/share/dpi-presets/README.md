# KZSC DPI profilleri / DPI profiles

Bu dizindeki profiller KZM2 v26.9.2 kaynak commit
`b9fc3f7c18b2f5f8978f16488ad9125a7b161455` içindeki güncel nfqws2
profillerinden GPL-3.0-or-later altında uyarlanmıştır. `tt-fiber`, `sol`,
`kablonet`, `vodafone`, `vodafone-tt` ve `vodafone-tt2` kimlikleri mevcut KZSC
kayıtlarının bozulmaması için korunur. `kablonet`, KZM2'nin multidisorder
profilini temsil eder. Profil adları veya sözdizimi tek başına ISS üzerinde
başarı garantisi değildir; gerçek WAN ve hedef sitede Blockcheck çalıştırın.

The profiles in this directory are adapted under GPL-3.0-or-later from the
current nfqws2 profiles in KZM2 v26.9.2 at commit
`b9fc3f7c18b2f5f8978f16488ad9125a7b161455`. Existing KZSC IDs are retained
for saved-selection compatibility; `kablonet` represents KZM2's multidisorder
profile. A profile name or valid syntax is not proof of success on an ISP.
Run Blockcheck on the real WAN and target site.

IPv4 ve IPv6 farklı yollar izleyebilir. KZSC `ip_ttl` değerini `ip6_ttl` olarak
kopyalamaz. IPv4'e özgü hop ayarı olan bir otomatik profil, aynı Lua ifadesinde
açık IPv6 karşılığı yoksa IPv4 ile sınırlanır; IPv6 trafik normal geçer. Her iki
ailenin açık değerleri korunur. Genel IPv6 bağlantı testi, DPI aşma başarısını
kanıtlamaz. Temel bölme profillerinde aileye özgü hop ayarı bulunmaz.

Cihaz bazında DPI kapatma tercihi varsa IPv6 DPI kapalı tutulur; mevcut cihaz
kaydında yalnız IPv4 adresleri bulunduğu için değişken IPv6 adreslerine güvenli
istisna uygulanamaz. Böylece kapatılan cihaz IPv6 üzerinden yeniden DPI işlemine
alınmaz. IPv4 cihaz istisnaları ve normal IPv6 internet bağlantısı korunur.

IPv4 TTL is not copied to IPv6 Hop Limit. Profiles with family-specific hop
settings are limited to that family unless each expression provides both
families explicitly. General IPv6 HTTPS connectivity is not a DPI-bypass test.
The baseline segmentation profiles themselves have no family-specific hop
settings. Multiple `--new` profiles keep their own family restrictions and
automatic hostlist settings.

While any device has DPI disabled, optional IPv6 DPI stays off. The current
client registry does not provide reliable per-device IPv6 addresses, so KZSC
cannot safely exclude rotating IPv6 addresses individually. Existing IPv6
queues are removed when such a device preference is detected. IPv4 device
exceptions and ordinary IPv6 Internet connectivity remain available.

The upstream Lua implementations are downloaded separately from the official
Zapret2 project and keep their licenses. See `THIRD_PARTY_NOTICES.md` for the
KZM2 attribution and exact source revision. No ISP success is asserted by
syntax or regression tests alone.
