# KZSC v0.11.2.57-generic

## Türkçe

- Kaldırıp yeniden kurulum sonrasında oluşabilen geçici `profile_set_*.cgi` eksikliği düzeltildi.
- Daemon ile kurulum sonrası denetim aynı anda profil uç noktalarını yenilerken denetim artık güvenli şekilde yeniden üretip tekrar dener.
- Yeniden kurulum denetimi, geçici yarış koşulunu kurulum hatası olarak raporlamaz.

## English

- Fixed transient missing `profile_set_*.cgi` endpoints after remove-and-reinstall.
- When the daemon refreshes generated profile endpoints during the post-install audit, the audit now safely regenerates and retries them.
- Reinstallation no longer reports a harmless publication race as an installation failure.
