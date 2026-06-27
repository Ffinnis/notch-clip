import AppKit

@MainActor
final class NSPasteboardClipboardWriter: ClipboardWriter {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func write(_ item: ClipboardItem) {
        pasteboard.clearContents()

        let grouped = Dictionary(grouping: item.representations, by: \.itemIndex)
        let pasteboardItems = grouped.keys.sorted().map { index in
            let pasteboardItem = NSPasteboardItem()
            grouped[index]?.forEach { representation in
                pasteboardItem.setData(
                    representation.data,
                    forType: NSPasteboard.PasteboardType(representation.type)
                )
            }
            return pasteboardItem
        }

        pasteboard.writeObjects(pasteboardItems)
    }
}
