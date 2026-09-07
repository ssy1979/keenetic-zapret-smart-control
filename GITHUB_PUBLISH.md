# GitHub publication gate / GitHub yayın kapısı

Repository: `ssy1979/keenetic-zapret-smart-control`
Release: `v1.0.0-generic`
Windows preparer: `KZSC-Hazirlayici-v1.0.0.zip`

Publication is allowed only after the complete source manifest, router-only archive readback, shell/Python regression suites, Windows packaged TR/EN offline smoke test, and independent SHA-256 checks pass. The release workflow refuses to overwrite an existing release.

The router archive intentionally excludes `docs/` and `tools/`; both remain in the GitHub source tree. External application files, caches, and processes are never removed automatically. A live Keenetic test is capability- and WAN-dependent; automated checks do not claim every model or ISP has been physically tested.

Use the bilingual visual guides in `docs/KURULUM.md` and `docs/INSTALLATION.md`. For a v1.0.0-generic audit failure, retry with the new preparer while preserving the existing Entware `/opt`; do not factory-reset or format storage.
