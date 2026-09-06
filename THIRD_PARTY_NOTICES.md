# Üçüncü Taraf Bildirimleri / Third-Party Notices

## Türkçe — Zapret2

KZSC, operatörün isteği üzerine Zapret2'yi resmî upstream projeden indirebilir: <https://github.com/bol-van/zapret2>. Telif ve lisans koşulları, çalışma anında indirilen tam upstream release içindeki dosya ve bildirimlere tabidir.

Zapret2 kaynakları, ikilileri, Lua kitaplıkları ve release arşivleri KZSC kaynak deposuna veya KZSC release arşivine dahil edilmez. KZSC ikilileri aynalamaz veya yeniden adlandırmaz. Kurulan kopya, sahiplik ve kaldırma kapsamı açık olacak biçimde `/opt/kzsc/zapret2` altında tutulur.

Keenetic ve ilgili ürün adları kendi sahiplerinin ticari markalarıdır. KZSC resmî bir Keenetic ürünü değildir.

---

## English — Zapret2

KZSC can download Zapret2 at the operator's request from the official upstream project:

- Project: <https://github.com/bol-van/zapret2>
- Copyright and license: governed by the files and notices in the exact upstream release downloaded at runtime

Zapret2 source, binaries, Lua libraries, and release archives are not included in the KZSC source repository or KZSC release archive. KZSC does not mirror or rename Zapret2 binaries. The installed copy remains under `/opt/kzsc/zapret2` so ownership and removal scope are explicit.

Keenetic and related product names are trademarks of their respective owners. KZSC is not an official Keenetic product.

## Current DPI profiles and short Blockcheck / Güncel DPI profilleri ve kısa Blockcheck

The bundled ISP profiles and the reduced Blockcheck strategy-family selection
are adapted from **Keenetic Zapret2 Manager (KZM2) v26.9.2**, upstream commit
`b9fc3f7c18b2f5f8978f16488ad9125a7b161455`, by RevolutionTR:
<https://github.com/RevolutionTR/keenetic-zapret2-manager>. These adapted parts
are distributed under **GPL-3.0-or-later**, matching their upstream license.
The stable KZSC saved-profile IDs and per-WAN NFQUEUE integration remain KZSC
interfaces. KZSC does not turn IPv4 TTL values into guessed IPv6 Hop Limits;
such profile expressions are restricted to IPv4 unless an explicit IPv6 value
is present. Run Blockcheck and verify the real target WAN before relying on a
profile.

Paketli ISS profilleri ile daraltılmış Blockcheck strateji ailesi seçimi,
RevolutionTR tarafından geliştirilen **Keenetic Zapret2 Manager (KZM2) v26.9.2**
ve yukarıdaki kaynak commitinden uyarlanmıştır. Bu uyarlanan parçalar upstream
ile aynı şekilde **GPL-3.0-or-later** lisansıyla dağıtılır. KZSC'nin kayıtlı
profil kimlikleri ve WAN başına NFQUEUE entegrasyonu korunur. KZSC, IPv4 TTL
değerinden tahmini IPv6 Hop Limit üretmez; açık IPv6 değeri olmayan ilgili
ifadeler IPv4 ile sınırlandırılır. Profili kullanmadan önce gerçek WAN ve hedef
site üzerinde Blockcheck ile doğrulayın.

### Historical versions / Geçmiş sürümler

Prior source history and releases, including v0.11.2.54, also carried adaptations
credited to [RevolutionTR/keenetic-zapret2-manager](https://github.com/RevolutionTR/keenetic-zapret2-manager)
under GPL-3.0-or-later. Replacing that material in the current tree does not
relicense historical copies or remove their original attribution obligations.
When redistributing those older copies, keep the notices attached to that exact
version and the applicable [GPL terms](https://www.gnu.org/licenses/gpl-3.0.html).

v0.11.2.54 dahil önceki kaynak geçmişi ve yayınlarda da yukarıdaki projeye atfedilen
GPL-3.0-or-later uyarlamalar vardı. Güncel ağaçtaki değiştirme işlemi geçmiş
kopyaların lisansını veya atıf yükümlülüğünü değiştirmez. Eski sürümler yeniden
dağıtılırken o sürümün özgün bildirimleri ve geçerli GPL koşulları korunmalıdır.

---

## KZSC Hazırlayıcı / KZSC Preparer

KZSC Hazırlayıcı'nın uygulama mantığı bu proje için özgün olarak yazılmıştır ve başka özel Keenetic yönetim uygulamalarından kod içermez. Windows paketi, güvenli SSH/TLS ve kullanıcı arayüzü için genel amaçlı açık kaynak çalışma zamanı ve kütüphaneler kullanır: Python, Tk/Tcl, Paramiko, Cryptography, bcrypt, PyNaCl ve bunların zorunlu bağımlılıkları. Bu bileşenlerin lisans bildirimleri kendi dağıtımlarında geçerlidir.

The KZSC Preparer application logic is original to this project and contains no code from other private Keenetic management applications. Its Windows package uses general-purpose open-source runtime components and libraries for SSH, TLS, and UI functionality: Python, Tk/Tcl, Paramiko, Cryptography, bcrypt, PyNaCl, and their required dependencies. Their respective license notices continue to apply.
