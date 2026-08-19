# KZSC macOS

This is the SwiftUI/macOS KZSC installer and control application. It is
distributed as a runnable release asset alongside the Windows preparer.

## Scope

- discover Keenetic candidates on the local `/24` network;
- verify SSH ED25519 SHA-256 fingerprints before trusting port 22/222;
- validate the latest trusted KZSC GitHub release and SHA-256 sidecar;
- download and verify the release into a temporary staging directory only when
  installation starts (it is never exposed as a manual download step);
- check and bootstrap Entware through Keenetic SSH 22 when SSH 222 is not yet
  available, then install KZSC directly without storing router passwords;
- reconnect after reboot and verify `kzsc status`, `kzsc preflight`, and
  `kzsc audit full`;
- control the installed KZSC instance through its existing responsive panel and
  JSON CGI surface (WAN, DPI, DNS, Zapret2, Blockcheck, Telegram, updates and
  settings).

The app accepts plain HTTP only for private LAN addresses. A public hostname
must use HTTPS (KeenDNS). The complete panel is loaded in `WKWebView`, so the
macOS client does not fork or scrape the KZSC HTML implementation.

The SSH installation step uses the macOS OpenSSH toolchain inside the app. The
router's Keenetic SSH 22 admin password is used only to bootstrap Entware when
needed; enter the same password used by the Keenetic web panel. Fresh Entware
uses root/`keenetic` by default; change that field only for a custom Entware
password. Neither password is put in a command line, log, preferences file, or
release archive. The app verifies
the ED25519 key, fetches the newest GitHub release, installs or queues missing
components, waits through a reboot when required, and checks panel access.

## Build

Open this folder in Xcode on macOS 13 or newer and run the `KZSCMacOS` scheme.
This Windows workspace cannot run Xcode or SwiftUI, so only source-level
validation can be performed here. No GitHub push is performed by this task.

Release automation builds an ad-hoc-signed `KZSCMacOS.app` bundle on a GitHub
macOS runner and publishes its ZIP plus SHA-256 sidecar with every KZSC
release. Download the macOS ZIP from Release assets, verify its SHA-256, then
open the app with right-click → **Open** if Gatekeeper asks for confirmation.
The bundle is directly usable but is not notarized.

If App Sandbox is enabled in Xcode, enable the **Outgoing Connections (Client)**
network capability. No incoming listener or router-side service is created by
the macOS app.
