import AVFoundation
import AVKit
import Combine
import MediaPlayer
import SwiftUI

@MainActor
final class PlaybackController: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var title = "Nothing playing"
    @Published private(set) var hasMedia = false
    @Published private(set) var externalVideo = false
    @Published private(set) var playing = false
    @Published private(set) var loading = false
    @Published private(set) var output = "iPhone"
    @Published var issue: String?
    private var observations: [NSKeyValueObservation] = []
    private var itemObservation: NSKeyValueObservation?
    private var notifications: [NSObjectProtocol] = []
    private var timeObserver: Any?

    init() {
        player.allowsExternalPlayback = true
        observations.append(player.observe(\.isExternalPlaybackActive, options: [.initial, .new]) { [weak self] player, _ in
            let active = player.isExternalPlaybackActive
            Task { @MainActor in self?.externalVideo = active }
        })
        observations.append(player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let state = player.timeControlStatus
            Task { @MainActor in
                self?.playing = state == .playing
                self?.loading = state == .waitingToPlayAtSpecifiedRate
                self?.publishNowPlaying()
            }
        })
        notifications.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                .flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            Task { @MainActor in
                self?.refreshRoute()
                if reason == .oldDeviceUnavailable { self?.player.pause() }
            }
        })
        notifications.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if value == AVAudioSession.InterruptionType.began.rawValue {
                Task { @MainActor in self?.player.pause() }
            }
        })
        notifications.append(NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: nil, queue: .main
        ) { [weak self] notification in
            let failedItem = notification.object as? AVPlayerItem
            let message = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription
            Task { @MainActor in
                guard let self, failedItem === self.player.currentItem else { return }
                self.issue = message ?? "Playback stopped. Check the connection or try another video."
                self.loading = false
            }
        })
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor in self?.publishNowPlaying() }
        }
        installRemoteControls()
        refreshRoute()
    }

    func activateAudio() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .moviePlayback)
        try session.setActive(true)
        refreshRoute()
    }

    func load(_ url: URL, title: String) {
        do { try activateAudio() }
        catch { issue = "Could not start the audio session: " + error.localizedDescription; return }
        issue = nil
        player.pause()
        itemObservation = nil
        self.title = title
        hasMedia = true
        loading = true
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let state = item.status
            let message = item.error?.localizedDescription
            Task { @MainActor in
                guard let self, self.player.currentItem === item else { return }
                if state == .failed {
                    self.loading = false
                    self.issue = message ?? "This video cannot be played. Try an MP4 or HLS stream."
                }
            }
        }
        player.play()
        publishNowPlaying()
    }

    func togglePlayback() {
        guard hasMedia else { return }
        if playing { player.pause() } else { player.play() }
    }

    func stop() {
        player.pause()
        itemObservation = nil
        player.replaceCurrentItem(with: nil)
        hasMedia = false
        loading = false
        title = "Nothing playing"
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func refreshRoute() {
        let names = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portName)
        output = names.isEmpty ? "iPhone" : names.joined(separator: ", ")
    }

    private func publishNowPlaying() {
        guard hasMedia else { return }
        var info: [String: Any] = [MPMediaItemPropertyTitle: title,
                                  MPNowPlayingInfoPropertyPlaybackRate: player.rate,
                                  MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue]
        let elapsed = player.currentTime().seconds
        let duration = player.currentItem?.duration.seconds ?? .nan
        if elapsed.isFinite { info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed }
        if duration.isFinite { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func installRemoteControls() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player.play() }; return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player.pause() }; return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayback() }; return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in
                self?.player.seek(to: CMTime(seconds: position, preferredTimescale: 600))
            }
            return .success
        }
    }
}

@MainActor
struct AirPlayPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = true
        view.tintColor = .white
        view.activeTintColor = .systemMint
        return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

@MainActor
struct NativePlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.updatesNowPlayingInfoCenter = false
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player { controller.player = player }
    }
}
