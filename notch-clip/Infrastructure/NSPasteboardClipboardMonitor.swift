import AppKit

@MainActor
final class NSPasteboardClipboardMonitor: ClipboardMonitor {
    var onChange: ((ClipboardItem) -> Void)?

    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(
            timeInterval: 0.65,
            target: self,
            selector: #selector(pollTimer),
            userInfo: nil,
            repeats: true
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func pollTimer() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
        let representations = captureRepresentations()
        guard let item = ClipboardClassifier.makeItem(representations: representations, sourceApp: sourceApp) else {
            return
        }
        onChange?(item)
    }

    private func captureRepresentations() -> [PasteboardRepresentation] {
        guard let pasteboardItems = pasteboard.pasteboardItems, !pasteboardItems.isEmpty else {
            if let string = pasteboard.string(forType: .string),
               let data = string.data(using: .utf8) {
                return [PasteboardRepresentation(itemIndex: 0, type: NSPasteboard.PasteboardType.string.rawValue, data: data)]
            }
            return []
        }

        return pasteboardItems.enumerated().flatMap { index, item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return PasteboardRepresentation(itemIndex: index, type: type.rawValue, data: data)
            }
        }
    }
}
