import Foundation
import Sparkle

@MainActor
final class AppUpdater {
    private let updaterController: SPUStandardUpdaterController

    init(startingUpdater: Bool = true) {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
