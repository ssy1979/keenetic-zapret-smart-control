# KZSC visual installation guide

[← Project home](../README.md) · [🇹🇷 Türkçe rehber](KURULUM.md) · [Latest release](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest)

> [!TIP]
> This guide uses **KZSC Preparer**, the easiest and recommended Windows installation method. You do not need to enter terminal commands.

## What you need

- A Windows 10/11 PC and your Keenetic router on the same local network.
- The router administrator username and password.
- A working Internet connection on the router.
- For a new Entware installation: supported internal storage or an attached EXT2/EXT3/EXT4 USB partition.

## Step 1 — Enable SSH on the router

In the Keenetic web interface, open **General system settings → Component options** and install or enable **SSH server**. Keep it reachable only from the local network.

This is the only router-side preparation required before starting the preparer.

## Step 2 — Download and open KZSC Preparer

1. Open the [latest release](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest).
2. Under **Assets**, download `KZSC-Hazirlayici-*.zip`.
3. Right-click the ZIP and choose **Extract all**.
4. Open the extracted folder and run `KZSC-Hazirlayici.exe`.

> [!IMPORTANT]
> Keep `KZSC-Hazirlayici.exe` and its `_internal` folder together. Do not move the EXE on its own.

## Step 3 — Connect and analyse

![KZSC Preparer connection screen](images/kzsc-hazirlayici-baslangic-en.png)

1. Pick your language.
2. Select the found router, or enter its local IP address (often `192.168.1.1`).
3. Enter the Keenetic administrator credentials in **KeeneticOS SSH (22)**.
4. Select **Connect and analyse**.
5. Confirm the SSH fingerprint only if it belongs to your own router.

The app checks the router before making changes. Passwords are not saved.

## Step 4 — Choose storage and create the plan

![KZSC Preparer installation options](images/kzsc-hazirlayici-kurulum-secenekleri-en.png)

Choose the storage shown by the app:

- **Existing Entware /opt**: keeps an already working Entware installation.
- **USB partition**: only detected EXT2/EXT3/EXT4 partitions are offered.
- **Internal storage**: shown only on compatible routers.

Leave **Install latest KZSC release automatically** enabled, then open **Plan and install** and choose **Create installation plan**.

## Step 5 — Apply the plan

![KZSC Preparer plan screen](images/kzsc-hazirlayici-plan-en.png)

Check that the router and storage target are correct, then choose **Apply plan**.

The preparer installs only what is missing, may restart the router if KeeneticOS components must change, then installs KZSC and verifies it. Do not turn off the router or close the app while the plan is running.

## Step 6 — Open KZSC

When the plan is complete, open this address on your local network:

```text
http://ROUTER_IP:9090/
```

Example: `http://192.168.1.1:9090/`

![KZSC dashboard](images/kzsc-genel-bakis-en.png)

On the **Overview** page, confirm that KZSC and your WANs are healthy. Then configure Zapret2/DPI, DNS and devices as needed.

## Common questions

### The router was not found

Make sure the PC is on the main local network, temporarily disable a client VPN, then enter the router’s local IP manually. Guest Wi-Fi can block router management.

### SSH 22 cannot connect

Confirm that the KeeneticOS **SSH server** component is enabled, the administrator credentials are correct, and the router’s local SSH port is 22. Do not expose SSH to the Internet.

### USB storage is not displayed

The preparer never formats a disk. Check that the partition is EXT2, EXT3 or EXT4 and that KeeneticOS sees it as connected.

### The panel does not open

Use the local address `http://ROUTER_IP:9090/`. Do not expose the panel directly to the Internet. If the installation report shows an error, save its redacted log and open an issue without passwords or tokens.

## Manual fallback

Use this only when the Windows preparer cannot be used.

1. Prepare a persistent Entware `/opt` target in KeeneticOS and ensure SSH 222 works.
2. Download the router archive and its `.sha256` file from the [latest release](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest), then upload them to `/opt/tmp`.
3. On the router, verify and install:

```sh
cd /opt/tmp
sha256sum -c keenetic-zapret-smart-control-v*-generic.tar.gz.sha256
tar -xzf keenetic-zapret-smart-control-v*-generic.tar.gz
cd keenetic-zapret-smart-control-v*-generic
/opt/bin/sh install.sh
```

The installer checks the actual router capabilities and stops safely when the setup is unsupported.
