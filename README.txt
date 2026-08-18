Keenetic Zapret Smart Control (KZSC)
v0.11.2.21-generic device policy, WAN labels and Preparer recovery

=== v0.11.2.21-generic ===
- Cihaz bazında Zapret ve Keenetic IP rezervasyonu CGI'sının kurulumda korunması ve gerçek POST/JSON uçtan uca testi eklendi.
- Cihazlar ekranı mevcut IP, Zapret erişimi, IP rezervasyonu ve WAN DPI profili olarak anlaşılır biçimde ayrıldı.
- KZSC Hazırlayıcı v1.2.5, uzun Entware beklemesinde kapanan SSH 22 oturumunu yeniden kurar; rc.unslung/Dropbear kurtarması uygular.
- Keenetic CLI `\\xHH` Türkçe adları çözülür; WAN kaynakları arayüz kimliğine göre birleştirilerek VODAFONE FİBER gibi gerçek adlar genel Broadband connection etiketine tercih edilir.

Standart kurulum: `cd /opt/tmp && sha256sum -c keenetic-zapret-smart-control-v0.11.2.21-generic.tar.gz.sha256 && tar -xzf keenetic-zapret-smart-control-v0.11.2.21-generic.tar.gz && cd keenetic-zapret-smart-control-v0.11.2.21-generic && sh install.sh`


Keenetic Zapret Smart Control (KZSC)
v0.11.2.18-generic daemon lifecycle and stale PID recovery

=== v0.11.2.18-generic ===
- Eski `daemon.lock` PID'si başka bir sürece verilmişse KZSC artık bu süreci daemon sanmaz; PID ve tam komut kimliği birlikte doğrulanır.
- Stale daemon PID/lock kayıtları güvenle temizlenir ve servis gerçek `kzsc-daemon.sh` süreciyle yeniden başlatılır.
- Daemon stdin'i çağıran kabuktan ayrılır ve SSH/güncelleme üst sürecinin HUP sinyalinde kapanmaz.
- Güncelleme işçisi PID'si de yalnız gerçek updater komut satırıyla eşleştiğinde aktif kabul edilir.
- Manuel güncelleme kontrolü, eski `failed/success` kurulum durumunu boş hata metniyle birlikte taşımak yerine `idle` durumuna getirir.
- Daemon yaşam döngüsü ve PID reuse senaryosu ayrı regresyon testiyle CI kapsamına alındı.

Standart kurulum: `cd /opt/tmp && sha256sum -c keenetic-zapret-smart-control-v0.11.2.18-generic.tar.gz.sha256 && tar -xzf keenetic-zapret-smart-control-v0.11.2.18-generic.tar.gz && cd keenetic-zapret-smart-control-v0.11.2.18-generic && sh install.sh`


Keenetic Zapret Smart Control (KZSC)
v0.11.2.17-generic KZSC/router restart controls and web UI cleanup

=== v0.11.2.17-generic ===
- Ayarlar sekmesine onaylı KZSC yeniden başlatma düğmesi eklendi; işlem yalnız daemon ve web arayüzünü yeniden başlatır.
- Yanına ayrı ve onaylı Router'ı Yeniden Başlat düğmesi eklendi; Keenetic NDMC üzerinden 30 saniyelik planlı sistem yeniden başlatması kullanır.
- Arayüz servis tekrar erişilebilir olana kadar health endpoint'i izler ve erken başarı bildirimi göstermez.
- Olay Günlüğü görünür sekmesi kaldırıldı; arka plan denetim kaydı ile Telegram senkronizasyonu korunur.
- Güncelleme CGI'larının bakım kuyruğunu yeniden oluşturmaya çalışması kaldırıldı; mevcut kuyruğa doğrudan ve ayrıştırılmış hata ile yazılır.
- Manuel kurulum eski başarısız güncelleme durumunu otomatik olarak temizleyip yeni sürümü `idle` ve güncel olarak yayımlar.
- Windows KZSC Hazırlayıcı v1.2.4, kaynakları ve Türkçe/İngilizce görselli kurulum belgeleri aynı depoya entegre edildi.
- GitHub sürümü router arşivi ile Windows Hazırlayıcı ZIP dosyasını ayrı SHA-256 dosyalarıyla birlikte yayımlar.
- Kurulum rehberleri ve Hazırlayıcı kaynakları CI sahiplik sözleşmesiyle sonraki çekirdek güncellemelerine karşı korunur.

Standart kurulum: `cd /opt/tmp && sha256sum -c keenetic-zapret-smart-control-v0.11.2.17-generic.tar.gz.sha256 && tar -xzf keenetic-zapret-smart-control-v0.11.2.17-generic.tar.gz && cd keenetic-zapret-smart-control-v0.11.2.17-generic && sh install.sh`


Keenetic Zapret Smart Control (KZSC)
v0.11.2.16-generic BusyBox updater scope fix and Telegram update controls

=== v0.11.2.16-generic ===
- BusyBox `ash` altında durum yayınlayıcısının güncelleme çalışma dizinini ezmesi ve arşiv doğrulayıcısının arşiv adını değiştirmesi düzeltildi.
- Güncelleyici fonksiyon değişkenleri yerelleştirildi; geçici dizin temizliği yalnız güvenli `kzsc-self-update.<pid>` yolu ile sınırlandı.
- Test paketi artık gerçek arşivi indirir, SHA-256 ve iç manifesti doğrular, açar, fixture kurucusunu çalıştırır, sonucu yayınlar ve geçici dosyaları denetler.
- Telegram botuna KZSC sürüm kontrolü, durum, onaylı kurulum ve otomatik güncelleme aç/kapat komutları ile inline butonlar eklendi.
- v0.11.2.14/v0.11.2.15 güncelleyicisi kendi hatasını otomatik düzeltemediği için v0.11.2.16 bir kez elle kurulmalıdır; sonraki sürümler otomatik alınabilir.

Standart kurulum: `cd /opt/tmp && sha256sum -c keenetic-zapret-smart-control-v0.11.2.16-generic.tar.gz.sha256 && tar -xzf keenetic-zapret-smart-control-v0.11.2.16-generic.tar.gz && cd keenetic-zapret-smart-control-v0.11.2.16-generic && sh install.sh`


Keenetic Zapret Smart Control (KZSC)
v0.11.2.15-generic web update queue permission hotfix

=== v0.11.2.15-generic ===
- Bazı Keenetic yükseltmelerinde `/opt/kzsc/var` veya `var/run` dizinlerinden kalan 0700 izinlerinin lighttpd CGI kullanıcısını engellemesi düzeltildi.
- Kurucu, servis ve daemon bakım kuyruğunun tüm yolunu hazırlar: üst dizinler yalnız geçiş için 0711, yazılamayan liste kapalı kuyruk 0733 olur.
- Health CGI artık bakım kuyruğuna gerçek bir probe dosyası yazıp siler; `kzsc audit http/full` bu çalışma zamanı koşulunu doğrular.
- Güncelleme sekmesindeki 30 dakikalık otomatik güncelleme aç/kapat seçeneği ve iki CGI eylemi regresyon testine alındı.
- Ham `maintenance_queue_unavailable` kodu yerine Türkçe/İngilizce anlaşılır hata gösterilir.

Standart kurulum: `cd /opt/tmp && tar -xzf keenetic-zapret-smart-control-v0.11.2.15-generic.tar.gz && cd keenetic-zapret-smart-control-v0.11.2.15-generic && sh install.sh`


Keenetic Zapret Smart Control (KZSC)
v0.11.2.14-generic adaptive Keenetic compatibility and absolute Blockcheck deadline

=== v0.11.2.14-generic ===
- Kurulum artık model adı allow-listesine bağlı değildir; KeeneticOS bileşenlerini, CPU mimarisini, Entware/lighttpd CGI ortamını, iptables/NFQUEUE yeteneklerini ve gerçek WAN topolojisini değiştirmeden önce denetler.
- PPPoE, kablolu IPoE/Ethernet (upstream router'dan DHCP/statik özel veya genel IPv4 dahil) ve Keenetic WISP desteklenir; tek veya çok WAN için dinamik registry, benzersiz queue ve CGI uçları üretilir.
- DoT (`dns-tls`) ve DoH (`dns-https`) KeeneticOS bileşenleri tam güvenli DNS işlevi için pre-flight aşamasında zorunlu doğrulanır.
- Queue tükenmesi veya çift tahsis artık `queue 0` ile sessiz devam etmez; registry yayınlanmadan güvenli biçimde hata verir.
- Blockcheck 30 dakika sayacı geniş taramada sıfırlanmaz; işçi girişinde başlayan mutlak sınır preset, ön kontrol, izolasyon ve upstream taramanın tamamını kapsar. Backend domain listesi 240 karakter/10 hedef ile sınırlıdır.
- Zapret2 yanlış mimari veya sinyal/segfault ile sonlanan ikilileri sağlıklı kabul etmez; upstream mimari seçimi cihaz üzerinde çalıştırılarak doğrulanır.
- Hatalı yükseltmede eski çalışan KZSC kodu/ayarları otomatik geri yüklenir. Servis ve gerçek lighttpd CGI erişimi doğrulanmadan kurulum başarılı sayılmaz.
- Ayrı Türkçe/English Güncelleme sekmesi; manuel kontrol/kurulum ile varsayılan kapalı, 30 dakikada bir otomatik kontrol ve kurulum seçeneği eklendi.
- Güncelleme arşivi yalnız güvenilir GitHub release kanalından alınır; SHA-256, iç manifest, arşiv yol/link/boyut ve downgrade kontrolleri uygulanır. Blockcheck çalışırken kurulmaz.
- Yeni sürüm ve kurulum sonucu üst bildirim kutuları, Olay Günlüğü ve Telegram sistem bildirimleriyle senkronize edilir; aynı sürüm Telegram'da tekrar bildirilmez.
- 1, 2, 3 ve 4 WAN karma PPPoE/IPoE/WISP fixture testleri ile güvenli updater testleri; queue tükenmesi, desteklenmeyen WAN, shell syntax ve public-release kalıntı kontrolleri eklendi.

Standart kurulum: `cd /opt/tmp && tar -xzf keenetic-zapret-smart-control-v0.11.2.14-generic.tar.gz && cd keenetic-zapret-smart-control-v0.11.2.14-generic && sh install.sh`

Ön kontrolü ayrıca çalıştırmak için: `kzsc preflight`


Keenetic Zapret Smart Control (KZSC)
v0.11.2.13-generic Blockcheck endpoint race fix

=== v0.11.2.13-generic ===
- Blockcheck CGI uç noktaları daemon, kurulum ve audit aynı anda yenileme yaptığında artık sil-oluştur boşluğu bırakmaz.
- CGI üretimi kilitle serileştirilir; aktif uç noktalar geçici dosyadan atomik olarak değiştirilir ve eski WAN uç noktaları yalnız başarılı üretimden sonra temizlenir.
- `kzsc audit full` içinde görülebilen geçici PPPoE Blockcheck start/stop endpoint FAIL sonucu giderildi.

Standart kurulum: `tar -xzf keenetic-zapret-smart-control-v0.11.2.13-generic.tar.gz && cd keenetic-zapret-smart-control-v0.11.2.13-generic && sh install.sh`

Eski ürün kalıntısı uyarısı alınırsa ve o ürünü artık kullanmadığınızdan eminseniz: `sh install.sh --remove-retired`


Keenetic Zapret Smart Control (KZSC)
v0.11.2.12-generic reliability, translation and backup hardening

=== v0.11.2.12-generic ===
- Olay Günlüğü yazımları atomik kilitle korunur; KeenDNS Copy/Open ve günlük temizleme işlemleri root daemon kuyruğunda işlenir ve arayüz sonucu doğrular.
- Durum simgesiyle başlayan bildirimler dahil Türkçe/İngilizce operasyon mesajları doğru çevrilir; dinamik Zapret2 ayrıntıları da dil değişimini izler.
- DNS CGI katmanındaki mükerrer olay yazımı kaldırıldı; DNS backend her işlem için tek kayıt oluşturur.
- Yedek indirme/silme/geri yükleme/Telegram dosya adları sıkı allow-list ile doğrulanır; yol geçişi reddedilir.
- Yüklenen yedek 5 MiB ile sınırlandırılır. Restore; arşiv yolu, dosya türü, dosya sayısı, açılmış boyut ve yapılandırma içeriği güvenlik kontrollerinden geçmeden uygulanmaz.
- Eski manager ve `/opt/zapret2` ağacı varsayılan kurulumda otomatik silinmez; kurulum güvenli biçimde durur. Bilinçli temizlik `--remove-retired` veya `kzsc remove-retired` ile yapılır.
- Release metadata ve audit/self-test kontrolleri v0.11.2.12-generic için güncellendi.

Standart kurulum: `tar -xzf keenetic-zapret-smart-control-v0.11.2.12-generic.tar.gz && cd keenetic-zapret-smart-control-v0.11.2.12-generic && sh install.sh`

Eski ürün kalıntısı uyarısı alınırsa ve o ürünü artık kullanmadığınızdan eminseniz: `sh install.sh --remove-retired`


Keenetic Zapret Smart Control (KZSC)
v0.11.2.11-generic Overview WAN reconcile UI cleanup

=== v0.11.2.11-generic ===
- Genel Bakış ekranındaki “WAN Otomatik Reconcile / WAN Auto Reconcile” kartı Türkçe ve İngilizce arayüzden kaldırıldı.
- Değişiklik yalnız UI render katmanındadır; daemon `kzsc-reconcile.sh tick`, reconcile runtime JSON, otomatik WAN doğrulama/DPI, Olay Günlüğü ve Telegram bildirimleri çalışmaya devam eder.
- UI self-test artık kartın render edilmediğini ve backend reconcile hook'unun aktif kaldığını doğrular.
- v0.11.2.10 Telegram config/runtime state ayrımı, backup hardening ve audit kontrolleri aynen korunur.
- Canlı doğrulama: UI self-test RC=0, runtime audit RC=0; “Genel Bakış WAN Reconcile kartı gizli / backend aktif” kontrolü OK.


Keenetic Zapret Smart Control (KZSC)
v0.11.2.10-generic Telegram runtime state separation

=== v0.11.2.10-generic ===
- Telegram kullanıcı ayarları ile mutable runtime state ayrıldı.
- `/opt/kzsc/etc/telegram.conf` artık yalnız kullanıcı ayarlarını tutar; `TG_LAST_UPDATE_ID`, `TG_LAST_SENT` ve `TG_LAST_ERROR` `/opt/kzsc/var/lib/telegram-state.conf` altında tutulur.
- İlk çalıştırmada v0.11.2.9 ve daha eski `telegram.conf` içindeki runtime değerleri kaybedilmeden yeni state dosyasına migrate edilir ve config normalize edilir.
- Telegram mesaj/poll runtime yazımları artık `telegram.conf` hash'ini değiştirmez.
- KZSC backup runtime Telegram state'i içermez; Telegram token güvenlik nedeniyle boşaltılmaya devam eder.
- Eski yedek restore akışı `TG_LAST_*` satırlarını restore sırasında sanitize eder ve mevcut cihaz runtime state'ini geri sarmaz.
- Runtime audit, Telegram config/state ayrımını, state dosyası 600 iznini ve state key allow-list'ini doğrular.
- UI self-test'e Telegram state ayrımı, gerekli/izinli keyler, backup exclusion ve legacy restore sanitize kontrolleri eklendi.
- v0.11.2.9 version consistency guard ve v0.11.2.8 HTTP/CGI runtime audit hardening aynen korunur.
- Canlı doğrulama: backup davranış testi, config hash stabilitesi, self-test, runtime, version, HTTP ve full audit RC=0; diagnostics v0.11.2.10-generic.


Keenetic Zapret Smart Control (KZSC)
v0.11.2.9-generic release metadata consistency guard

=== v0.11.2.9-generic ===
- v0.11.2.8 paketindeki aktif sürüm metadata referanslarının 0.11.2.7'de kalması düzeltildi.
- CLI diagnostics, backup metadata, Telegram status, maintenance VERSION ve config example aynı canonical sürüme taşındı.
- Yeni `kzsc audit version` release version consistency kontrolü ekler.
- Version consistency kontrolü `kzsc audit code` ve dolayısıyla `kzsc audit full` içine entegre edildi.
- Farklı/eski aktif `0.11.2.x-generic` referansı kalırsa audit artık FAIL üretir.
- v0.11.2.8 HTTP/CGI runtime audit hardening aynen korunur.
- Canlı doğrulama: version/http/full audit RC=0; diagnostics v0.11.2.9-generic; Settings, KeenDNS ve servisler sağlıklı.


Keenetic Zapret Smart Control (KZSC)
v0.11.2.8-generic HTTP/CGI runtime audit hardening

=== v0.11.2.8-generic ===
- Yeni `kzsc audit http` gerçek lighttpd/CGI yolunu canlı olarak doğrular.
- Settings backend JSON ile local HTTP CGI GET cevabı birebir karşılaştırılır; CGI environment regression artık audit FAIL üretir.
- KeenDNS aktifse proxy upstream port audit'i gerçek runtime kontrolüne dahil edilir.
- KeenDNS HTTPS Settings GET router içinden doğrulanır; hairpin/DNS nedeniyle erişilemiyorsa uyarı verilir.
- HTTP/CGI kontrolü `kzsc audit runtime` ve dolayısıyla `kzsc audit full` içine entegre edildi.
- Canlı doğrulama: `kzsc audit http`, runtime ve full audit RC=0; full audit tüm kontroller OK.



=== v0.11.2.7-generic ===
- Keenetic lighttpd CGI ortamındaki Settings `empty_request` sorunu giderildi.
- Settings CGI PATH sabitlendi ve LD_LIBRARY_PATH temizlenerek GET/SET backend ortamı düzeltildi.
- Ayarlar formu URL-encoded payload'ı QUERY_STRING'e de aynalar; CGI query payload'ını öncelikli kullanır.
- Panel port değişiminde yeni lighttpd portu doğrulanır; başarısızlıkta eski porta rollback yapılır.
- KeenDNS aktifse proxy upstream portu KZSC_PORT ile otomatik senkronize edilir.
- `kzsc-keendns.sh audit` port eşleşmesini doğrular.
- Canlı doğrulama: Settings save; 9090 -> 9091 -> 9090; LAN ve KeenDNS HTTPS erişimi başarıyla test edildi.


v0.11.2.6-generic final ownership/audit hardening
- Copy/Open KeenDNS UI actions are operation-log audited (retained from v0.11.2.5).
- Code audit now recognizes KZSC-owned lighttpd runtime config and only explicitly safe runtime symlinks with validated targets.
- Runtime orphan audit distinguishes shared Blockcheck control directories (_global/queue/scheduler) from per-WAN state.
- Telegram config permission check is BusyBox-safe.
- Installer/purity sanitizer removes the retired lowercase CLI log residue from old builds.
- Standalone ownership scan remains strict for retired product identifiers/paths outside official upstream /opt/kzsc/zapret2.

Keenetic Zapret Smart Control (KZSC) v0.11.2.6-generic

KZSC, Keenetic üzerinde çalışan bağımsız çok-WAN DPI, Zapret2, Blockcheck, güvenli DNS,
Telegram bildirim ve yedekleme yönetim uygulamasıdır.

Mimari
- Uygulama kökü: /opt/kzsc
- CLI: kzsc
- Servis: /opt/etc/init.d/S99kzsc
- Web paneli: varsayılan 9090/TCP (LAN)
- Zapret2: /opt/kzsc/zapret2 altında KZSC tarafından yönetilir
- DPI queue aralığı: 320-399
- Firewall zincirleri: KZSC<queue>I / KZSC<queue>O
- WAN registry: /opt/kzsc/var/dpi/wan-registry
- Olay Günlüğü: /opt/kzsc/var/log/operation-log.ndjson
- KZSC yedekleri: /opt/kzsc/var/backups
- DNS snapshotları: /opt/kzsc/var/dns/backups

Temel özellikler
- 1/N internet WAN keşfi ve kullanıcı dostu bağlantı adları
- WAN bazlı DPI profil seçimi, motor başlatma/durdurma ve self-heal
- KZSC tarafından yönetilen Zapret2 kurulum/güncelleme/onarım/kaldırma
- WAN bazlı Blockcheck ve güvenli NFQUEUE izolasyonu
- Cloudflare, Google, Quad9 ve AdGuard için DoT/DoH yönetimi
- DNS temiz kurulum, snapshot ve ISS DNS yok sayma
- Telegram Bot bildirimleri ve test/Chat ID işlemleri
- KZSC ayar yedeği, indirme, Telegram'a gönderme, geri yükleme ve silme
- Kalıcı Olay Günlüğü
- Türkçe / English arayüz


v0.11.2.6-generic sağlamlaştırma / audit
- KeenDNS Adresi Kopyala ve Paneli Aç kullanıcı aksiyonları Olay Günlüğü'ne kaydedilir.
- Olay Günlüğü temizlendiğinde temizleme işlemi ilk yeni kayıt olarak bırakılır.
- AUTO Blockcheck profilleri bakım kuyruğunda ilgili WAN'a ait olmak şartıyla kabul edilir; yabancı AUTO profil reddedilir.
- Zapret2 işlemleri yalnız kendi butonlarını geçici kilitler; diğer UI butonlarının disabled durumu bozulmaz.
- Eski tamamlanmış Blockcheck sonuçları tarayıcı açılışında yeniden bildirim olarak gösterilmez.
- Cihaz rolü Türkçe Genişletici / English Extender olarak tutarlı gösterilir.
- `kzsc audit [buttons|code|runtime|full]` kapsamlı buton, kaynak, standalone ve runtime denetimi eklendi.
- `kzsc purity-check` KZSC-owned kaynakta eski ürün kimliği/yolu/bağımlılığı arar; resmi upstream Zapret2 ağacı hariç tutulur.
- Kurulum bilinen eski ürün dosya yollarını tekrar temizler ve güncel bin/CGI allow-list uygular.
- Kurulum KZSC root, www, etc, share, bin ve CGI için allow-list uygular; var runtime state ile resmi upstream Zapret2 ağacı dışında eski uygulama ağaçlarının kalmasına izin vermez.
- Native DPI `check-all` ile enabled motorların process + tam datapath bütünlüğü read-only doğrulanır.
- Dinamik WAN kimliği kalktığında stale Blockcheck CGI, engine, Blockcheck state, AUTO profil ve per-WAN doğrulama kaydı temizlenir.
- KZSC-owned Zapret2 durum/log dosyaları `zapret2-status.json` ve `zapret2.log` adlarına taşındı; eski generic status/log adı upgrade sırasında temizlenir.

Yerleşik DPI profilleri
- TURK TELEKOM (TT)
- SUPERONLINE (SOL)
- KABLONET (TÜRKSAT)

Blockcheck izolasyonu
- Aktif DPI varken hedef WAN'ın interface-scope hook kuralları geçici olarak askıya alınır.
- NFQUEUE özel zincirde olsa bile ona ulaşan -i/-o WAN hook'u üzerinden güvenli izolasyon yapılır.
- Başka bir interface-scope dışı NFQUEUE yolu tespit edilirse güvenlik için test engellenir.
- Test bitince veya kesilince snapshot kuralları aynı sırayla geri yüklenir.

Tanı
  kzsc diag
  kzsc ui-selftest
  kzsc purity-check
  kzsc engines status
  kzsc blockcheck status
  kzsc dns status
  kzsc telegram status
  kzsc backup status
  kzsc zapret2 status

v0.11.2.6-generic
- Telegram bildirimlerinde metin içindeki literal `\n` sorunu düzeltildi; başlık ve içerik artık gerçek satır sonlarıyla gösterilir.
- Varsayılan WAN reconcile bildirimi teknik PPPoE0/PPPoE1 yerine canlı Keenetic bağlantı adlarını gösterir.
- WAN değişimi sırasında kısa süreli DNS/rota kesintisinde Telegram sendMessage için tek transport retry eklendi.
- Reconcile bildirimlerinde `new_wan`, `binding_changed`, `profile_missing` ve sonuç kodları kullanıcı dostu Türkçe metinlere çevrilir.
- Genel Bakış'taki "WAN Otomatik Reconcile" kartı otomatik izleme durumu, varsayılan WAN, bekleyen doğrulama sayısı, son WAN değişikliği ve son otomatik DPI doğrulamasını gösterir.
- Reconcile backend son WAN değişikliğini ve son başarılı otomatik doğrulamayı kalıcı olarak saklar ve /www/data/reconcile.json üzerinden yayınlar.
- v0.11.2.0'dan yükseltmede mevcut validated kayıtları ve Olay Günlüğü kullanılarak görünürlük geçmişi otomatik bootstrap edilir.
- Telegram WAN bildirimleri reconcile olayları için ayrıştırıldı: Varsayılan WAN Değişti, WAN Değişikliği Algılandı ve WAN Profili Doğrulandı başlıklarıyla net bildirim gönderilir.
- Olay Günlüğü'nde wan_reconcile eylemi kullanıcı dostu "WAN Otomatik Reconcile" adıyla gösterilir.
- v0.11.2.0'ın WAN topology reconcile, preset-first doğrulama, broad Blockcheck/AUTO fallback ve reboot persistence davranışları korunur.

v0.11.2.0-generic
- Keenetic WAN topology reconcile eklendi: varsayılan bağlantı, PPPoE/ppp eşlemesi ve yeni/yeniden bağlanan WAN'lar otomatik izlenir.
- Linux PPP interface artık yalnız PPPoE sıra numarasından varsayılmaz; live IPv4 eşleşmesinden çözülür, numara eşlemesi yalnız fallback'tir.
- ISP/bağlantı etiketi canlı Keenetic açıklamasından alınır; eski interface-numarası haritalarının yanlış profile yol açması engellenir.
- Varsayılan WAN değiştiğinde cihaz/policy eşlemeleri otomatik yenilenir; bilinen WAN sırf öncelik değişti diye gereksiz Blockcheck'e girmez.
- Yeni veya yeniden bağlanan WAN'da eski KZSC NFQUEUE bağı temizlenir ve otomatik preset-first Blockcheck başlatılır.
- Presetlerden çalışan bulunursa doğrulanan preset otomatik uygulanır ve DPI motoru onunla devam eder.
- Hiçbir preset yeterli olmazsa mevcut geniş Blockcheck akışı otomatik devreye girer; başarılı nfqws2 sonucu yeni AUTO profile dönüştürülüp uygulanır.
- Aynı anda birden çok WAN değişirse Blockcheck işleri mevcut güvenli seri kuyruğa alınır.
- Başarısız otomatik doğrulamalar configurable retry süresiyle yeniden denenebilir; varsayılan 6 saattir.
- CLI: `kzsc reconcile status|refresh|baseline`.
- v0.11.1.13'teki kısa dosya adıyla backup restore davranışı korunur.

v0.11.1.13-generic
- CLI restore artık yalnız tam yol değil, doğrudan yedek dosya adını da kabul eder.
- `kzsc backup restore kzsc-backup-YYYYMMDD-HHMMSS.tar.gz` otomatik olarak /opt/kzsc/var/backups altında çözülür.
- Full-path ve web upload restore akışları geriye uyumlu olarak korunur.
- Backup MANIFEST ve maintenance sürüm metadatası güncel paket sürümüyle eşitlendi.
- UI self-test'e restore dosya adı çözümleme kontrolü eklendi.


v0.11.1.12-generic
- Blockcheck code 30 hatasına neden olan NFQUEUE izolasyon modeli düzeltildi.
- Özel KZSC NFQUEUE zincirleri artık yanlışlıkla interface-scope dışı kural sayılmaz.
- İzolasyon doğrudan NFQUEUE satırını değil, hedef WAN'dan NFQUEUE zincirine ulaşan hook'u snapshotlar.
- Blockcheck preflight artık gerçek izolasyon hata nedenini UI'a aktarır.
- Dağıtım paketindeki kullanılmayan eski CGI kaynakları kaldırıldı.
- Runtime purity/sanitize kodu yalnız güncel KZSC tree invariantlarını denetleyecek şekilde sadeleştirildi.
- README sürüm geçmişi temizlenip güncel ürün dokümantasyonuna dönüştürüldü.


v0.11.1.1
- Multi-WAN Blockcheck requests are serialized in a safe queue; upstream temporary global NFQUEUE rules are never shared by concurrent WAN tests.
- Working nfqws2 strategies found by Blockcheck are converted to per-WAN AUTO BLOCKCHECK profiles and applied automatically.
- Every day at 04:00 local router time, all Internet WANs are queued for a quick Blockcheck and successful strategies are auto-applied.
- Auto-generated per-WAN profiles are included in KZSC backups.


v0.11.1.12-generic
- Gece otomatik Blockcheck varsayılan olarak kapatıldı.
- Auto profil adı WAN başına sabit; başarılı yeni test aynı dosyanın üzerine yazar.
- Auto profiller WAN DPI profil seçicisinde görünür.
- Blockcheck gerçek tamamlanan test sayısını gösterir; upstream toplamı dinamik olduğunda yanlış kalan sayı uydurmaz.
- Genel Bakış KZSC kartı sürüm, mimari, router ve KeeneticOS bilgilerini gösterir; DPI ayrıntıları WAN kartlarındadır.
- KeenDNS alan adı otomatik keşfi ve kzsc.<domain> uzaktan erişim aç/kapat eklendi; domain değişikliği otomatik izlenir.


v0.11.1.12-generic Blockcheck stabilization
- Tek Blockcheck modu; UI tarama modu seçenekleri kaldırıldı.
- KZSC hard timeout: 1800 saniye (30 dakika).
- Timeout/manuel stop upstream child nfqws2 ve blockcheck2 süreçlerini temizler.
- NFQUEUE restore idempotent ve değişen chain uzunluğuna dayanıklı hale getirildi.
- Upgrade sırasında eski orphan blockcheck süreçleri ve yalnız upstream blockcheck_* zincirleri temizlenir.
- Gece otomatik Blockcheck kapalı kalır.


v0.11.1.12-generic
- KeenDNS discovery adds my.keenetic.net redirect fallback because KeenDNS booking may live cloud-side rather than running-config.
- Queued Blockcheck jobs show no elapsed counter; the counter starts from 00:00 only when that WAN becomes the active Blockcheck job.
- Optional Telegram command control added; only configured Chat ID is accepted and commands are allow-listed.


v0.11.1.12-generic
- Telegram WAN management uses live Keenetic connection labels instead of PPPoE0/PPPoE1 in user-facing commands and status.
- /help dynamically lists current connection names; renamed connections are picked up automatically.
- Queued WAN Blockcheck elapsed time stays blank and begins only when the queued job actually starts.

v0.11.1.12-generic preset-first Blockcheck
- Blockcheck first validates built-in KZSC presets, with the ISP-recommended preset first.
- A preset is sufficient only when HTTP and HTTPS/TLS reachability both succeed for every configured Blockcheck target.
- If a preset is sufficient, broad upstream strategy scanning is skipped and the verified preset is used according to auto-apply policy.
- If no preset is sufficient, the original WAN profile/state is restored before normal broad Blockcheck scanning begins.
- Existing per-WAN AUTO profile is also tried after built-in presets when present.
- The 30-minute hard limit remains the safety ceiling for the broad scan.


v0.11.1.12-generic runtime cleanup/reconcile
- Blockcheck stop/timeout now kills re-parented per-WAN run-tree children and removes temporary blockcheck_* mangle chains.
- Stop resets stale elapsed/result state before returning WAN to idle.
- Native DPI ensure validates queue chains plus INPUT/FORWARD/POSTROUTING WAN hooks, and recovers stale isolation markers before reconcile.
- Retains preset-first early-exit flow, dynamic Telegram WAN names, and KeenDNS work.


v0.11.1.12-generic Telegram UX
- /status ham JSON yerine kısa insan-okur özet verir.
- /dpi ve /blockcheck dinamik WAN adlarıyla inline yönetim butonları gönderir.
- Telegram callback_query + answerCallbackQuery desteği eklendi.
- /help ve /status ana menü butonlarıyla gelir.
- WAN Telegram bildirimlerinde teknik PPPoE/NDMC kimliği gösterilmez.

v0.11.1.12-generic Telegram polish
- Telegram DPI/Blockcheck buttons shortened to avoid mobile truncation.
- WAN connection label is shown on its own button row; action buttons remain compact.
- Telegram engine/Blockcheck states are human-readable Turkish labels.
- Blockcheck result preset_verified is shown as "Preset doğrulandı" and profile_found as "Profil bulundu".

v0.11.1.12-generic Telegram callback authorization fix
- Inline callback authorization now validates callback_query.message.chat.id against configured TG_CHAT_ID.
- callback_query.from.id is logged for audit but is not confused with the configured chat target.
- Fixes callbacks being rejected when the configured Telegram chat ID differs from the clicking user ID.


v0.11.2.3: Final TR/EN UI translation audit; explicit bilingual global operation notices in English mode; Event Log dynamic message/date localization; missing Overview/KeenDNS/Backup translations completed.


v0.11.2.4: KeenDNS Copy Address now works on the local HTTP panel using a clipboard fallback, with visible TR/EN success/error notices.
