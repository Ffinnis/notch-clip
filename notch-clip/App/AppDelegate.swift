import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var compositionRoot: AppCompositionRoot?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let compositionRoot = AppCompositionRoot()
        self.compositionRoot = compositionRoot
        compositionRoot.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        compositionRoot?.stop()
    }
}
