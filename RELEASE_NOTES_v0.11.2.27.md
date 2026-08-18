# KZSC v0.11.2.27-generic

## Türkçe

- KeeneticOS bileşen kurulumu güncelleme işçisini sonlandırırsa, geçerli resume paketi artık otomatik olarak `reboot_pending` durumuna alınır.
- Bu durumda güncelleme geri alınmaz ve router yeniden başladıktan sonra kurulum verileri korunur.
- Güncelleyici kesinti/toparlanma senaryosu için regresyon testi eklendi.

## English

- If KeeneticOS component installation terminates the update worker, a valid resume package is now promoted to `reboot_pending`.
- The update is no longer rolled back in that case, and resume data survives until the router restarts.
- Added regression coverage for interrupted staged updates.
