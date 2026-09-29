# KZSC v1.0.18-generic

## Türkçe

- Extra DSL KN-2111 ve benzer KeeneticOS 5.x PPPoE-over-VLAN topolojilerinde taşıyıcı VLAN/Ethernet arayüzünün ayrı bir IPoE WAN olarak yanlış sayılması düzeltildi.
- KZSC artık IPv4 adresi olmayan ve `usedby: PPPoE*` ile bir PPPoE oturumu tarafından açıkça tüketilen taşıyıcı arayüzleri WAN listesinden çıkarır; gerçek PPPoE oturumu (`PPPoE0 -> ppp0` gibi) korunur.
- Düzeltme model adına bağlı değildir. IPv4 adresi bulunan gerçek IPoE VLAN/Ethernet bağlantıları, WISP, klasik PPPoE ve karma çoklu-WAN yapıları aynı şekilde desteklenmeye devam eder.
- KN-2111 (Extra DSL, KeeneticOS 5.01.C.6.0-1) için `Dsl0/Vlan35 -> PPPoE0 -> ppp0` regression fixture'ı eklendi; ayrıca adresli IPoE VLAN ile PPPoE'nin birlikte bulunduğu karma senaryonun filtrelenmediği doğrulanır.
- KN-3610 IPoE regression kapsamı ve mevcut 1/2/3/4-WAN PPPoE/IPoE/WISP testleri korunur.
- Güvenlik/audit allow-list gevşetilmedi. Bu düzeltme kaynakta yer aldığı için kullanıcıların manuel hotfix, `.new` veya yedek dosyası bırakmasına gerek kalmaz.
- Windows KZSC Hazırlayıcı mantığında değişiklik gerekmedi; mevcut Hazırlayıcı 1.0.16 güvenilir GitHub `latest` kanalından bu KZSC sürümünü otomatik olarak çözer. Release iş akışı Hazırlayıcı paketini de yeniden doğrulayıp aynı yayına ekler.

## English

- Fixed PPPoE-over-VLAN WAN discovery on Extra DSL KN-2111 and similar KeeneticOS 5.x layouts where a carrier VLAN/Ethernet interface could be misclassified as a separate IPoE WAN.
- KZSC now excludes a carrier interface only when it has no IPv4 address and is explicitly consumed by a PPPoE session via `usedby: PPPoE*`; the real PPPoE session (for example `PPPoE0 -> ppp0`) remains the WAN.
- The fix is model-agnostic. Real IPoE VLAN/Ethernet interfaces with an IPv4 address, WISP, conventional PPPoE, and mixed multi-WAN configurations remain supported.
- Added a KN-2111 (Extra DSL, KeeneticOS 5.01.C.6.0-1) regression fixture for `Dsl0/Vlan35 -> PPPoE0 -> ppp0`, plus a conservative mixed test proving that an addressed IPoE VLAN is not filtered when PPPoE is also present.
- Existing KN-3610 IPoE coverage and the 1/2/3/4-WAN PPPoE/IPoE/WISP regression matrix remain in place.
- The security/audit allow-list is not weakened. Because the fix is shipped in the source, users no longer need manual hotfix files, `.new` files, or backup artifacts in the KZSC tree.
- No Windows KZSC Preparer logic change was required; existing Preparer 1.0.16 resolves this KZSC version from the trusted GitHub `latest` channel. The release workflow still rebuilds and verifies the Preparer asset for the same release.
