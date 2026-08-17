# Katkı Rehberi / Contributing

## Türkçe

Katkılar KZSC'nin yetenek tabanlı davranışını korumalı; tek bir router modeli, PPP arayüz numarası, WAN sayısı, ISS, LAN adresi, Telegram bilgisi veya genel IP sabitlenmemelidir.

Pull request açmadan önce `sh tests/test-adaptive-wan.sh` testini ve değişen tüm shell/CGI dosyalarında `sh -n` kontrolünü çalıştırın. BusyBox `ash` uyumluluğunu koruyun, Bash zorunluluğu eklemeyin, her yeni WAN/KeeneticOS arayüz biçimi için fixture ekleyin ve Türkçe/İngilizce UI metinlerini birlikte güncelleyin. Runtime dosyaları, router tanıları, token'lar, yedekler ve indirilmiş Zapret2 ikilileri commit edilmemelidir.

Donanım test raporlarında model, KeeneticOS sürümü, mimari, WAN türü/sayısı ve pre-flight sonucu bulunmalı; tanımlayıcı ağ bilgileri bulunmamalıdır.

### Depo sahipliği ve sürüm sınırları

- Çekirdek KZSC güncellemeleri `tools/kzsc-hazirlayici/**`, `docs/KURULUM.md`, `docs/INSTALLATION.md`, `docs/images/**` ve README dosyalarındaki işaretli Hazırlayıcı bloklarını silmemeli veya üzerine yazmamalıdır.
- Hazırlayıcı güncellemeleri `opt/kzsc/**`, `install.sh`, çekirdek sürüm notları, `tests/test-adaptive-wan.sh`, `tests/test-updater.sh` veya `v*-generic` tag anlamını değiştirmemelidir.
- `.github/workflows/release.yml` ortak entegrasyon sınırıdır: router paketi `docs/` ve `tools/` dizinlerini içermez; Windows Hazırlayıcı aynı GitHub sürümüne ayrı, SHA-256 doğrulamalı bir varlık olarak eklenir.
- Bu sınırların bilinçli olarak değiştirilmesi gerekiyorsa iki bileşenin testleri ve `tests/test-repository-contract.sh` aynı pull request içinde güncellenmelidir.

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

### Repository ownership and release boundaries

- Core KZSC updates must preserve `tools/kzsc-hazirlayici/**`, `docs/KURULUM.md`, `docs/INSTALLATION.md`, `docs/images/**`, and the marked Preparer blocks in both README files.
- Preparer updates must not alter `opt/kzsc/**`, `install.sh`, core release notes, `tests/test-adaptive-wan.sh`, `tests/test-updater.sh`, or the meaning of `v*-generic` tags.
- `.github/workflows/release.yml` is the shared integration boundary: the router package excludes `docs/` and `tools/`, while the Windows Preparer is attached to the same GitHub release as a separate SHA-256-verified asset.
- If these boundaries must change intentionally, update both component test suites and `tests/test-repository-contract.sh` in the same pull request.
