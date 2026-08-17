# Güvenlik Politikası / Security Policy

## Güvenlik açığı bildirimi

Router kimlik bilgilerini, Telegram token'larını, KeenDNS ayrıntılarını, yedekleri, tanı arşivlerini, genel IP adreslerini veya istismar ayrıntılarını public issue içinde paylaşmayın.

Deponun özel GitHub Security Advisory bildirim akışını kullanın. Etkilenen KZSC sürümünü, Keenetic modelini ve KeeneticOS sürümünü, gizli bilgiler çıkarılmış yeniden üretme adımlarını ve yalnız gerekli en küçük log bölümünü ekleyin.

KZSC'ye ait kod ve yollar kapsam içindedir. Zapret2 sorunları upstream projeye; KeeneticOS ve Entware paket sorunları ilgili üretici/bakımcıya bildirilmelidir. Yalnız güncel sürüm düzeltme alır; yanıt süresi garantisi verilmez.

KZSC otomatik güncellemesi yalnız `ssy1979/keenetic-zapret-smart-control` GitHub release kanalını kabul eder. Dış SHA-256 doğrulaması, arşiv yol/link/boyut kontrolleri ve iç `SHA256SUMS` manifesti uygulanır. Otomatik kurulum varsayılan olarak kapalıdır. GitHub hesabının veya release zincirinin ele geçirildiğinden şüpheleniyorsanız otomatik güncellemeyi kapatın ve özel güvenlik bildirimi gönderin.

---

## Reporting a vulnerability

Do not publish router credentials, Telegram tokens, KeenDNS details, backups, diagnostic archives, public IP addresses, or exploit details in a public issue.

Use the repository's private GitHub Security Advisory reporting flow. Include the affected KZSC version, Keenetic model and KeeneticOS version, reproduction steps with secrets removed, and the smallest relevant log excerpt.

## Scope

Security reports should concern KZSC-owned code and paths. Zapret2 issues belong to its upstream project. KeeneticOS and Entware package issues belong to their respective maintainers.

Only the current release receives fixes. No support window or response-time guarantee is promised.

KZSC self-update accepts only the `ssy1979/keenetic-zapret-smart-control` GitHub release channel. It verifies an external SHA-256 value, archive paths/links/size, and the internal `SHA256SUMS` manifest. Automatic installation is disabled by default. If repository or release-chain compromise is suspected, disable automatic updates and submit a private security report.
