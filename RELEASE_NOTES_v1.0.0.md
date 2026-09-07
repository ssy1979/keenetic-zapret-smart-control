# KZSC v1.0.0-generic / Windows Hazırlayıcı 1.0.0

Bu sürüm, KZSC ve Windows Hazırlayıcı'nın güncel, doğrulanmış özelliklerini tek ve kararlı 1.0.0 yayında birleştirir. Router paketi ile Windows paketi aynı GitHub Release altında, ayrı SHA-256 denetim dosyalarıyla yayımlanır.

## Türkçe — KZSC router paneli

- KeeneticOS üzerinde Zapret2 yönetimi için Türkçe/İngilizce web paneli (`http://ROUTER_IP:9090/`).
- Model listesine bağlı kalmadan salt-okunur yetenek ön denetimi: Open Package/Entware, `dns-tls`, `dns-https`, lighttpd/mod_cgi, iptables/NFQUEUE, queue-bypass, çalışabilir Zapret2 ikilisi ve internet bağlantıları doğrulanır.
- Tekli veya çoklu WAN keşfi; PPPoE, kablolu IPoE/Ethernet (DHCP ya da statik, üst router'dan özel IPv4 dahil) ve Keenetic WISP desteği.
- Her WAN için gerçek bağlantı adı, Linux arayüz eşlemesi, bağımsız DPI profili, NFQUEUE ve Blockcheck işlemi.
- Zapret2 için Tüm Ağ ve alan adı politikaları; WAN başına hariç alan adı/uzantı listeleri ve görünür sayaçlar.
- Cihaz ekranında cihaz bazında Zapret açma/kapatma, doğrudan internet istisnası, WAN profili görünürlüğü ve isteğe bağlı Keenetic DHCP statik IP rezervasyonu.
- Çoklu WAN, yük dengeleme ve failover yollarında KZSC istisnalarının korunması; TCP odaklı profillerde QUIC geri dönüşü için ayrı güvenli filter zinciri.
- Blockcheck önce kısa hazır profil doğrulaması yapar; gerekirse sabit duvar saati sınırı olmadan tam upstream standart strateji kümesine devam eder ve çalışan sonucu kaydeder.
- DNS sekmesinden DoT/DoH ve İSS DNS davranışı yönetimi; hazırlayıcı DNS ayarlarını değiştirmez.
- Telegram bildirimleri, durum özeti, güncelleme denetimi/kurulumu ve otomatik güncelleme komutları.
- Yapılandırma, politika ve rezervasyon verileri için güvenli yedekleme/geri yükleme; durum, preflight ve tam audit komutları.
- Onaylı KZSC yeniden başlatma ile ayrı, onaylı Keenetic router yeniden başlatma denetimleri; işlem sonuçları denetim kaydına ve etkinse Telegram'a aktarılır.
- Manuel, web, Telegram ve isteğe bağlı 30 dakikalık otomatik güncelleme yollarında güvenilir GitHub kaynak/varlık sabitleme, SHA-256 ve iç `SHA256SUMS` doğrulaması, güvenli arşiv sınırları, downgrade engeli ve başarısız güncellemede otomatik geri alma.
- Daemon yaşam döngüsünde PID kimliği doğrulama, atomik tekil çalışma, SSH/HUP dayanıklılığı ve güvenli bakım kuyruğu.

## Türkçe — Windows Hazırlayıcı

- Windows masaüstü uygulaması; Türkçe ve İngilizce arayüz, ağda Keenetic keşfi ve SSH 22 yönetici hesabıyla salt-okunur analiz.
- Eksik KeeneticOS bileşenlerini planlama, USB/dahili depolama hedefi seçimi, OPKG/Entware kurulumu, Entware SSH 222 erişimi ve güvenilir KZSC kurulumu.
- Gerçek KeeneticOS yapılandırmasından WAN/sağlayıcı adlarını ayrıştırma; LAN ve fiziksel portları hariç tutma, tekli/çoklu WAN için doğru arayüz seçimi.
- Yeniden başlatma gerekirse SSH 222'ye yeniden bağlanma, otomatik devamı bekleme ve yalnız çalışan servisler ile `status`, `preflight`, `audit full` kontrolleri tamamlanınca başarı bildirme.
- Parolaları diskte saklamaz; günlük ve raporlarda parola/token değerlerini maskeler.
- Mevcut Entware'i silmez, disk biçimlendirmez ve DNS ayarlarına dokunmaz.
- Router değişmeden önce Windows üzerinde paketin tamamını denetler: sürüm, zorunlu backend'ler, manifest kapsamı, yinelenen veya güvenli olmayan yollar, bağlantılar/özel dosyalar ve açılmış boyut sınırları denetlenir. Router'ın aynı doğrulanmış SHA-256 dosyasını indirmesi zorunludur.
- Bağımsız testler, paketlenmiş uygulama smoke testi ve SHA-256 dosyasıyla dağıtım.

## English — KZSC router panel

- Turkish/English web panel for Zapret2 management on KeeneticOS (`http://ROUTER_IP:9090/`).
- Read-only, capability-based pre-flight instead of a model allow-list: Open Package/Entware, `dns-tls`, `dns-https`, lighttpd/mod_cgi, iptables/NFQUEUE, queue bypass, a working Zapret2 binary, and Internet uplinks are checked.
- Single- and multi-WAN discovery for PPPoE, wired IPoE/Ethernet (DHCP or static, including private IPv4 behind an upstream router), and Keenetic WISP.
- Per-WAN user-facing connection name, Linux interface mapping, independent DPI profile, NFQUEUE, and Blockcheck operation.
- All-Network and domain policies for Zapret2, with per-WAN exclusion domain/suffix lists and visible counters.
- Per-device Zapret on/off, direct-Internet bypass, WAN-profile visibility, and optional Keenetic DHCP static-IP reservation in the Devices view.
- Preserved KZSC exclusions across multi-WAN, load-balancing, and failover paths; a dedicated safe filter chain provides QUIC fallback for TCP-focused profiles.
- Blockcheck first validates short bundled presets, then—when needed—continues without a wall-clock limit through the complete upstream standard strategy set and saves a working result.
- DoT/DoH and ISP-DNS behavior management from the DNS tab; the preparer does not alter DNS settings.
- Telegram notifications, status summary, update check/install, and automatic-update commands.
- Secure backup/restore for configuration, policy, and reservation data, plus status, preflight, and full-audit commands.
- Confirmed KZSC restart and separate confirmed Keenetic router restart controls; results are recorded in the audit log and sent to Telegram when enabled.
- Trusted GitHub source/asset pinning, SHA-256 plus internal `SHA256SUMS` verification, safe archive limits, downgrade protection, and automatic rollback on failed updates across manual, web, Telegram, and opt-in 30-minute automatic update paths.
- Daemon lifecycle hardening with PID identity checks, atomic singleton operation, SSH/HUP resilience, and a safe maintenance queue.

## English — Windows Preparer

- Windows desktop application with Turkish and English UI, LAN discovery, and read-only analysis through the KeeneticOS SSH 22 administrator account.
- Plans missing KeeneticOS components, USB/internal storage selection, OPKG/Entware installation, Entware SSH 222 access, and trusted KZSC installation.
- Parses real KeeneticOS configuration to retain WAN/provider names, exclude LAN and physical ports, and choose the correct interface for single- and multi-WAN setups.
- Reconnects through SSH 222 after a required reboot, waits for automatic continuation, and reports success only after services plus `status`, `preflight`, and `audit full` checks pass.
- Never stores passwords on disk; redacts password/token values from logs and reports.
- Never formats disks, removes existing Entware, or changes DNS settings.
- Validates the entire package on the PC before changing the router: version, required backends, manifest coverage, duplicate or unsafe paths, links/special files, and expanded-size limits. The router must download the identical verified SHA-256 payload.
- Distributed with regression coverage, a packaged-application smoke test, and a SHA-256 verification file.

## Assets

- `keenetic-zapret-smart-control-v1.0.0-generic.tar.gz` and its SHA-256 file — router package.
- `KZSC-Hazirlayici-v1.0.0.zip` and its SHA-256 file — Windows setup assistant.
