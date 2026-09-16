# KZSC v1.0.14-generic

## Kapatma güvenliği ve ISS DNS göstergesi

- KZSC DNS devre dışı bırakıldığında tüm özel DNS/DoT/DoH kayıtları
  temizlenir ve normal Cloudflare DNS sunucuları 1.1.1.1 ile 1.0.0.1 eklenir.
- ISS DNS yeniden müzakeresi beklenmediği için WAN bağlantısı gereksiz yere
  kesilmez.
- IPv4 ISS DNS durumu, başarılı KZSC politikasını esas alarak doğru gösterilir;
  ndmc çıktı biçimi yanlış bir “Kullanılıyor” etiketi oluşturamaz.

KeenDNS davranışında değişiklik yoktur.
