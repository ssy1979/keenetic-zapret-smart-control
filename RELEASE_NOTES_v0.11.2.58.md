# KZSC v0.11.2.58-generic

## Türkçe

- Yeniden kurulum denetiminde geçici `profile_set_*.cgi` dosyaları artık hata olarak raporlanmaz.
- Yarım kalmış kurulumlardan kalan KZSC NFQUEUE zincirleri güvenli biçimde temizlenir; kalan yabancı referanslar kurulumu engellemez.
- Kullanıcının manuel kaydettiği ve çalışan DPI profili Blockcheck tarafından önce kabul edilir; gereksiz uzun tarama başlatılmaz.

## English

- Transient generated `profile_set_*.cgi` endpoints no longer fail reinstall validation.
- Stale KZSC NFQUEUE chains from interrupted installs are safely cleaned up; foreign references do not block a working install.
- A manually saved, healthy DPI profile is accepted first by Blockcheck instead of starting an unnecessary long scan.
