# KZSC v1.0.17-generic

## Türkçe

- Hopper DSL KN-3610 ve benzer KeeneticOS 5.x topolojilerinde kablolu IPoE WAN keşfi düzeltildi.
- Fiziksel portta görülen `role, for = ISP: inet` bağı artık ilgili mantıksal `ISP`/VLAN arayüzüyle ilişkilendiriliyor.
- Mantıksal WAN içindeki IPv4 `defaultgw: yes` bilgisi, aynı bloktaki IPv6 `defaultgw: no` alanı tarafından artık ezilmiyor.
- PPPoE, klasik Ethernet/IPoE ve WISP keşfi korunuyor; yeni mantık model adına bağlı değil ve desteklenen arayüz türleriyle sınırlı kalıyor.
- KN-3610 biçimini, `ISP -> eth2.2` canlı Linux eşlemesini ve kısa default-route kaybında yapılandırılmış WAN'ın korunmasını doğrulayan regression fixture'ları eklendi.
- Sahada doğrulanan ortam: Hopper DSL (KN-3610), KeeneticOS 5.01.C.5.0-0, MIPS, kablolu IPoE.

## English

- Fixed wired IPoE WAN discovery on Hopper DSL KN-3610 and similar KeeneticOS 5.x interface layouts.
- Physical-port bindings such as `role, for = ISP: inet` are now associated with the corresponding logical ISP/VLAN interface.
- An IPv4 `defaultgw: yes` decision is no longer overwritten by a later IPv6 `defaultgw: no` field in the same interface block.
- Existing PPPoE, conventional Ethernet/IPoE and WISP discovery remains supported; the logic stays model-agnostic and restricted to supported uplink types.
- Added regression fixtures for the KN-3610 layout, live `ISP -> eth2.2` Linux mapping, and retention of a configured WAN during a short default-route outage.
- Field-verified environment: Hopper DSL (KN-3610), KeeneticOS 5.01.C.5.0-0, MIPS, wired IPoE.
