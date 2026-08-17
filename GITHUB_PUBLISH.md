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

## İlk release / First release

- Tag: `v0.11.2.14-generic`
- Title: `KZSC v0.11.2.14-generic · Uyarlamalı Keenetic Desteği / Adaptive Keenetic Support`
- Notes: [RELEASE_NOTES_v0.11.2.14.md](RELEASE_NOTES_v0.11.2.14.md)
- Assets:
  - `keenetic-zapret-smart-control-v0.11.2.14-generic.tar.gz`
  - `keenetic-zapret-smart-control-v0.11.2.14-generic.tar.gz.sha256`

## Yayın kapısı / Publication gate

Yayın yalnız şu koşulların tümü sağlandığında yapılır / Publish only when all conditions pass:

1. Tüm shell syntax kontrolleri / all shell syntax checks.
2. 1–4 WAN adaptive test suite and secure updater test suite.
3. Source checksum manifest.
4. Secret, personal path, runtime state, and retired-residue scans.
5. Extracted archive compared with source and tested again.
6. Live pre-flight, installation, `kzsc audit full`, and web CGI validation on the reference Keenetic.
7. MIT license present and explicit owner approval to publish.
