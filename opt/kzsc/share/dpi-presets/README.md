# KZSC başlangıç DPI profilleri / Baseline DPI profiles

Bu dizindeki altı `.conf` dosyası KZSC için yeniden yazılmış aynı temel TCP
profilidir. Eski ISS kimlikleri yalnız kayıtlı profil seçimleri bozulmasın diye
korunur; isimler, o ISS üzerinde başarıyla test edildiği anlamına gelmez.
Gerçek WAN üzerinde Blockcheck çalıştırın; sonucu hedef sitelerde doğrulayın.

HTTP için hostname başlangıcından sonraki, TLS için ilk bayt ve SNI uzantısındaki
bir konumdan bölme kullanılır. Paket içeriği korunur. Sahte paket, tahmini TTL,
Lua kodu enjeksiyonu veya başka bir yönetim uygulamasından strateji alınmamıştır.
Bu TCP profilleri etkinleştiğinde UDP 443 engellenerek HTTP/3 yerine TCP/TLS
bağlantısına geçiş istenir; TCP desteklemeyen UDP hizmetleri bu profilin kapsamı
dışındadır. Blockcheck başarılı bir QUIC stratejisi bulursa kendi otomatik
profiline bunu ekleyebilir.

IPv4 ve IPv6 farklı yollar izleyebilir. KZSC `ip_ttl` değerini `ip6_ttl` olarak
kopyalamaz. IPv4'e özgü hop ayarı olan bir otomatik profil, aynı Lua ifadesinde
açık IPv6 karşılığı yoksa IPv4 ile sınırlanır; IPv6 trafik normal geçer. Her iki
ailenin açık değerleri korunur. Genel IPv6 bağlantı testi, DPI aşma başarısını
kanıtlamaz. Temel bölme profillerinde aileye özgü hop ayarı bulunmaz.

Cihaz bazında DPI kapatma tercihi varsa IPv6 DPI kapalı tutulur; mevcut cihaz
kaydında yalnız IPv4 adresleri bulunduğu için değişken IPv6 adreslerine güvenli
istisna uygulanamaz. Böylece kapatılan cihaz IPv6 üzerinden yeniden DPI işlemine
alınmaz. IPv4 cihaz istisnaları ve normal IPv6 internet bağlantısı korunur.

The six `.conf` files contain one independently authored KZSC TCP baseline.
Legacy ISP IDs remain for saved-selection compatibility, not as a claim that the
strategy has been tested on those networks. Run Blockcheck on the actual WAN
and verify the target sites. HTTP splits after the hostname begins; TLS splits
at a fixed early byte and within the SNI extension. No fake payload, guessed
hop count, injected Lua program, or other manager strategy is bundled.

These TCP-only profiles reject UDP 443 to request HTTP/3-to-TCP fallback. They
do not provide a strategy for UDP-only services. A successful QUIC Blockcheck
result can populate an automatic profile separately.

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

The configuration was composed using the official Zapret2 interface manual:
[profile filters, standard fooling, markers and multisplit](https://github.com/bol-van/zapret2/blob/master/docs/manual.en.md).
Only the documented API is referenced; the upstream Lua implementations are
downloaded separately from the official project and keep their licenses.
No ISP success is asserted by syntax or regression tests alone.
