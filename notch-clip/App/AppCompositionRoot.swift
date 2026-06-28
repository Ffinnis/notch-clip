import AppKit
import SwiftData

@MainActor
final class AppCompositionRoot {
    private let repository: ClipboardRepository
    private let writer: ClipboardWriter
    private let monitor: NSPasteboardClipboardMonitor
    private let store: ClipboardStore
    private let panelController: NotchPanelController
    private let hoverDetector: NotchHoverDetector
    private let updater: AppUpdater
    private let statusItemController: StatusItemController
    private var cleanupTimer: Timer?

    private static let cleanupInterval: TimeInterval = 60 * 60

    init() {
        let repository = Self.makeRepository()
        let writer = NSPasteboardClipboardWriter()
        let store = ClipboardStore(repository: repository, writer: writer)
        let panelController = NotchPanelController(store: store)
        let hoverDetector = NotchHoverDetector(
            panelFrameProvider: { [weak panelController] in
                panelController?.panelFrame
            }
        )
        let updater = AppUpdater()
        let statusItemController = StatusItemController()

        self.repository = repository
        self.writer = writer
        self.monitor = NSPasteboardClipboardMonitor()
        self.store = store
        self.panelController = panelController
        self.hoverDetector = hoverDetector
        self.updater = updater
        self.statusItemController = statusItemController
    }

    static func makeRepository(
        persistentContainer: @MainActor () throws -> ModelContainer = makePersistentModelContainer,
        inMemoryContainer: @MainActor () throws -> ModelContainer = makeInMemoryModelContainer
    ) -> ClipboardRepository {
        do {
            return SwiftDataClipboardRepository(container: try persistentContainer())
        } catch {
            NSLog("Could not create persistent clipboard store: \(error). Falling back to in-memory SwiftData.")
        }

        do {
            return SwiftDataClipboardRepository(container: try inMemoryContainer())
        } catch {
            NSLog("Could not create in-memory SwiftData clipboard store: \(error). Falling back to volatile memory.")
            return InMemoryClipboardRepository()
        }
    }

    func start() {
        cleanupClipboardHistory()
        store.reload()
        if let currentItem = monitor.currentItem(sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName) {
            store.markCurrentClipboard(currentItem)
        }
        scheduleClipboardCleanup()

        monitor.onChange = { [weak self] item in
            self?.capture(item)
        }
        monitor.start()

        hoverDetector.onHover = { [weak self] screen in
            self?.panelController.show(anchorScreen: screen)
        }
        hoverDetector.onExit = { [weak self] in
            self?.panelController.hide(reason: .hoverExited)
        }
        hoverDetector.start()

        statusItemController.onShow = { [weak self] in
            self?.panelController.show(anchorScreen: NSScreen.main)
        }
        statusItemController.onCheckForUpdates = { [weak self] in
            self?.updater.checkForUpdates()
        }
        statusItemController.onQuit = {
            NSApp.terminate(nil)
        }
        statusItemController.install()
    }

    func stop() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        monitor.stop()
        hoverDetector.stop()
    }

    private func capture(_ item: ClipboardItem) {
        do {
            try repository.saveCapturedItem(item)
            try repository.pruneIfNeeded()
            store.markCurrentClipboard(item)
        } catch {
            NSLog("Failed to save clipboard item: \(error)")
        }
    }

    private func scheduleClipboardCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: Self.cleanupInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.cleanupClipboardHistory(reloadStore: true)
            }
        }
    }

    private func cleanupClipboardHistory(reloadStore: Bool = false) {
        do {
            try repository.pruneIfNeeded()
            if reloadStore {
                store.reload(preserveVisiblePage: true)
            }
        } catch {
            NSLog("Failed to clean up clipboard history: \(error)")
        }
    }

    private static func makePersistentModelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: StoredClipboardItem.self,
            StoredPasteboardRepresentation.self
        )
    }

    private static func makeInMemoryModelContainer() throws -> ModelContainer {
        let schema = Schema([
            StoredClipboardItem.self,
            StoredPasteboardRepresentation.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
