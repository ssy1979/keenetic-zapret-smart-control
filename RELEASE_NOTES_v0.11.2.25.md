# KZSC v0.11.2.25-generic

## Türkçe

Bu düzeltme sürümü, v0.11.2.24'te kendi kendini hazırlayan kurulum yolunda görülen yanlış durdurmayı giderir.

- Kalıcı yeniden başlatma/kuruluma devam kopyasındaki `kzsc-bootstrap.sh`, çalıştırma biti yerine okunabilirlik açısından doğrulanır; betik zaten `/opt/bin/sh` ile çalıştırılır.
- KeeneticOS bileşen algısı pre-flight ile aynı ayrıştırma kuralını kullanır. Hazır bileşenler nedeniyle gereksiz yeniden başlatma akışı başlatılmaz.
- Bu iki davranış için doğrudan regresyon testleri eklendi.
- İç checksum manifesti güncellendi; GitHub CI, paket üretimi ve release varlığı doğrulamaları zorunlu kalır.

## English

This maintenance release fixes an incorrect stop in the self-preparing installer path introduced by v0.11.2.24.

- The durable reboot/resume copy now validates `kzsc-bootstrap.sh` for readability rather than its executable mode; the script is intentionally run with `/opt/bin/sh`.
- KeeneticOS component detection now uses the same parser as pre-flight, preventing an unnecessary reboot path when components are already present.
- Direct regression coverage was added for both behaviours.
- The internal checksum manifest is refreshed; GitHub CI, package creation, and release-asset verification remain mandatory.
