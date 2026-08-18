# KZSC v0.11.2.26-generic

## Türkçe

- Bileşen kurulumu yeniden başlatma gerektirirse güncelleme artık `reboot_pending` durumunda güvenle bekletilir.
- Güncelleme paketi ve devam (resume) verileri geri alma sırasında korunur.
- Router yeniden başladıktan sonra kurulumun otomatik sürdürülmesi güvenilir hale getirildi.
- Güncelleyici için reboot-pending regresyon testi eklendi.

## English

- Updates that require a component reboot are now safely staged as `reboot_pending`.
- Update and resume payloads are preserved instead of being rolled back prematurely.
- Installation resumes reliably after the router restarts.
- Added updater regression coverage for reboot-pending installations.
