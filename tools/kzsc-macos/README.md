# KZSC macOS

This is a local SwiftUI/macOS workstream. It is intentionally separate from
the router code and is not published yet.

> **Testing status:** The macOS application is an early test build. It is not
> yet a supported production release; validate it on a Mac with Xcode before
> using it for router installation or control.

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
needed; the Entware root password is used on SSH 222. Neither password is put
in a command line, log, preferences file, or release archive. The app verifies
the ED25519 key, fetches the newest GitHub release, installs or queues missing
components, waits through a reboot when required, and checks panel access.

## Build

Open this folder in Xcode on macOS 13 or newer and run the `KZSCMacOS` scheme.
This Windows workspace cannot run Xcode or SwiftUI, so only source-level
validation can be performed here. No GitHub push is performed by this task.

The repository also has a **KZSC macOS test app** workflow. It builds an
unsigned, ad-hoc-signed `KZSCMacOS.app` bundle on a GitHub macOS runner and
uploads a ZIP plus SHA-256 sidecar as an Actions artifact. Download the latest
artifact from the workflow, unzip it, then open the app with right-click →
**Open** if Gatekeeper asks for confirmation. This artifact is for feedback
only; it is not notarized or a production release.

If App Sandbox is enabled in Xcode, enable the **Outgoing Connections (Client)**
network capability. No incoming listener or router-side service is created by
the macOS app.
