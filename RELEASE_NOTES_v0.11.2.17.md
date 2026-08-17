# KZSC v0.11.2.17-generic

## Türkçe

Bu sürüm Ayarlar sekmesine güvenli KZSC ve router yeniden başlatma düğmeleri ekler, görünür Olay Günlüğü sekmesini kaldırır ve web güncelleme kuyruğundaki yanlış `maintenance_queue_unavailable` sonucunu düzeltir.

### Değişiklikler

- Ayarlar sekmesine onay isteyen **KZSC'yi Yeniden Başlat** düğmesi eklendi.
- Yeniden başlatma yalnız KZSC daemon ve lighttpd web arayüzünü etkiler; router ve internet WAN bağlantıları yeniden başlatılmaz.
- İşlem bakım kuyruğunda root daemon tarafından yürütülür. Sonuç önce yayımlanır, servis iki saniye sonra yeniden başlatılır ve arayüz `health.cgi` tekrar hazır olmadan başarı göstermez.
- Yeniden başlatma işlemi korunan arka plan denetim kaydına yazılır ve Telegram sistem bildirimleri açıksa bota iletilir.
- KZSC düğmesinin yanına ayrı ve onaylı **Router'ı Yeniden Başlat** düğmesi eklendi. Tüm internet ve yerel ağ bağlantılarının geçici olarak kesileceği açıkça gösterilir.
- Router yeniden başlatma CGI'sı yalnız arayüzün özel işlem başlığıyla gönderdiği POST isteğini kabul eder; doğrudan GET/görüntü isteğiyle tetiklenemez.
- Router işlemi genel BusyBox `reboot` komutu yerine farklı Keenetic modellerinde bulunan resmi `ndmc` sistem arayüzünü keşfeder ve `system reboot 30` ile planlar. Komut kabul edilmezse yeniden başlatma yapılmaz ve hata kullanıcıya bildirilir.
- Başarılı router yeniden başlatma isteği, sistem kapanmadan önce korunan denetim kaydına ve etkinse Telegram botuna iletilir.
- Olay Günlüğü sekmesi ve ona ait görünür arayüz/JavaScript render kalıntıları kaldırıldı. Arka plan denetim kaydı, güvenlik tanısı ve Telegram senkronizasyonu korunur.
- Güncelleme CGI uçları bakım kuyruğunu yetkisiz CGI kullanıcısıyla yeniden oluşturmaya çalışmaz; var olan güvenli kuyruğu doğrulayıp doğrudan yazar.
- Bakım kuyruğu hazırlama değişkeni BusyBox `ash` altında yerelleştirildi.
- Manuel kurulum, eski başarısız güncellemeden kalan `apply_state`, PID ve hata kayıtlarını temizler; yeni sürümü `idle` ve güncel olarak yayımlar.
- Türkçe/İngilizce düğme, onay, bekleme, başarı ve hata metinleri eklendi.

### Güncelleme

v0.11.2.16 üzerindeki otomatik güncelleme açıksa bu sürüm 30 dakikalık kontrol sırasında doğrulanarak kurulabilir. Manuel kontrol için:

```sh
kzsc update check
kzsc update install
```

## English

This release adds safe KZSC and router restart controls to Settings, removes the visible Event Log tab, and fixes the false `maintenance_queue_unavailable` result in the web update queue path.

### Changes

- A confirmed **Restart KZSC** button is now available in Settings.
- Restart affects only the KZSC daemon and lighttpd web interface; it does not restart the router or Internet WAN uplinks.
- The root daemon performs the action through the maintenance queue. The result is published first, restart begins two seconds later, and the UI does not report success until `health.cgi` is ready again.
- Restart is written to the protected background audit log and synchronized to Telegram when system notifications are enabled.
- A separate confirmed **Restart Router** button is available beside the KZSC control. The UI clearly warns that all Internet and local-network connections will be interrupted temporarily.
- The router-reboot CGI accepts only a POST request carrying the UI's dedicated action header; it cannot be triggered by a direct GET/image request.
- Instead of relying on the generic BusyBox `reboot` command, the router action discovers Keenetic's official `ndmc` system interface and schedules `system reboot 30`. If the command is not accepted, no reboot is reported and the error is returned to the user.
- A successful router-restart request is written to the protected audit log and sent to the Telegram bot, when enabled, before the system goes down.
- The Event Log tab and its visible UI/JavaScript rendering residue were removed. The background audit log remains available for security diagnostics and Telegram synchronization.
- Update CGI endpoints no longer try to recreate the maintenance queue as the unprivileged CGI account; they validate and write directly to the existing protected queue.
- The maintenance-queue preparation variable is now local under BusyBox `ash`.
- Manual installation clears stale failed-update state, worker PID, and error records, then publishes the new release as current and `idle`.
- Turkish and English button, confirmation, waiting, success, and error text are included.

### Update

When automatic updates are enabled on v0.11.2.16, this release can be verified and installed during the 30-minute check. For a manual check:

```sh
kzsc update check
kzsc update install
```
