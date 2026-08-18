# GitHub Yayın Planı / GitHub Publication Plan

## Depo bilgileri / Repository metadata

- Owner: `ssy1979`
- Repository: `ssy1979/keenetic-zapret-smart-control`
- Repository name: `keenetic-zapret-smart-control`
- Description: `Keenetic için uyarlamalı Zapret2, DPI, Blockcheck ve güvenli DNS yönetimi · Adaptive Zapret2, DPI, Blockcheck and secure DNS management for Keenetic`
- Visibility: `Public`
- Default branch: `main`
- Git commit identity: `ssy1979 <sinan@sinanyener.com>`
- Topics: `keenetic`, `zapret2`, `dpi`, `blockcheck`, `multi-wan`, `pppoe`, `ipoe`, `wisp`, `entware`, `busybox`, `nfqueue`, `dot`, `doh`, `self-update`

## Yeni release / New release

- Tag: `v0.11.2.21-generic`
- Title: `KZSC v0.11.2.21-generic · Cihaz Politikası ve Hazırlayıcı / Device Policy & Preparer`
- Notes: [RELEASE_NOTES_v0.11.2.21.md](RELEASE_NOTES_v0.11.2.21.md)
- Assets:
  - `keenetic-zapret-smart-control-v0.11.2.21-generic.tar.gz`
  - `keenetic-zapret-smart-control-v0.11.2.21-generic.tar.gz.sha256`
  - `KZSC-Hazirlayici-v1.2.5.zip`
  - `KZSC-Hazirlayici-v1.2.5.zip.sha256`

## Yayın kapısı / Publication gate

Yayın yalnız şu koşulların tümü sağlandığında yapılır / Publish only when all conditions pass:

1. Tüm shell syntax kontrolleri / all shell syntax checks.
2. 1–4 WAN adaptive test suite, secure updater test suite, and repository ownership contract.
3. 35-test Windows Preparer regression suite and reproducible PyInstaller build.
4. Source checksum manifest plus independent SHA-256 files for router and Windows assets.
5. Secret, personal path, runtime state, and retired-residue scans.
6. Extracted router archive compared with source and tested again; `docs/` and `tools/` remain repository-only.
7. Live pre-flight, installation, `kzsc audit full`, and web CGI validation on the reference Keenetic.
8. MIT license present and explicit owner approval to publish.
