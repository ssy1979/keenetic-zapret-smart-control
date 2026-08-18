# KZSC v0.11.2.19-generic

## Türkçe

- WAN başına bağımsız **Tüm Ağ** ve **Otomatik** Zapret çalışma modları eklendi.
- Otomatik mod, Zapret2'nin DPI engeli olasılığı algılamasıyla alan adlarını WAN'a özel listeye ekler. Listeler panelden elle düzenlenebilir.
- Her WAN için ayrı Zapret hariç tutma listesi eklendi. `*.gov.tr` biçimi kabul edilir ve alt alan adlarını kapsayan Zapret sonek biçiminde saklanır.
- Cihazlar bölümünde cihaz bazında Zapret açma/kapatma eklendi. Kapalı cihazın trafiği kendi WAN zincirinde NFQUEUE'ye girmeden geçer.
- MAC adresinin değişebilmesi uyarısı ve cihaz başına kullanıcı seçilebilir **Keenetic DHCP sabit IP rezervasyonu** eklendi. IP, çakışma denetiminden sonra Keenetic yapılandırmasına yazılır; cihazın sonraki DHCP yenilemesinde uygulanır.
- Yeni politika ve rezervasyon verileri güvenli KZSC yedekleme/geri yükleme akışına eklendi.
- Çoklu WAN, tek WAN, IPoE ve WISP keşif yoluyla aynı mantıkta çalışır.

## English

- Added independent per-WAN **All Network** and **Automatic** Zapret operating modes.
- Automatic mode uses Zapret2 likely-DPI-block detection to append domains to a WAN-specific list. Lists can be edited manually in the panel.
- Added a separate per-WAN Zapret exclusion list. `*.gov.tr` is accepted and stored in Zapret suffix form covering subdomains.
- Added per-device Zapret on/off in Devices. A disabled device bypasses NFQUEUE in its own WAN chain.
- Added a MAC-change warning and an opt-in **Keenetic DHCP static-IP reservation** per device. The IP is collision-checked and written to Keenetic configuration; it takes effect on the next DHCP renewal.
- Included policy and reservation data in the secure KZSC backup/restore flow.
- The same discovery-driven behavior works for multi-WAN, single-WAN, IPoE, and WISP topologies.
