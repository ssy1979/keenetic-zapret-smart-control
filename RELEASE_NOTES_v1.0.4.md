# KZSC v1.0.4-generic / Windows Hazırlayıcı 1.0.4

## Türkçe

### Temiz kurulumda ISS DNS yoksayma düzeltmesi

- IPoE ve WISP WAN'larında ISS DNS yoksayma komutu Keenetic'in kalıcı yapılandırma biçimi olan `ip no name-servers` olarak düzeltildi.
- Aynı WAN'larda ISS DNS'i yeniden açma komutu `ip name-servers` olarak uygulanır.
- PPPoE bağlantıları için doğru `ipcp name-servers` / `ipcp no name-servers` akışı korunur.

## English

### Clean-install ISP-DNS ignore fix

- For IPoE and WISP WANs, the ISP-DNS ignore command now uses Keenetic's persistent configuration form: `ip no name-servers`.
- ISP DNS is re-enabled on those WANs with `ip name-servers`.
- The correct PPPoE `ipcp name-servers` / `ipcp no name-servers` flow remains in place.

## Release assets

- `keenetic-zapret-smart-control-v1.0.4-generic.tar.gz` and its SHA-256 file — router package.
- `KZSC-Hazirlayici-v1.0.4.zip` and its SHA-256 file — Windows setup assistant.
