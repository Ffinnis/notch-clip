import CryptoKit
import Foundation

enum ClipboardClassifier {
    nonisolated static func makeItem(
        representations: [PasteboardRepresentation],
        sourceApp: String?,
        date: Date = Date()
    ) -> ClipboardItem? {
        guard !representations.isEmpty else { return nil }

        let content = classify(representations)
        let previewText = makePreviewText(for: content, representations: representations)
        let title = makeTitle(for: content, representations: representations)

        return ClipboardItem(
            id: UUID(),
            createdAt: date,
            sourceApp: sourceApp,
            isPinned: false,
            content: content,
            displayTitle: title,
            previewText: previewText,
            contentHash: hash(representations),
            representations: representations
        )
    }

    nonisolated static func classify(_ representations: [PasteboardRepresentation]) -> ClipboardContent {
        if let fileURL = firstURL(for: ["public.file-url"], in: representations) {
            return .fileURL(fileURL)
        }

        if let url = firstURL(for: ["public.url"], in: representations) ?? firstURLFromText(in: representations) {
            return .url(url, title: nil)
        }

        if let color = firstText(in: representations).flatMap(normalizedHexColor) {
            return .color(color)
        }

        if let html = firstRepresentation(ofTypes: ["public.html"], in: representations)?.stringValue {
            return .html(html)
        }

        if let richText = firstRepresentation(ofTypes: ["public.rtf", "public.rtfd"], in: representations) {
            return .richText(richText.data, plainText: firstText(in: representations))
        }

        if let image = firstRepresentation(ofTypes: ["public.png", "public.tiff", "public.jpeg"], in: representations) {
            return .image(image.data)
        }

        if let text = firstText(in: representations) {
            if looksLikeCode(text) {
                return .code(text, language: inferredLanguage(from: text))
            }
            return .text(text)
        }

        let first = representations[0]
        return .raw(type: first.type, byteCount: first.data.count)
    }

    private nonisolated static func firstRepresentation(
        ofTypes types: Set<String>,
        in representations: [PasteboardRepresentation]
    ) -> PasteboardRepresentation? {
        representations.first { types.contains($0.type) }
    }

    private nonisolated static func firstText(in representations: [PasteboardRepresentation]) -> String? {
        let textTypes: Set<String> = [
            "public.utf8-plain-text",
            "public.utf16-plain-text",
            "NSStringPboardType"
        ]

        for representation in representations where textTypes.contains(representation.type) {
            if let string = representation.stringValue, !string.isEmpty {
                return string
            }
        }

        return nil
    }

    private nonisolated static func firstURL(for types: Set<String>, in representations: [PasteboardRepresentation]) -> URL? {
        for representation in representations where types.contains(representation.type) {
            guard let string = representation.stringValue else { continue }
            if let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return url
            }
        }
        return nil
    }

    private nonisolated static func firstURLFromText(in representations: [PasteboardRepresentation]) -> URL? {
        guard let text = firstText(in: representations)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "mailto"].contains(scheme)
        else {
            return nil
        }
        return url
    }

    private nonisolated static func normalizedHexColor(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard [6, 8].contains(raw.count),
              raw.allSatisfy({ $0.isHexDigit })
        else {
            return nil
        }
        return "#\(raw.uppercased())"
    }

    private nonisolated static func looksLikeCode(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let markers = [
            "func ",
            "function ",
            "class ",
            "struct ",
            "import ",
            "const ",
            "let ",
            "var ",
            "if (",
            "return ",
            "</",
            "{",
            "};"
        ]
        return markers.contains { lowered.contains($0) }
    }

    private nonisolated static func inferredLanguage(from text: String) -> String? {
        let lowered = text.lowercased()
        if lowered.contains("function ") || lowered.contains("const ") {
            return "JavaScript"
        }
        if lowered.contains("func ") || lowered.contains("struct ") {
            return "Swift"
        }
        if lowered.contains("</") || lowered.contains("<html") {
            return "HTML"
        }
        return nil
    }

    private nonisolated static func makeTitle(for content: ClipboardContent, representations: [PasteboardRepresentation]) -> String {
        switch content {
        case .url(let url, _):
            return url.host ?? "URL"
        case .fileURL(let url):
            return url.lastPathComponent
        case .color(let color):
            return color
        default:
            return content.kind.title
        }
    }

    private nonisolated static func makePreviewText(
        for content: ClipboardContent,
        representations: [PasteboardRepresentation]
    ) -> String {
        switch content {
        case .text(let text), .code(let text, _):
            return text
        case .url(let url, _), .fileURL(let url):
            return url.absoluteString
        case .color(let color):
            return color
        case .html(let html):
            return html
        case .richText(_, let plainText):
            return plainText ?? "Rich text content"
        case .image:
            return "Image content"
        case .raw(let type, _):
            return type
        }
    }

    private nonisolated static func hash(_ representations: [PasteboardRepresentation]) -> String {
        var data = Data()

        representations
            .sorted { lhs, rhs in
                if lhs.itemIndex == rhs.itemIndex {
                    return lhs.type < rhs.type
                }
                return lhs.itemIndex < rhs.itemIndex
            }
            .forEach { representation in
                data.append(Data("\(representation.itemIndex):\(representation.type):\(representation.data.count):".utf8))
                data.append(representation.data)
            }

        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
