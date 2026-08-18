# KZSC v0.11.2.22-generic

## Türkçe

- Cihaz bazında **Doğrudan internet (Zapret kapalı)** tercihi artık keşif anındaki WAN eşlemesine bağlı değildir. İstisna, tek WAN, Multi-WAN, yük dengeleme ve failover yollarındaki tüm KZSC WAN zincirlerine uygulanır. Arayüz yalnız trafik kuralları gerçekten kurulup doğrulandığında başarı bildirir; eksik istisnalar daemon tarafından onarılır.
- TCP-only DPI profillerindeki QUIC geri-dönüş kuralı cihaz istisnalarını koruyan ayrı bir KZSC filter zincirine taşındı. İstisna yalnız KZSC reddini atlar; Keenetic'in diğer güvenlik duvarı kuralları çalışmaya devam eder.
- **Çalışma Modu** üst menüde ayrı sekmedir. PPPoE0/PPPoE1 yerine gerçek bağlantı adı öne çıkar; teknik arayüz ayrıca gösterilir. Otomatik ve hariç alan adı listeleri, sayaçları ve boş durumları görünürdür.
- Cihazlar ekranı sabit genişlik zorlamasından çıkarıldı. Orta ve küçük ekranlarda her cihaz anlaşılır bir karta dönüşür; Zapret tercihi, IP rezervasyonu ve WAN profili ekran dışında kalmaz.
- KZSC Hazırlayıcı v1.2.6 gerçek KeeneticOS `Interface, name = "..."` kayıtlarını, `role: inet` bilgisini ve running-config içindeki `!` blok sınırlarını ayrıştırır. Geçersiz LAN/fiziksel portlar WAN listesinden çıkarılır, kullanıcı bağlantı adları doğru arayüze bağlanır ve Multi-WAN kurulumlarında varsayılan seçim **Hepsi** olur.
- Hazırlayıcı WAN ayrıştırıcısı, cihaz politikası, Multi-WAN/failover istisnaları, shell sözdizimi ve web JavaScript'i için regresyon testleri genişletildi.

## English

- The per-device **Direct internet (Zapret off)** preference no longer depends on the WAN mapping observed during discovery. The bypass is installed in every KZSC WAN chain for single-WAN, Multi-WAN, load-balancing, and failover paths. The UI reports success only after the traffic rules are installed and verified, and the daemon repairs missing exclusions.
- TCP-only DPI profiles now use a dedicated KZSC filter chain for QUIC fallback while preserving device exclusions. The exclusion bypasses only KZSC's rejection; Keenetic's remaining firewall rules continue normally.
- **Operating Mode** is now a separate top-level tab. The user-facing connection name is primary, the technical interface is shown separately, and automatic/exclusion domain lists include visible counts and empty states.
- The Devices view no longer forces a fixed-width table. Medium and small screens switch each device to a clear card so Zapret preference, IP reservation, and WAN profile remain visible.
- KZSC Preparer v1.2.6 parses real KeeneticOS `Interface, name = "..."` records, `role: inet`, and `!` running-config boundaries. Invalid LAN/physical ports are removed from WAN choices, provider labels remain attached to the correct interface, and **All** is the default on Multi-WAN installations.
- Regression coverage was expanded for Preparer WAN parsing, device policy, Multi-WAN/failover exclusions, shell syntax, and web JavaScript.
