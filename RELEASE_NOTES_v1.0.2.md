# KZSC v1.0.2-generic / Windows Hazırlayıcı 1.0.2

## Türkçe

### KZSC DNS kapatıldığında ISS DNS'e güvenli dönüş

- DNS sekmesindeki **KZSC DNS'yi Devre Dışı Bırak** işlemi artık router'daki tüm statik IPv4/IPv6 DNS, DoT ve DoH upstream kayıtlarını temizler.
- Etkin tüm WAN bağlantılarında daha önce uygulanmış **ISS DNS'lerini yok say** ayarı kaldırılır; her bağlantı yeniden ISS'den DNS alır.
- İşlemden önce panel, tüm özel DNS kayıtlarının silineceğini ve ISS DNS'e dönüleceğini açıkça onaylatır.

## English

### Safe return to ISP DNS when KZSC DNS is disabled

- **Disable KZSC DNS** now removes all static IPv4/IPv6 DNS, DoT, and DoH upstream entries configured on the router.
- It clears the previous **Ignore ISP DNS** setting on every active WAN, allowing each connection to receive DNS from its ISP again.
- The panel asks for confirmation before this full DNS cleanup and ISP-DNS restoration.

## Release assets

- `keenetic-zapret-smart-control-v1.0.2-generic.tar.gz` and its SHA-256 file — router package.
- `KZSC-Hazirlayici-v1.0.2.zip` and its SHA-256 file — Windows setup assistant.
