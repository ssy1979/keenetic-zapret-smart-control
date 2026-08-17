# Katkı Rehberi / Contributing

## Türkçe

Katkılar KZSC'nin yetenek tabanlı davranışını korumalı; tek bir router modeli, PPP arayüz numarası, WAN sayısı, ISS, LAN adresi, Telegram bilgisi veya genel IP sabitlenmemelidir.

Pull request açmadan önce `sh tests/test-adaptive-wan.sh` testini ve değişen tüm shell/CGI dosyalarında `sh -n` kontrolünü çalıştırın. BusyBox `ash` uyumluluğunu koruyun, Bash zorunluluğu eklemeyin, her yeni WAN/KeeneticOS arayüz biçimi için fixture ekleyin ve Türkçe/İngilizce UI metinlerini birlikte güncelleyin. Runtime dosyaları, router tanıları, token'lar, yedekler ve indirilmiş Zapret2 ikilileri commit edilmemelidir.

Donanım test raporlarında model, KeeneticOS sürümü, mimari, WAN türü/sayısı ve pre-flight sonucu bulunmalı; tanımlayıcı ağ bilgileri bulunmamalıdır.

---

## English

Contributions should preserve KZSC's capability-based behavior and must not hard-code a single router model, PPP interface number, WAN count, ISP, LAN address, Telegram credential, or public IP.

Before opening a pull request:

1. Run `sh tests/test-adaptive-wan.sh` on a POSIX host.
2. Run `sh -n` on every changed shell or CGI script.
3. Preserve BusyBox `ash` compatibility; do not require Bash.
4. Add a fixture for every new WAN or KeeneticOS interface form.
5. Keep Turkish and English UI text in sync.
6. Never commit runtime files, router diagnostics, tokens, backups, or downloaded Zapret2 binaries.

Hardware test reports should state the model, KeeneticOS version, architecture, WAN type/count, and pre-flight result without including identifying network data.
