# KZSC v0.11.2.29-generic

## Türkçe

- Başlatıcı devam paketinin yeniden başlatma sonrasında korunması düzeltildi.
- Kullanılamayan KeeneticOS bileşenlerinde sonsuz yeniden başlatma döngüsü engellendi.
- Entware lighttpd'nin Keenetic web paneliyle port çakışması önlendi.
- Hazırlayıcı DNS ayarlarına dokunmaz; DNS yönetimi KZSC'ye bırakılır.
- KZSC DNS arayüzüne DoT + DoH birlikte seçeneği eklendi.
- WAN keşfi, SSH anahtar doğrulaması ve çoklu WAN uyumluluğu iyileştirildi.
- Güncellenmiş Windows Hazırlayıcı 1.2.7 aynı sürümün varlıkları arasında yayımlanır.

## English

- Preserves the bootstrap resume package across router restarts.
- Prevents endless reboot loops for unavailable KeeneticOS components.
- Prevents Entware lighttpd from masking the Keenetic web panel.
- The preparer no longer changes DNS; DNS ownership remains with KZSC.
- Adds a combined DoT + DoH option to the KZSC DNS UI.
- Improves WAN discovery, SSH host-key verification, and multi-WAN compatibility.
- Publishes the updated Windows Preparer 1.2.7 with the same release assets.
