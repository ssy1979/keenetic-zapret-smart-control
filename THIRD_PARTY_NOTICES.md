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

## GPL-derived DPI preset adaptations / GPL türevi DPI preset uyarlamaları

The `opt/kzsc/share/dpi-presets/kzm2-*.conf` files are adaptations of the ready DPI profile definitions in [RevolutionTR/keenetic-zapret2-manager](https://github.com/RevolutionTR/keenetic-zapret2-manager), licensed under GNU GPL-3.0-or-later. The upstream project and author are credited here as required by the upstream notice. These preset adaptations are distributed under GPL-3.0-or-later; the rest of KZSC remains under its stated project license. See the upstream repository and <https://www.gnu.org/licenses/gpl-3.0.html> for the license terms.

`opt/kzsc/share/dpi-presets/kzm2-*.conf` dosyaları, GNU GPL-3.0-or-later lisanslı [RevolutionTR/keenetic-zapret2-manager](https://github.com/RevolutionTR/keenetic-zapret2-manager) projesindeki hazır DPI profil tanımlarından uyarlanmıştır. Kaynak proje ve geliştirici, upstream bildirimindeki atıf şartı gereği burada açıkça belirtilmiştir. Bu preset uyarlamaları GPL-3.0-or-later kapsamında dağıtılır; KZSC'nin geri kalanı kendi proje lisansına tabidir. Lisans koşulları için upstream deposuna ve <https://www.gnu.org/licenses/gpl-3.0.html> adresine bakın.

The IPv6 TTL/hop-limit strategy normalization in `opt/kzsc/bin/kzsc-native-dpi.sh` is adapted from the same GPL-3.0-or-later KZM2 implementation. KZSC adds its own per-WAN capability detection, NFQUEUE lifecycle, safe IPv4 fallback, and mixed IPv4/IPv6 WAN handling. That script is distributed under GPL-3.0-or-later; modification notices are kept in its header.

`opt/kzsc/bin/kzsc-native-dpi.sh` içindeki IPv6 TTL/hop-limit strateji normalizasyonu da aynı GPL-3.0-or-later lisanslı KZM2 uygulamasından uyarlanmıştır. KZSC buna WAN bazlı yetenek algılama, NFQUEUE yaşam döngüsü, güvenli IPv4 geri dönüşü ve karma IPv4/IPv6 WAN yönetimini ekler. Bu betik GPL-3.0-or-later kapsamında dağıtılır; değişiklik bildirimi dosya başlığında korunur.

---

## KZSC Hazırlayıcı / KZSC Preparer

KZSC Hazırlayıcı'nın uygulama mantığı bu proje için özgün olarak yazılmıştır ve başka özel Keenetic yönetim uygulamalarından kod içermez. Windows paketi, güvenli SSH/TLS ve kullanıcı arayüzü için genel amaçlı açık kaynak çalışma zamanı ve kütüphaneler kullanır: Python, Tk/Tcl, Paramiko, Cryptography, bcrypt, PyNaCl ve bunların zorunlu bağımlılıkları. Bu bileşenlerin lisans bildirimleri kendi dağıtımlarında geçerlidir.

The KZSC Preparer application logic is original to this project and contains no code from other private Keenetic management applications. Its Windows package uses general-purpose open-source runtime components and libraries for SSH, TLS, and UI functionality: Python, Tk/Tcl, Paramiko, Cryptography, bcrypt, PyNaCl, and their required dependencies. Their respective license notices continue to apply.
