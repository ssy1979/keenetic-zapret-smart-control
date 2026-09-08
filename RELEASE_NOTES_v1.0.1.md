# KZSC v1.0.1-generic / Windows Hazırlayıcı 1.0.1

## Türkçe

### Keenetic kayıtlı cihazlar, çevrimdışıyken de yönetilebilir

- **Cihazlar** listesi artık yalnız anlık ARP/komşu tablosunu değil, Keenetic'te kayıtlı istemcileri de gösterir.
- Çevrimdışı kayıtlı cihazlar belirgin bir durum etiketiyle görünür; görüntülenen adresin kayıtlı/son IP olduğu açıkça belirtilir.
- Cihaz çevrimdışıyken de **Zapret üzerinden / Doğrudan internet** tercihi değiştirilebilir. Tercih MAC adresine bağlı saklanır ve cihaz yeniden bağlandığında uygulanır.
- Cihaz filtresine **Çevrimiçi cihazlar** ve **Çevrimdışı kayıtlı cihazlar** seçenekleri eklendi.
- IP'si henüz görünmeyen ancak Keenetic'te MAC adresiyle kayıtlı cihazlar da listelenir; bu cihazlar için tercih bağlantı geldiğinde etkin olur.

### Güvenilirlik

- Çevrimdışı kayıtların WAN/politika keşfi görünürlük içindir; eski bir rota bilgisi hiçbir zaman cihazın canlı politika üyeliğini değiştirmez.
- Yeni regresyon testi, çevrimiçi, çevrimdışı ve IP'siz kayıtlı istemcilerin aynı envanterde görünmesini ve çevrimdışı MAC tercihini doğrular.

## English

### Manage Keenetic-registered devices while they are offline

- The **Devices** view now combines the live ARP/neighbour table with Keenetic's registered-client inventory.
- Offline registered devices have a clear status label and identify their address as a registered/last IP.
- **Via Zapret / Direct Internet** can be changed while a device is offline. The choice is stored by MAC address and applies when the device reconnects.
- The device filter now includes **Online devices** and **Offline registered devices**.
- A client registered by MAC but without a currently visible IP is listed as well; its preference becomes active on connection.

### Reliability

- Offline records are used for visibility only: stale route information never changes a device's live policy membership.
- A new regression test covers online, offline, and no-IP registered clients together with persistent offline MAC preferences.

## Release assets

- `keenetic-zapret-smart-control-v1.0.1-generic.tar.gz` and its SHA-256 file — router package.
- `KZSC-Hazirlayici-v1.0.1.zip` and its SHA-256 file — Windows setup assistant.
