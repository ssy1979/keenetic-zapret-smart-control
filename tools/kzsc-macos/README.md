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
- download and verify the release into `~/Downloads/KZSC`;
- prepare the Entware upload/install flow without storing router passwords;
- reconnect after reboot and verify `kzsc status`, `kzsc preflight`, and
  `kzsc audit full`;
- control the installed KZSC instance through its existing responsive panel and
  JSON CGI surface (WAN, DPI, DNS, Zapret2, Blockcheck, Telegram, updates and
  settings).

The app accepts plain HTTP only for private LAN addresses. A public hostname
must use HTTPS (KeenDNS). The complete panel is loaded in `WKWebView`, so the
macOS client does not fork or scrape the KZSC HTML implementation.

The SSH installation step is designed to use the macOS OpenSSH toolchain and an
interactive password prompt (or an already configured SSH key/agent). The app
never puts a router password in a command line, log, preferences file, or
release archive.

The local flow is: verify the port 222 ED25519 key, download the latest release,
prepare the displayed `scp -O`/`ssh` command, run that command in Terminal, then
reconnect to check the router status and full KZSC audit. The app does not run a
hidden password prompt or silently modify the router.

## Build

Open this folder in Xcode on macOS 13 or newer and run the `KZSCMacOS` scheme.
This Windows workspace cannot run Xcode or SwiftUI, so only source-level
validation can be performed here. No GitHub push is performed by this task.

If App Sandbox is enabled in Xcode, enable the **Outgoing Connections (Client)**
network capability. No incoming listener or router-side service is created by
the macOS app.
