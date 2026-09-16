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

### A. Prepare a persistent `/opt` target

This section uses only the KeeneticOS web interface. Connect your computer to the router’s local network and open `http://my.keenetic.net` or the router IP (for example, `http://192.168.1.1`) in a browser.

1. Open **Management → General system settings → Component options**.
2. Install **Open Package support (OPKG)**. The **SSH server** component must also be installed and enabled.

![KeeneticOS component options for OPKG](https://support.keenetic.com/asset/images/uuid-3a0506eb-881c-a993-eef9-c1bacce647c9.png)

3. Connect an USB drive; EXT4 is preferred. It must appear under **Storages & Devices**; older interfaces show it at **Applications → USB devices**.
4. Open **Applications → OPKG Package Manager**. Select that USB partition in the **Drive** field, enable OPKG access for your account, and select **Save/Apply**.

![KeeneticOS connected USB storage](https://support.keenetic.com/asset/images/uuid-214a480a-7b40-9a66-7523-9f68cbbeb167.jpg)

![KeeneticOS OPKG drive selection](https://support.keenetic.com/asset/images/uuid-8a297160-bd75-8450-49bf-c08bf74c7e73.png)

5. Confirm that the selected USB partition is mounted. OPKG mounts that partition persistently at `/opt`. If the router restarts, wait until it is fully online.

> [!IMPORTANT]
> Safely remove the USB drive before unplugging it. Without the drive, `/opt` and KZSC cannot run; reconnect it and wait for the router to detect it.

### B. Verify SSH 222

When the Entware target is mounted, connect to the router’s **SSH 222** service. On Windows, download and install the MSI package from [PuTTY’s official download page](https://www.putty.org/).

In PuTTY, enter the router IP in **Host Name**, set **Port** to `222`, select **SSH**, and choose **Open**. On a first connection, accept the host key only if it is your own router.

The default Entware credentials are:

```text
login as: root
password: keenetic
```

Password characters are not displayed while typing; this is normal. Use your own password if you have changed it. Never expose SSH to the Internet.

Run these four checks in the router session:

```sh
test -x /opt/bin/opkg && echo 'OK: opkg'
test -x /opt/bin/sh && echo 'OK: Entware shell'
test -x /opt/etc/init.d/rc.unslung && echo 'OK: Entware startup'
opkg update
```

The first three commands must each print `OK`; `opkg update` must download package lists without an error. If any check fails, `/opt` is not persistent or SSH 222 is not ready. Stop here, fix the storage target, reboot if necessary, and repeat the checks.

### C. Upload and install KZSC

#### 1) Download the files to your PC

1. Open the [latest release](https://github.com/ssy1979/keenetic-zapret-smart-control/releases/latest).
2. Under **Assets**, download the router archive named `keenetic-zapret-smart-control-v...-generic.tar.gz` and the `.sha256` file with the **same base name**. Keep both files in one folder.
3. Do not extract the archive or rename either file. The `.sha256` file is used for the integrity check.

#### 2) Upload to `/opt/tmp` from the Keenetic interface

The root of the disk chosen for OPKG is `/opt` on the router. Therefore a `tmp` directory created at the disk root in the KeeneticOS file manager is `/opt/tmp` in the terminal.

1. Open the **Applications** page in the Keenetic interface.
2. Select the connected USB drive. The built-in KeeneticOS file manager opens.
3. At the disk root, use the **New folder** icon to create a folder named `tmp`, then open it.
4. Select the **Upload file** icon, choose both downloaded files (`.tar.gz` and `.sha256`), and wait for the upload to complete.

![KeeneticOS built-in USB file manager](https://support.keenetic.com/asset/images/uuid-b7f23f41-a232-db0b-1dd8-45677a0a1425.png)

The `tmp` folder must show exactly two files: the router archive and its matching `.sha256` file. Do not continue if either file is missing or renamed.

#### 3) Verify and install on the router

```sh
cd /opt/tmp
sha256sum -c keenetic-zapret-smart-control-v*-generic.tar.gz.sha256
tar -xzf keenetic-zapret-smart-control-v*-generic.tar.gz
cd keenetic-zapret-smart-control-v*-generic
/opt/bin/sh install.sh
```

The installer checks the actual router capabilities and stops safely when the setup is unsupported.
