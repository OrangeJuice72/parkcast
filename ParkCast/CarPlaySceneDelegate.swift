// Included only by the optional ParkCastCarPlay target. The default iPhone app
// does not need a CarPlay entitlement. This scene uses system templates only.
#if CARPLAY
import CarPlay
import Combine

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPSessionConfigurationDelegate {
    private var interfaceController: CPInterfaceController?
    private var configuration: CPSessionConfiguration?
    private var subscriptions = Set<AnyCancellable>()
    private var list: CPListTemplate?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        configuration = CPSessionConfiguration(delegate: self)
        AppModel.shared.carConnected = true
        AppModel.shared.carVideoSupported = configuration?.supportsVideoPlayback
        let template = CPListTemplate(title: "ParkCast", sections: sections())
        list = template
        interfaceController.setRootTemplate(template, animated: false) { _, error in
            if let error {
                Task { @MainActor in AppModel.shared.library.issue = error.localizedDescription }
            }
        }
        AppModel.shared.library.$entries.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self else { return }
            self.list?.updateSections(self.sections())
        }.store(in: &subscriptions)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        AppModel.shared.carConnected = false
        AppModel.shared.carVideoSupported = nil
        AppModel.shared.playback.player.pause()
        subscriptions.removeAll()
        configuration = nil
        list = nil
        self.interfaceController = nil
    }

    func sessionConfiguration(_ sessionConfiguration: CPSessionConfiguration,
                              limitedUserInterfacesChanged limitedUserInterfaces: CPLimitableUserInterface) {
        // Vehicle and iOS own video availability. This app never overrides it.
        AppModel.shared.carVideoSupported = sessionConfiguration.supportsVideoPlayback
    }

    private func sections() -> [CPListSection] {
        let model = AppModel.shared
        let test = CPListItem(text: "Video test", detailText: "Apple sample · internet required")
        test.handler = { _, completion in
            Task { @MainActor in model.playTest(); completion() }
        }
        let items = model.library.entries.filter { $0.kind != .website }.prefix(100).map { entry in
            let item = CPListItem(text: entry.title, detailText: entry.kind == .file ? "Saved video" : "Video stream")
            item.handler = { _, completion in
                Task { @MainActor in model.play(entry); completion() }
            }
            return item
        }
        let help = CPListItem(text: "Video output", detailText: "Use AirPlay in the iPhone player to choose a display.")
        help.isEnabled = false
        return [CPListSection(items: [test, help]), CPListSection(items: items)]
    }
}
#endif
