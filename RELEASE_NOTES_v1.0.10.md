# KZSC v1.0.10-generic

- “ISS DNS'lerini yok say” ve “Temiz Kurulum” seçenekleri Güvenli DNS panelinde korunur.
- “KZSC DNS'yi Devre Dışı Bırak” seçeneği yeniden eklendi.
- Devre dışı bırakma işlemi routerdaki IPv4/IPv6 DNS, DoT ve DoH kayıtlarını temizler.
- Tüm etkin WAN'larda ISS DNS yok sayma ayarı kapatılır ve yapılandırma doğrulanır.
- Keenetic'in `show ip name-server` çıktısında en az bir etkin DNS sunucusu görülmeden işlem başarılı sayılmaz; doğrulanan adresler sonuç mesajında gösterilir.
- KeenDNS özelliklerinde değişiklik yapılmadı.
