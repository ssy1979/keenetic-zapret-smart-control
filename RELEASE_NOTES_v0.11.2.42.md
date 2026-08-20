# KZSC v0.11.2.42-generic

## Türkçe

- IPv6 yeteneği WAN bazında global adres ve canlı HTTPS ile doğrulanır.
- İkincil PPPoE WAN'larda ana tablo default-route satırı zorunlu değildir.
- IPv6 açık WAN profillerinde IPv4 TTL stratejileri IPv6 hop-limit ile tamamlanır.
- TCP-only profillerde IPv6 QUIC/HTTP3 TCP fallback'e alınır.
- IPv4-only WAN'lar güvenli IPv4 DPI ile devam eder.
- KZM2 GPL-3.0 uyarlama ve atıf bildirimi korunur.

## English

- IPv6 capability is detected per WAN using a global address and live HTTPS.
- Secondary PPPoE WANs do not require a main-table interface-specific default route.
- IPv6-enabled WAN profiles mirror IPv4 TTL strategies to the IPv6 hop limit.
- TCP-only profiles reject IPv6 QUIC/HTTP3 so TCP/TLS fallback remains effective.
- IPv4-only WANs continue safely on the IPv4 DPI path.
- GPL-3.0 KZM2 adaptation and attribution notices are included.
