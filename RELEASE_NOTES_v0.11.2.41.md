# KZSC v0.11.2.41-generic

## Türkçe

- IPv6 yeteneği artık WAN bazında değerlendirilir.
- IPv6 varsayılan rotası olmayan WAN IPv4 DPI ile çalışmaya devam eder.
- Bir WAN'ın IPv6 testi başarısız olduğunda diğer WAN motorları durdurulmaz.
- BusyBox IPv6 rota kontrolü ve HTTP yanıtı testi düzeltildi.
- Güncelleme sonrası arayüz sayfasının yenilenmesi gerektiği açıkça bildirilir.

## English

- IPv6 capability is now evaluated independently for each WAN.
- A WAN without an IPv6 default route continues with IPv4 DPI.
- An IPv6 probe failure on one WAN no longer stops the other WAN engines.
- BusyBox IPv6 route detection and HTTP response probing are corrected.
- The interface now clearly tells users to refresh the page after an update.
