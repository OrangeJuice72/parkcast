# ParkCast device checks

These are **pending**, not completed test results. Run while parked. Use the ordinary ParkCast scheme first.

1. **Launch:** install from Xcode, open all three tabs, rotate the phone, and try a larger system text size. Controls and content should remain reachable.
2. **Known video:** play the Apple test stream. Confirm a moving picture and sound on the phone before testing external output. With networking unavailable, an error should appear rather than a success label.
3. **Route:** open AirPlay. If a compatible receiver is listed, select it and inspect the actual receiver screen. Native external-video status should reflect AVPlayer; merely choosing car audio must not report successful video. If no video receiver exists, record that result.
4. **Browser:** open YouTube, play an ordinary public video, and test its native AirPlay control. Try back, forward, a new address, bookmark, reload, and Safari. Dismissing the browser should pause its media. Test Netflix/Disney+ separately; record any app-only or display restriction as unsupported, not an app success.
5. **Library:** import a small MP4 from Files. Close and relaunch ParkCast; it should still play. Delete it and verify only the ParkCast copy is removed. Add a website bookmark and a direct HTTPS stream and confirm they open in the correct view.
6. **Playlists:** import a small UTF-8 M3U with two owned/legal stream URLs. Names should match, duplicate URLs should appear once, relative URLs should work in remote lists, and an HLS manifest should direct you to Video link. Test a malformed, unavailable, and oversized URL/list.
7. **Playback:** pause/resume from the phone and lock screen. Test a call interruption and disconnecting the external route. Audio interruptions/route removal should pause the native player. Check subtitles/Picture in Picture using content that supports them.
8. **Privacy:** clear website data and verify the browser is signed out. Saved video entries should remain. Inspect Share diagnostics; it must contain no URLs, cookies, credentials, or library contents.
9. **Optional CarPlay build:** only after approval/signing, verify the scene opens on a compatible head unit and the library updates after adding/removing a stream. Video availability remains controlled by the vehicle and iOS. The scene should clear its capability status and pause playback when disconnected.

Record phone model, exact iOS version, scheme, head-unit software version, connection type, content type, and observed picture/sound. The optional CarPlay scene and the phone browser have distinct restrictions; testing one does not validate the other.
