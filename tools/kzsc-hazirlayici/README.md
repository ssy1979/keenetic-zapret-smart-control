# KZSC Hazırlayıcı / KZSC Preparer

[Türkçe kurulum rehberi](../../docs/KURULUM.md) · [English installation guide](../../docs/INSTALLATION.md)

KZSC Hazırlayıcı, Windows üzerinden KeeneticOS SSH 22'ye bağlanarak KZSC için gereken tabanı hazırlar. Eksik KeeneticOS bileşenlerini, OPKG/Entware kurulumunu, SSH 222 erişimini, DoT/DoH yapılandırmasını, İSS DNS davranışını ve KZSC'nin güvenilir son sürüm kurulumunu tek planda yönetir.

The KZSC Preparer connects to KeeneticOS over SSH 22 and prepares the complete KZSC base. It manages missing KeeneticOS components, OPKG/Entware, SSH 222 access, DoT/DoH, ISP DNS behavior, and installation of the latest trusted KZSC release.

## Güvenlik sınırları / Security boundaries

- Parolalar diske kaydedilmez / Passwords are not stored on disk.
- Disk biçimlendirilmez ve mevcut Entware silinmez / Disks are not formatted and existing Entware is not removed.
- KZSC yalnız `ssy1979/keenetic-zapret-smart-control` deposunun `latest` kanalından alınır.
- Dış SHA-256, güvenli arşiv yolları ve iç `SHA256SUMS` doğrulanmadan kurulum çalışmaz.
- Başka özel Keenetic uygulamasına ait kod veya entegrasyon içermez.

## Kaynaktan test / Test from source

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r tools\kzsc-hazirlayici\requirements.txt
.venv\Scripts\python.exe -m unittest discover -s tools\kzsc-hazirlayici\tests -v
```

Windows paketleme ayrıntıları için [BUILD.md](BUILD.md) dosyasına bakın.
