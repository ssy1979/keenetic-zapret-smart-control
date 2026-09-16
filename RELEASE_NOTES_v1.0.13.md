# KZSC v1.0.13-generic

## DNS uyumluluk düzeltmesi

- ndmc çıktısındaki taşıma dönüşleri ve terminal kontrol karakterleri
  temizlenerek IPv4 ISS DNS durumu doğru gösterilir.
- PPPoE ISS DNS engeli için desteklenen iki KeeneticOS komut dizilimi sırayla
  denenir.
- KZSC DNS kapatıldığında tüm WAN'larda ISS DNS kabulü doğrulanır ve bağlantı
  yeniden müzakere edilerek DNS sunucuları yeniden alınır.

KeenDNS davranışında değişiklik yoktur.
