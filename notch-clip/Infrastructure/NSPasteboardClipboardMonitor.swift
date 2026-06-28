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

    func currentItem(sourceApp: String? = nil) -> ClipboardItem? {
        ClipboardClassifier.makeItem(representations: captureRepresentations(), sourceApp: sourceApp)
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

        let representations: [PasteboardRepresentation] = pasteboardItems.enumerated().flatMap { index, item in
            item.types.compactMap { type -> PasteboardRepresentation? in
                guard let data = item.data(forType: type) else { return nil }
                return PasteboardRepresentation(itemIndex: index, type: type.rawValue, data: data)
            }
        }

        return representations + filePreviewRepresentations(for: representations)
    }

    private func filePreviewRepresentations(for representations: [PasteboardRepresentation]) -> [PasteboardRepresentation] {
        representations.compactMap { representation in
            guard representation.type == "public.file-url",
                  let string = representation.stringValue,
                  let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
                  PreviewableFileKind(fileURL: url) != nil,
                  let data = previewData(for: url)
            else {
                return nil
            }

            return PasteboardRepresentation(
                itemIndex: representation.itemIndex,
                type: ClipboardTypeIdentifier.filePreviewData,
                data: data
            )
        }
    }

    private func previewData(for url: URL) -> Data? {
        guard url.isFileURL else { return nil }

        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile != false,
                  let fileSize = values.fileSize,
                  fileSize > 0,
                  fileSize <= PreviewableFileKind.maxStoredPreviewBytes
            else {
                return nil
            }

            return try Data(contentsOf: url)
        } catch {
            return nil
        }
    }
}
