# KZSC v1.0.3-generic / Windows Hazırlayıcı 1.0.3

## Türkçe

### ISS DNS geri yükleme düzeltmesi

- DNS kapatma işleminde ISS DNS alımını yeniden açmak için kullanılan genel komut düzeltildi.
- PPPoE bağlantılarında `ipcp name-servers`; DHCP/IPoE ve WISP bağlantılarında `ip dhcp client name-servers` kullanılır.
- Bu komut her etkin WAN için koşulsuz uygulanır; böylece önceki sürümden kalan algılanamayan ayarlar da düzeltilir.
- Router öz denetimi WAN türüne göre ISS DNS geri yükleme yolunu doğrular.

## English

### ISP DNS restoration fix

- The generic command previously used to restore ISP DNS was corrected.
- PPPoE connections use `ipcp name-servers`; DHCP/IPoE and WISP connections use `ip dhcp client name-servers`.
- The correct command is applied to every active WAN even if an older setting is not detectable in the running configuration.
- The router self-test now verifies the WAN-type-specific ISP DNS restoration path.

## Release assets

- `keenetic-zapret-smart-control-v1.0.3-generic.tar.gz` and its SHA-256 file — router package.
- `KZSC-Hazirlayici-v1.0.3.zip` and its SHA-256 file — Windows setup assistant.
