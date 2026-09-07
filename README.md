<p align="center">
  <a href="https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest">
    <img src="docs/images/kzsc-genel-bakis-en.png" alt="KZSC web panel preview" width="820">
  </a>
</p>

<h1 align="center">Keenetic Zapret Smart Control</h1>

<p align="center">
  Adaptive Keenetic router management for Zapret2, per-WAN DPI, secure DNS, Blockcheck, Telegram, backups, and safe updates.
</p>

<p align="center">
  <a href="https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest"><img src="https://img.shields.io/github/v/release/ssy1979/keenetic-zapret-smart-control?display_name=tag&style=for-the-badge&color=2ea44f" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-7c3aed?style=for-the-badge" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/platform-KeeneticOS-0ea5e9?style=for-the-badge" alt="KeeneticOS">
  <img src="https://img.shields.io/badge/interface-TR%20%7C%20EN-f97316?style=for-the-badge" alt="Turkish and English interface">
</p>

<p align="center">
  <a href="README.tr.md">🇹🇷 Türkçe</a> · <strong>🇬🇧 English</strong>
</p>

<p align="center">
  <a href="#recommended-assisted-installation">🚀 Quick start</a> ·
  <a href="docs/INSTALLATION.md">📘 Installation guide</a> ·
  <a href="#manual-windows-option">🛠️ Manual install</a> ·
  <a href="#kzsc-updates">🔄 Updates</a> ·
  <a href="SECURITY.md">🛡️ Security</a>
</p>

> [!IMPORTANT]
> **New to KZSC?** Start with the Windows **KZSC Preparer** below. It checks the router, prepares the required base, and installs KZSC through a guided flow.

### At a glance

| Component | What it does |
| --- | --- |
| **KZSC Preparer** | Windows setup assistant for KeeneticOS components, OPKG/Entware, and first KZSC installation. |
| **KZSC Router Panel** | Bilingual web UI for WAN/DPI, Zapret2, DNS, Blockcheck, Telegram, backups, and updates. |
| **Safety first** | Read-only compatibility checks, verified releases, and automatic rollback if an update fails. |

---

KZSC is a capability-driven management layer for Zapret2, per-WAN DPI, Blockcheck, secure DNS, Telegram notifications, backups, and a bilingual Turkish/English web panel on Keenetic routers. The **KZSC Preparer** in this same project builds the required KeeneticOS/OPKG/Entware base from Windows; secure DNS is configured by KZSC after installation.


Current release: `v1.0.0-generic`


<!-- KZSC_PREPARER_START: Keep this block when updating release documentation. -->
## Recommended assisted installation


![KZSC installation flow](docs/images/kurulum-akisi-en.svg)


1. Open the [latest GitHub Release](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest).
2. Download and fully extract `KZSC-Hazirlayici-v1.0.0.zip` from Assets.
3. Run `KZSC-Hazirlayici.exe`.
4. Discover the Keenetic and analyze it with the SSH 22 administrator credentials.
5. Choose the USB/internal storage target (DNS and WAN options are managed by KZSC after installation).
6. Review and apply the plan. The preparer completes Entware SSH 222 and installs KZSC.
7. Open `http://ROUTER_IP:9090/` after installation.


For first-time users, see the complete visual walkthrough: **[KZSC visual installation guide](docs/INSTALLATION.md)**. A detailed Turkish guide is available in [docs/KURULUM.md](docs/KURULUM.md).



### The two parts of the project


- **Windows: KZSC Preparer** — network discovery, SSH 22 analysis, missing KeeneticOS components, USB/internal OPKG, Entware SSH 222, and automatic KZSC installation. It leaves DNS unchanged.
- **Router: KZSC** — the `/opt/kzsc` web panel, WAN/DPI/Blockcheck, Zapret2 management, DNS, Telegram, backup, and secure updates.


Preparer source: [`tools/kzsc-hazirlayici`](tools/kzsc-hazirlayici)
<!-- KZSC_PREPARER_END -->


## Manual Windows option


Windows users who do not want to use the preparer can install KZSC from PowerShell with the OpenSSH Client: upload the verified release archive to `/opt/tmp` using `scp -P 222`, connect with `ssh -p 222 root@ROUTER_IP`, install the required Entware packages, and run `/opt/bin/sh install.sh`. The complete bilingual procedure is in the [manual installation guide](docs/INSTALLATION.md).


## Supported router topology


The installer does not approve routers by a hard-coded model list. It validates the actual router before changing an existing installation:


- KeeneticOS Open Package support and Entware under `/opt`
- `dns-tls` and `dns-https` KeeneticOS components
- lighttpd with `mod_cgi`
- iptables mangle/filter, NFQUEUE, and queue bypass support
- a compatible Zapret2 CPU binary that executes successfully on the device
- one or more supported Internet uplinks


Supported uplinks are PPPoE, wired IPoE/Ethernet (DHCP or static, public or private IPv4 from an upstream router), and Keenetic WISP. L2TP/PPTP and mobile/USB modem WANs are intentionally outside the current release scope.


Models such as KN-1811, KN-1812, KN-1012, KN-3610, and KN-3611 are handled by the same discovery path. A model is compatible only when the on-device pre-flight passes; this avoids making an unverified model-name promise.
