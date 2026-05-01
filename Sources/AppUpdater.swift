import Foundation
import Combine
import Sparkle

@MainActor
final class AppUpdater: NSObject, ObservableObject {
    let controller: SPUStandardUpdaterController
    @Published private(set) var canCheckForUpdates: Bool = false

    private var cancellable: AnyCancellable?

    override init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        cancellable = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: \.canCheckForUpdates, on: self)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
