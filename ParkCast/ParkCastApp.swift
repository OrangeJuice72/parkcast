import SwiftUI
import UIKit

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    let library = LibraryStore()
    let playback = PlaybackController()
    let browser = BrowserModel()
    @Published var tab = 0
    @Published var showingBrowser = false
    @Published var showingPlayer = false
    @Published var carVideoSupported: Bool?
    @Published var carConnected = false

    static let testURL = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"

    func browse(_ address: String) {
        playback.stop()
        do { try playback.activateAudio() }
        catch { browser.issue = error.localizedDescription }
        browser.open(address)
        showingBrowser = true
    }

    func play(_ entry: MediaEntry) {
        if entry.kind == .website { browse(entry.location); return }
        do {
            let url = try entry.url(in: library.directory)
            if entry.kind == .file, !FileManager.default.fileExists(atPath: url.path) { throw MediaError.invalidFile }
            browser.pause()
            playback.load(url, title: entry.title)
            showingPlayer = true
        } catch { library.issue = error.localizedDescription }
    }

    func playTest() {
        play(MediaEntry(title: "Apple video test", location: Self.testURL, kind: .stream))
    }

    var diagnosticReport: String {
        """
        ParkCast 1.0 prototype
        iOS: \(UIDevice.current.systemVersion)
        Audio output: \(playback.output)
        Native player's external video active: \(playback.externalVideo ? "yes" : "no")
        App CarPlay scene connected: \(carConnected ? "yes" : "no")
        CarPlay video capability: \(carVideoSupported.map { $0 ? "supported" : "not supported" } ?? "not reported")
        Browser video output: not observable by this app
        Vehicle: 2025 GMC Sierra Denali 2500 HD (user supplied)
        """
    }
}

@main
@MainActor
struct ParkCastApp: App {
    @StateObject private var model = AppModel.shared
    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .tint(.mint)
        }
    }
}
