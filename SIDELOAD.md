# Trying ParkCast from Windows

There are two different test paths:

1. **Private Safari player over Tailscale:** usable remotely now, without signing. This tests video playback and Safari's AirPlay controls. It is not the native app and does not create a CarPlay home-screen icon.
2. **Native iPhone app:** build an ARM64 `.ipa` on a Mac/cloud macOS runner, then sign/install it with your own Apple account. The source ZIP is not an IPA. Tailscale does not replace Apple's signature or device pairing.

## Native build

The manual GitHub Actions workflow `.github/workflows/ios-build.yml` runs the Swift core tests, compiles the ordinary ParkCast device target, and uploads `ParkCast-unsigned.ipa` for local signing. It needs no Apple credentials or signing secrets. It does not build the entitlement-restricted CarPlay target.

The workflow runs only when dispatched. Private repositories can consume included Actions usage and incur charges beyond it; standard hosted runners in public repositories are free. Do not publish this source publicly without the owner's approval.

On a Mac, the same build can be run with:

```sh
bash scripts/build-ipa.sh
```

## First installation from Windows

Use [Sideloadly](https://sideloadly.io/) or [AltStore Classic](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows). Both require Apple-device connectivity and your own Apple account. Enter passwords/2FA directly in the tool, never in this repository or a chat.

For Sideloadly:

1. Install its Windows version and the Apple device components required by its current setup instructions.
2. Connect and unlock the iPhone by USB and tap Trust when prompted.
3. Select the phone and load `ParkCast-unsigned.ipa`.
4. Sign in directly in Sideloadly and install.
5. On the iPhone, trust your developer profile under Settings → General → VPN & Device Management, and enable Developer Mode if prompted.
6. Launch ParkCast and run the known video test while parked.

The vendor supports free Apple accounts with 7-day signing validity; automatic refreshing still requires the relevant PC/device connectivity. A first-time remote installation is not promised. If AltStore/SideStore is already installed and configured on the phone, its existing workflow may provide another installation path.

Downloading an unsigned IPA in Safari cannot install it. The optional CarPlay entitlement is not granted by using a sideloading tool. Netflix/Disney+ compatibility and the Sierra's video support remain unverified.

## Private Safari test server

```powershell
node try/server.cjs
tailscale serve --bg --https=8450 http://127.0.0.1:4191
```

This binds the app server only to local loopback and exposes it through Tailscale Serve. It does not enable public Funnel. Check existing Serve ports before selecting a port; do not overwrite other services.

Keep this PC awake and Tailscale connected on the iPhone. Use the HTTPS address returned by Serve in Safari. The test page does not upload selected local videos. The protected streaming services open separately in Safari and are not proxied or embedded.

To remove only this test route:

```powershell
tailscale serve --https=8450 off
```

Stop the Node process started for `try/server.cjs`; do not stop unrelated Node processes or reset all Tailscale Serve configuration.
