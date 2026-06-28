import Foundation

enum ClipboardContentKind: String, Codable, CaseIterable, Identifiable {
    case text
    case url
    case code
    case color
    case image
    case pdf
    case fileURL
    case richText
    case html
    case raw

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .text: "Text"
        case .url: "URL"
        case .code: "Code"
        case .color: "Color"
        case .image: "Image"
        case .pdf: "PDF"
        case .fileURL: "File"
        case .richText: "Rich Text"
        case .html: "HTML"
        case .raw: "Raw"
        }
    }

    nonisolated var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .url: "link"
        case .code: "curlybraces"
        case .color: "paintpalette"
        case .image: "photo"
        case .pdf: "doc.richtext"
        case .fileURL: "doc"
        case .richText: "doc.richtext"
        case .html: "chevron.left.forwardslash.chevron.right"
        case .raw: "shippingbox"
        }
    }
}

enum ClipboardContent: Equatable {
    case text(String)
    case url(URL, title: String?)
    case code(String, language: String?)
    case color(String)
    case image(Data)
    case pdf(Data)
    case fileURL(URL)
    case richText(Data, plainText: String?)
    case html(String)
    case raw(type: String, byteCount: Int)

    nonisolated var kind: ClipboardContentKind {
        switch self {
        case .text: .text
        case .url: .url
        case .code: .code
        case .color: .color
        case .image: .image
        case .pdf: .pdf
        case .fileURL: .fileURL
        case .richText: .richText
        case .html: .html
        case .raw: .raw
        }
    }
}

struct PasteboardRepresentation: Identifiable, Hashable {
    let id: UUID
    let itemIndex: Int
    let type: String
    let data: Data

    init(id: UUID = UUID(), itemIndex: Int, type: String, data: Data) {
        self.id = id
        self.itemIndex = itemIndex
        self.type = type
        self.data = data
    }

    nonisolated var stringValue: String? {
        switch type {
        case "public.utf16-plain-text":
            decodedUTF16String()
        case "public.utf8-plain-text",
             "NSStringPboardType",
             "public.url",
             "public.file-url",
             "public.html":
            decodedString(encodings: [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian])
        default:
            decodedString(encodings: [.utf8])
        }
    }

    private nonisolated func decodedString(encodings: [String.Encoding]) -> String? {
        for encoding in encodings {
            if let string = String(data: data, encoding: encoding) {
                return string
            }
        }
        return nil
    }

    private nonisolated func decodedUTF16String() -> String? {
        guard data.count.isMultiple(of: 2) else { return nil }

        let prefix = Array(data.prefix(2))
        if prefix == [0xFF, 0xFE] || prefix == [0xFE, 0xFF] {
            return String(data: data, encoding: .utf16)
        }

        var evenNullCount = 0
        var oddNullCount = 0

        for (index, byte) in data.enumerated() where byte == 0 {
            if index.isMultiple(of: 2) {
                evenNullCount += 1
            } else {
                oddNullCount += 1
            }
        }

        if oddNullCount > evenNullCount {
            return String(data: data, encoding: .utf16LittleEndian)
        }

        if evenNullCount > oddNullCount {
            return String(data: data, encoding: .utf16BigEndian)
        }

        return String(data: data, encoding: .utf16LittleEndian)
            ?? String(data: data, encoding: .utf16BigEndian)
    }
}

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let sourceApp: String?
    var isPinned: Bool
    let content: ClipboardContent
    let displayTitle: String
    let previewText: String
    let contentHash: String
    let representations: [PasteboardRepresentation]

    nonisolated var kind: ClipboardContentKind {
        content.kind
    }

    nonisolated var metadata: String {
        switch content {
        case .image(let data), .pdf(let data):
            ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        case .raw(_, let byteCount):
            ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
        default:
            "\(previewText.count) characters"
        }
    }
}

enum ClipboardFilter: String, CaseIterable, Identifiable {
    case history
    case pins

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .history: "History"
        case .pins: "Pins"
        }
    }

    nonisolated var symbolName: String {
        switch self {
        case .history: "clock.arrow.circlepath"
        case .pins: "pin"
        }
    }
}

enum PanelHideReason {
    case hoverExited
    case userDismissed
}

@MainActor
protocol ClipboardRepository {
    func fetchItems(query: String, filter: ClipboardFilter) throws -> [ClipboardItem]
    func saveCapturedItem(_ item: ClipboardItem) throws
    func delete(id: UUID) throws
    func setPinned(id: UUID, isPinned: Bool) throws
    func pruneIfNeeded() throws
}

@MainActor
protocol ClipboardWriter {
    func write(_ item: ClipboardItem)
}

@MainActor
protocol ClipboardMonitor: AnyObject {
    var onChange: ((ClipboardItem) -> Void)? { get set }
    func start()
    func stop()
}

enum ClipboardTypeIdentifier {
    nonisolated static let imageDataTypes: Set<String> = [
        "public.png",
        "public.tiff",
        "public.jpeg",
        "public.heic",
        "public.heif",
        "public.image",
        "com.compuserve.gif"
    ]

    nonisolated static let pdfDataTypes: Set<String> = [
        "com.adobe.pdf",
        "public.pdf"
    ]

    nonisolated static let filePreviewData = "revvu.notch-clip.file-preview-data"

    nonisolated static func isInternal(_ type: String) -> Bool {
        type == filePreviewData
    }
}

enum PreviewableFileKind: String, Sendable {
    case image
    case pdf

    nonisolated static let maxStoredPreviewBytes = 12 * 1024 * 1024

    nonisolated init?(fileURL url: URL) {
        guard url.isFileURL else { return nil }

        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "tif", "tiff", "gif", "heic", "heif", "webp", "bmp":
            self = .image
        case "pdf":
            self = .pdf
        default:
            return nil
        }
    }
}
