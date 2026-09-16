# KZSC v1.0.11-generic

## DNS düzeltmeleri

- PPPoE bağlantılarında IPv4 ISS DNS yok sayma durumu, KeeneticOS'un eski ve yeni
  çalışan yapılandırma gösterimlerinde doğru algılanır.
- **KZSC DNS'yi Devre Dışı Bırak** tüm KZSC DNS kayıtlarını temizler, her WAN'da
  ISS DNS yok saymayı iptal eder ve aktif DNS listesini doğrular.
- DNS kayıtları kendiliğinden dönmezse, yalnız ilgili WAN için IPoE/WISP DHCP
  yenilemesi veya PPPoE oturumunun kontrollü yeniden bağlanması uygulanır; işlem
  sonunda DNS sunucularının geldiği tekrar denetlenir.

KeenDNS davranışında değişiklik yoktur.
