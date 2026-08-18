# KZSC v0.11.2.24-generic

## Türkçe

Bu sürüm, farklı bir Keenetic cihazda görülen eksik `lighttpd-mod-cgi`, `iptables` ve `iptables-save` kurulum hatasını giderir.

- Manuel `install.sh`, çalışan OPKG/Entware `/opt` tabanı üzerinde yalnız eksik Entware paketlerini otomatik kurar ve kurulumdan sonra tekrar doğrular.
- Zorunlu `dns-tls`, `dns-https`, `opkg-kmod-netfilter` ve `opkg-kmod-netfilter-addons` KeeneticOS bileşenleri ayrıca denetlenir.
- Eksik KeeneticOS bileşenleri güvenli önizleme sonrasında otomatik uygulanır. Router yeniden başlarsa aynı doğrulanmış kurulum Entware açılış betiğiyle otomatik devam eder.
- Bileşen ve paket adları sabit izin listelerinden gelir; dış depo, rastgele URL veya kullanıcı tarafından verilen komut çalıştırılmaz.
- Kurulum servisleri değiştirmeden önce tam pre-flight kontrolünü yeniden çalıştırır. Başarısız yükseltmelerde mevcut geri yükleme koruması devam eder.
- Yeni regresyon paketi; eksik bileşen algılama, bileşen komut sırası, paket kurulum hatası, tekrar çalıştırma ve kurulum sırasını test eder.

Not: İlk OPKG/Entware depolama seçimi cihaza özgüdür. `/opt` henüz yoksa KZSC Hazırlayıcı veya Keenetic'in resmî OPKG/Entware yöntemi kullanılmalıdır.

## English

This release fixes manual installation failures caused by missing `lighttpd-mod-cgi`, `iptables`, and `iptables-save` on another Keenetic router.

- Manual `install.sh` now installs only missing Entware packages on an existing OPKG/Entware `/opt` base and verifies them afterwards.
- Required `dns-tls`, `dns-https`, `opkg-kmod-netfilter`, and `opkg-kmod-netfilter-addons` KeeneticOS components are checked explicitly.
- Missing KeeneticOS components are applied after a safe preview. If the router reboots, the same verified installation resumes automatically through a temporary Entware startup hook.
- Component and package names come from fixed allowlists; no external repository, arbitrary URL, or caller-provided command is executed.
- The full pre-flight gate runs again before services are changed. Existing rollback protection remains active for failed upgrades.
- A new regression suite covers missing-component detection, component command ordering, package-install failure, idempotency, and installer ordering.

Note: Initial OPKG/Entware storage selection is device-specific. If `/opt` does not exist yet, use KZSC Preparer or Keenetic's official OPKG/Entware installation method.
