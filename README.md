<p align="center">
  <img src="docs/images/kzsc-genel-bakis-en.png" alt="KZSC router panel" width="820">
</p>

<h1 align="center">Keenetic Zapret Smart Control</h1>

<p align="center">The simple way to install and manage Zapret2 on a Keenetic router.</p>

<p align="center">
  <a href="https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest"><img src="https://img.shields.io/github/v/release/ssy1979/keenetic-zapret-smart-control?display_name=tag&style=for-the-badge&color=2ea44f" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-7c3aed?style=for-the-badge" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/KeeneticOS-supported-0ea5e9?style=for-the-badge" alt="KeeneticOS">
</p>

<p align="center"><a href="README.tr.md">🇹🇷 Türkçe rehber</a> · <strong>🇬🇧 English guide</strong></p>

> [!IMPORTANT]
> **First installation? Use KZSC Preparer on Windows.** It is the recommended, no-terminal route.

<!-- KZSC_PREPARER_START: Windows preparer contract -->
## Which part do I need?

| You want to… | Use this |
| --- | --- |
| Install KZSC for the first time from a Windows PC | **KZSC Preparer** |
| Manage Zapret2, DNS, WANs, devices and updates afterwards | **KZSC Router Panel** |
| Install without a Windows PC | [Manual fallback](docs/INSTALLATION.md#manual-fallback) |

## Install in 4 easy steps

1. On the router, enable the **SSH server** component in **General system settings → Component options**. Keep SSH local-only.
2. Open the [latest release](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest), download **`KZSC-Hazirlayici-*.zip`**, and extract the whole ZIP.
3. Open `KZSC-Hazirlayici.exe`, enter the router administrator credentials, then select **Connect and analyse**.
4. Read the plan and select **Apply plan**. When it says complete, open `http://ROUTER_IP:9090/`.

![KZSC Preparer start screen](docs/images/kzsc-hazirlayici-baslangic-en.png)

**That is all.** The preparer checks compatibility, prepares OPKG/Entware if needed, and installs KZSC. It does not format disks or save passwords.

For every screen and common question, use the [visual installation guide](docs/INSTALLATION.md).
<!-- KZSC_PREPARER_END -->

## After installation

Open the panel at `http://ROUTER_IP:9090/` from your local network.

| Page | What to do there |
| --- | --- |
| **Overview** | Confirm that KZSC and your WANs are healthy. |
| **Zapret2 / DPI** | Enable and tune filtering. |
| **Devices** | Include or exclude online and registered offline devices. Choices are stored by MAC address. |
| **Updates** | Check and install verified releases. |

![KZSC update page](docs/images/kzsc-guncelleme-en.png)

## Before you begin

- Computer and router must be on the same local network.
- You need the router administrator username and password.
- The router needs an Internet connection.
- For a new Entware installation, connect a supported EXT2/EXT3/EXT4 USB partition or use supported internal storage.

The preparer validates the actual router before changing it. It supports compatible PPPoE, IPoE/Ethernet and WISP connections; unsupported setups are shown in the plan instead of being silently changed.

## Need help?

- [Visual installation guide](docs/INSTALLATION.md)
- [Turkish guide](docs/KURULUM.md)
- [Release notes](RELEASE_NOTES_v1.0.6.md)
- [Security policy](SECURITY.md)

Do not publish router passwords, Telegram tokens, backups, public IPs or KeenDNS addresses in an issue. KZSC is an independent community project, not an official Keenetic or Zapret2 product.
