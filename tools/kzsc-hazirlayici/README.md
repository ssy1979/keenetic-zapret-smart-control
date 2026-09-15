# KZSC Hazırlayıcı / KZSC Preparer

[🇹🇷 Türkçe görselli kurulum](../../docs/KURULUM.md) · [🇬🇧 English visual installation](../../docs/INSTALLATION.md) · [Latest release](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest)

**KZSC Hazırlayıcı**, Windows üzerinden Keenetic router’a KZSC kurmanın en kolay yoludur. / **KZSC Preparer** is the simplest Windows route for installing KZSC on a Keenetic router.

## Kullanıcı için / For users

1. Son sürümden `KZSC-Hazirlayici-*.zip` dosyasını indirin. / Download `KZSC-Hazirlayici-*.zip` from the latest release.
2. ZIP’in tamamını çıkartın. / Extract the whole ZIP.
3. `KZSC-Hazirlayici.exe` dosyasını çalıştırın. / Run `KZSC-Hazirlayici.exe`.
4. Cihazı analiz edin, planı okuyun ve uygulayın. / Analyse the router, review the plan, and apply it.

Uygulama eksik KeeneticOS bileşenlerini, OPKG/Entware tabanını ve KZSC’nin doğrulanmış güncel sürümünü hazırlar. / The app prepares missing KeeneticOS components, the OPKG/Entware base, and the verified current KZSC release.

## Güvenlik / Safety

- Parolalar diske kaydedilmez. / Passwords are not stored on disk.
- Diskler biçimlendirilmez; mevcut Entware silinmez. / Disks are not formatted and existing Entware is not removed.
- KZSC yalnız bu projenin güvenilir GitHub yayınından indirilir ve doğrulanır. / KZSC is downloaded only from this project’s trusted GitHub release and verified.
- İlk bağlantı için router’da yerel **SSH 22** erişimi etkin olmalıdır. / Local **SSH 22** must be enabled on the router for the first connection.

## Geliştiriciler için / For developers

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r tools\kzsc-hazirlayici\requirements.txt
.venv\Scripts\python.exe -m unittest discover -s tools\kzsc-hazirlayici\tests -v
.venv\Scripts\python.exe tools\kzsc-hazirlayici\app.py --smoke-test
```

Paketleme ayrıntıları: [BUILD.md](BUILD.md).
