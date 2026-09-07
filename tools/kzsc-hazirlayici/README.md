# KZSC Hazırlayıcı / KZSC Preparer

[Türkçe kurulum rehberi](../../docs/KURULUM.md) · [English installation guide](../../docs/INSTALLATION.md)

KZSC Hazırlayıcı, Windows üzerinden KeeneticOS SSH 22'ye bağlanarak KZSC için gereken tabanı hazırlar. Eksik KeeneticOS bileşenlerini, OPKG/Entware kurulumunu, SSH 222 erişimini ve KZSC'nin güvenilir son sürüm kurulumunu tek planda yönetir. DNS ayarlarına dokunmaz; DoT/DoH ve İSS DNS davranışı kurulumdan sonra KZSC DNS sekmesinden yönetilir.

The KZSC Preparer connects to KeeneticOS over SSH 22 and prepares the complete KZSC base. It manages missing KeeneticOS components, OPKG/Entware, SSH 222 access, and installation of the latest trusted KZSC release. It leaves DNS unchanged; DoT/DoH and ISP DNS behavior are managed later from the KZSC DNS tab.

## Güvenlik sınırları / Security boundaries

- Parolalar diske kaydedilmez / Passwords are not stored on disk.
- Disk biçimlendirilmez ve mevcut Entware silinmez / Disks are not formatted and existing Entware is not removed.
- KZSC yalnız `ssy1979/keenetic-zapret-smart-control` deposunun `latest` kanalından alınır.
- Dış SHA-256, güvenli arşiv yolları ve iç `SHA256SUMS` doğrulanmadan kurulum çalışmaz.
- 1.0.0, paketi cihazda değişiklik yapmadan önce bilgisayarda denetler: eksik backend, sürüm uyuşmazlığı, manifest dışı dosya, yinelenen yol, bağlantı/özel dosya ve aşırı açılmış boyut reddedilir. Router üzerinde aynı doğrulanmış SHA-256 yeniden aranır.
- 1.0.0 validates the downloaded payload on the PC before changing the device: missing backends, version mismatch, unlisted files, duplicate paths, links/special files, and excessive expanded size are rejected. The router must download exactly the same verified SHA-256.
- Başka özel Keenetic uygulamasına ait kod veya entegrasyon içermez.

## Kurulum sonucu / Installation result

Başarı yalnız KZSC sürümü ve çalışan servisleri doğrulandıktan, `status`, `preflight` ve `audit full` tamamlandıktan sonra gösterilir. Bileşen kurulumu yeniden başlatma gerektirirse hazırlayıcı SSH 222'ye yeniden bağlanıp otomatik devamın bitmesini bekler. Son denetim başarısızsa mesaj dosyaların kurulmuş olduğunu açıkça belirtir; bu durumda günlüğü kaydedin ve bildirilen hatayı giderdikten sonra yeniden cihaz analizi yapın. Günlük ve raporlardaki parola/token değerleri maskelenir.

Success is shown only after checking the installed KZSC version, running services, `status`, `preflight`, and `audit full`. If component installation needs a reboot, the preparer reconnects to SSH 222 and waits for resumed installation. A failed final audit explicitly reports that files were installed; save the log and analyze the device again after resolving the reported error. Passwords and tokens are redacted from logs and reports.

## Kaynaktan test / Test from source

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r tools\kzsc-hazirlayici\requirements.txt
.venv\Scripts\python.exe -m unittest discover -s tools\kzsc-hazirlayici\tests -v
.venv\Scripts\python.exe tools\kzsc-hazirlayici\app.py --smoke-test
```

Windows paketleme ayrıntıları için [BUILD.md](BUILD.md) dosyasına bakın.
