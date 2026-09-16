# KZSC v1.0.12-generic

## PPPoE ISS DNS düzeltmesi

- PPPoE bağlantılarında ISS DNS yok sayma artık Keenetic'in doğru IPCP
  komutuyla uygulanır: ipcp no name-servers.
- DNS paneli, hem arayüz bloğu hem de tek satırlı çalışan yapılandırma
  gösterimlerinde IPv4 ISS DNS durumunu doğru okur.
- KZSC DNS devre dışı bırakılırken, ISS DNS'lerini yeniden almak için PPPoE
  bağlantısı tanımlı alt arayüzü üzerinden yeniden kurulur. Önceki down/up
  yöntemi PPP oturumunda güvenilir bir yeniden müzakere sağlamıyordu.
- PPPoE profilinde ek DHCP DNS alıcısı varsa, bu da açılır veya kapatılır.

KeenDNS davranışında değişiklik yoktur.
