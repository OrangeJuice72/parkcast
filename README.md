# ParkCast

A native iPhone video browser and AirPlay player, built as a subscription-free starting point for watching while parked. No paywall, purchases, tracking SDK, server, or third-party runtime dependencies.

**Status: prototype source, not a signed/installable iPhone download.** Written on Windows. Project structure and Swift syntax have been checked; Apple SDK compilation, Swift unit tests, and phone/car playback have **not** been run. The user's 2025 GMC Sierra Denali 2500 HD has not been verified as a video-capable destination. This is not a claim that Netflix, Disney+, or YouTube will play on that screen.

## What is implemented

- Dark SwiftUI interface with Watch, Library, and Connect tabs.
- Built-in WebKit browser with YouTube, Netflix, and Disney+ shortcuts; URL entry; back/forward; reload; bookmarks; and open in Safari. These open the services' real websites, where you sign in yourself.
- Native video player for direct HTTPS MP4/MOV/HLS links and videos imported from Files. Imported videos are copied into app storage so they remain available across launches.
- Apple's AirPlay route picker, native playback controls, Picture in Picture, background audio, lock-screen/remote playback controls, and an Apple test stream.
- Persistent local bookmarks, video library, HTTPS M3U playlist import from a URL or file, duplicate filtering, search, and deletion.
- Connection diagnostics that distinguish audio routing from the native player's actual external video state. Browser casting is explicitly not reported as connected.
- Website login/cookie clearing and a shareable connection report containing no browsing history or account credentials.
- An **optional experimental CarPlay target** with a system-template library and test-stream selection. It needs Apple-approved signing and compatible vehicle support.

## Run it on your iPhone

1. Copy this folder to a Mac with Xcode. The standard `ParkCast` scheme targets **iOS 17+**; use an Xcode version that supports the iOS version on your phone.
2. Open **`ParkCast.xcodeproj`**, not `Package.swift`. The package is only for the portable parser tests.
3. Select the **ParkCast** scheme. Under the ParkCast target's **Signing & Capabilities**, select your Apple team and change `com.example.parkcast` to a unique bundle identifier.
4. Connect your iPhone, trust the Mac, and enable Developer Mode if Xcode asks. Select your phone as the run destination and press Run.
5. While parked, connect to CarPlay. In ParkCast, open **Connect → Play the video test**, then use the AirPlay picker. Observe whether a video destination is available and whether the actual display shows the picture.
6. Only after the test works, try a website or your own video. A successful unprotected test does not establish compatibility with a protected streaming service.

The standard iPhone build has no special CarPlay entitlement. A free Apple Personal Team can be used for personal-device development, subject to Apple's provisioning limits and periodic reinstalling. That is separate from subscribing to an app. See [Apple's developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account).

The test stream uses the internet and is hosted by Apple. No video is bundled or downloaded until you choose to play/import one. To import a Photos video, save it to Files using the Photos share menu, then import it in ParkCast.

## Optional CarPlay home-screen app

Start with the normal iPhone scheme above. Only use **ParkCastCarPlay** if you already have a development account/provisioning profile approved for `com.apple.developer.carplay-video`.

- This target requires the **iOS 27 SDK and iOS 27+**. It uses the separate `Config/CarPlay-Info.plist`, `Config/CarPlay.entitlements`, and `CARPLAY` compilation flag.
- Set its team and a unique bundle identifier independently. The Apple-approved entitlement must be present in the provisioning profile, not just the local file.
- The car UI lists the Apple test stream and your saved files/direct streams; websites are opened on the iPhone, not rendered as an arbitrary browser on the car screen.
- Choose video output through AirPlay in the iPhone player. The template alone does not force video routing or automatically open a video presentation on the car.
- Video support and current video availability are different. The optional scene reports support, and the operating system/vehicle controls availability. No state is spoofed.
- This optional target cannot be promised as a zero-cost distribution path: Apple controls membership and entitlement eligibility. The base app remains separate and subscription-free.

An AirPlay-enabled iPhone app and a CarPlay home-screen app are different things. Adding the entitlement does not retrofit video support into a vehicle. [Apple CarPlay overview](https://developer.apple.com/carplay/), [video entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.carplay-video), [video capability](https://developer.apple.com/documentation/carplay/cpsessionconfiguration/supportsvideoplayback).

## Limits compared with CarDash

- **Whole-phone in-app broadcasting is not implemented.** The Connect tab explains the built-in iOS Control Center mirroring option. There is no ReplayKit broadcast extension, fake broadcast button, or custom CarPlay mirroring transport.
- There is no guarantee of Netflix/Disney+ web playback inside WKWebView. Providers may require their own apps, restrict external displays, or block protected content in mirroring. Netflix says iPhone AirPlay is unsupported. [Netflix documentation](https://help.netflix.com/en/node/49).
- Website video uses the site's native player/AirPlay support. This app does not extract encrypted streams, collect provider passwords, alter DRM, or pretend to have CarDash's proprietary transport.
- Audio reaching the truck does not prove video support. A missing video destination cannot be fixed by the route-picker UI.
- HTTPS only; HTTP-only streams and local-network media servers are not supported by this version. Playlist files must be UTF-8 and contain HTTPS entries; remote lists can also use relative HTTPS URLs. HLS manifests belong in **Video link**, not **M3U playlist**.
- Imported local files are limited by the phone's free storage and Apple's supported codecs. Apple or the receiver may impose further restrictions on sending local files externally.

## Validation

On Windows or macOS, check the project wiring and plists:

```sh
python scripts/validate.py
```

Optional parser-only Swift syntax checking (does not type-check against Apple SDKs):

```sh
python -m pip install --target .tools/python tree-sitter==0.26.1 tree-sitter-swift==0.7.4
python scripts/validate.py
```

On a Mac, run the actual unit tests and simulator compilation:

```sh
bash scripts/check-mac.sh
# Also compile the experimental CarPlay target, with the iOS 27+ SDK:
bash scripts/check-mac.sh --carplay
```

The nine Swift tests cover URL validation, signed query preservation, M3U names/relative URLs/duplicates, HLS detection, import limits, local-file path confinement, and library serialization. A simulator build checks compilation; it cannot confirm real AirPlay or CarPlay compatibility. Follow [TESTING.md](TESTING.md) on the phone and vehicle.

`scripts/generate_project.py` recreates the checked-in project and plists without external tools. **It overwrites project signing/bundle-ID edits**, so run it only intentionally, before configuring your team. `validate.py` is read-only.

## Source map

| Path | Purpose |
| --- | --- |
| `ParkCast/Views.swift` | iPhone screens and controls |
| `ParkCast/BrowserModel.swift` | WebKit navigation, AirPlay settings, and website data |
| `ParkCast/PlaybackController.swift` | AVPlayer, route observation, audio session, Now Playing |
| `ParkCast/LibraryStore.swift` | Local persistence and imports |
| `ParkCast/CarPlaySceneDelegate.swift` | Optional approved CarPlay library scene |
| `Sources/ParkCastCore/Media.swift` | URL and playlist parsing; local-file confinement |
| `Tests/ParkCastCoreTests/MediaTests.swift` | Portable Swift unit tests |

Built from public Apple frameworks. The app has no affiliation with Apple, GMC, CarDash, Netflix, Disney, or YouTube.
