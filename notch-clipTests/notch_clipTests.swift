import AppKit
import SwiftData
import XCTest
@testable import notch_clip

@MainActor
final class notch_clipTests: XCTestCase {
    enum TestError: Error {
        case expected
    }

    func testClassifiesKnownPasteboardTypes() throws {
        XCTAssertEqual(ClipboardClassifier.classify([text("#1f1f1f")]), .color("#1F1F1F"))

        let urlContent = ClipboardClassifier.classify([text("https://chatgpt.com/")])
        if case .url(let url, _) = urlContent {
            XCTAssertEqual(url.absoluteString, "https://chatgpt.com/")
        } else {
            XCTFail("Expected URL content")
        }

        let codeContent = ClipboardClassifier.classify([text("function update() { return true; }")])
        if case .code(let code, let language) = codeContent {
            XCTAssertEqual(code, "function update() { return true; }")
            XCTAssertEqual(language, "JavaScript")
        } else {
            XCTFail("Expected code content")
        }

        let imageContent = ClipboardClassifier.classify([
            PasteboardRepresentation(itemIndex: 0, type: "public.png", data: Data([0x89, 0x50, 0x4E, 0x47]))
        ])
        if case .image(let data) = imageContent {
            XCTAssertEqual(data.count, 4)
        } else {
            XCTFail("Expected image content")
        }

        let pdfContent = ClipboardClassifier.classify([
            PasteboardRepresentation(itemIndex: 0, type: "com.adobe.pdf", data: Data([0x25, 0x50, 0x44, 0x46]))
        ])
        if case .pdf(let data) = pdfContent {
            XCTAssertEqual(data.count, 4)
        } else {
            XCTFail("Expected PDF content")
        }

        let fileContent = ClipboardClassifier.classify([
            representation(type: "public.file-url", string: "file:///Users/roman/Desktop/example.png")
        ])
        if case .fileURL(let url) = fileContent {
            XCTAssertEqual(url.lastPathComponent, "example.png")
        } else {
            XCTFail("Expected file URL content")
        }

        let rawContent = ClipboardClassifier.classify([
            PasteboardRepresentation(itemIndex: 0, type: "com.example.custom", data: Data([1, 2, 3]))
        ])
        XCTAssertEqual(rawContent, .raw(type: "com.example.custom", byteCount: 3))
    }

    func testClassifiesUTF16PasteboardTextTypes() throws {
        let urlContent = ClipboardClassifier.classify([
            representation(type: "public.utf16-plain-text", string: "https://example.com/docs", encoding: .utf16LittleEndian)
        ])
        if case .url(let url, _) = urlContent {
            XCTAssertEqual(url.absoluteString, "https://example.com/docs")
        } else {
            XCTFail("Expected UTF-16 URL content")
        }

        let codeContent = ClipboardClassifier.classify([
            representation(type: "public.utf16-plain-text", string: "func update() { return true }", encoding: .utf16)
        ])
        if case .code(let code, let language) = codeContent {
            XCTAssertEqual(code, "func update() { return true }")
            XCTAssertEqual(language, "Swift")
        } else {
            XCTFail("Expected UTF-16 code content")
        }

        let colorContent = ClipboardClassifier.classify([
            representation(type: "public.utf16-plain-text", string: "#00ffaa", encoding: .utf16BigEndian)
        ])
        XCTAssertEqual(colorContent, .color("#00FFAA"))
    }

    func testClassifiesLegacyStringPasteboardType() throws {
        let content = ClipboardClassifier.classify([
            representation(type: "NSStringPboardType", string: "Legacy text")
        ])
        XCTAssertEqual(content, .text("Legacy text"))
    }

    func testRepositoryDeduplicatesPinsSearchesAndDeletes() throws {
        let repository = try makeRepository()
        let firstItem = try XCTUnwrap(
            ClipboardClassifier.makeItem(representations: [text("Needle note")], sourceApp: "Notes")
        )

        try repository.saveCapturedItem(firstItem)
        try repository.saveCapturedItem(firstItem)

        XCTAssertEqual(try repository.fetchItems(query: "", filter: .history).count, 1)
        XCTAssertEqual(try repository.fetchItems(query: "needle", filter: .history).map(\.id), [firstItem.id])

        try repository.setPinned(id: firstItem.id, isPinned: true)
        let pins = try repository.fetchItems(query: "", filter: .pins)
        XCTAssertEqual(pins.count, 1)
        XCTAssertTrue(try XCTUnwrap(pins.first).isPinned)

        try repository.delete(id: firstItem.id)
        XCTAssertTrue(try repository.fetchItems(query: "", filter: .history).isEmpty)
    }

    func testClipboardWriterSkipsInternalPreviewRepresentations() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("notch-clip-tests-\(UUID().uuidString)"))
        let writer = NSPasteboardClipboardWriter(pasteboard: pasteboard)
        let item = try XCTUnwrap(
            ClipboardClassifier.makeItem(
                representations: [
                    text("Copy me"),
                    PasteboardRepresentation(
                        itemIndex: 0,
                        type: ClipboardTypeIdentifier.filePreviewData,
                        data: Data([1, 2, 3])
                    )
                ],
                sourceApp: "Tests"
            )
        )

        writer.write(item)

        let pasteboardItem = try XCTUnwrap(pasteboard.pasteboardItems?.first)
        XCTAssertEqual(pasteboardItem.string(forType: .string), "Copy me")
        XCTAssertNil(
            pasteboardItem.data(forType: NSPasteboard.PasteboardType(ClipboardTypeIdentifier.filePreviewData))
        )
    }

    func testStoreVirtualizesVisibleHistoryItems() throws {
        let repository = InMemoryClipboardRepository(maxItems: 100)
        let writer = CapturingClipboardWriter()
        let store = ClipboardStore(repository: repository, writer: writer)

        for index in 0..<35 {
            let item = try XCTUnwrap(
                ClipboardClassifier.makeItem(
                    representations: [text("History item \(index)")],
                    sourceApp: "Tests",
                    date: Date(timeIntervalSince1970: TimeInterval(index))
                )
            )
            try repository.saveCapturedItem(item)
        }

        store.reload()

        XCTAssertEqual(store.items.count, 35)
        XCTAssertEqual(store.visibleItems.count, 24)
        XCTAssertTrue(store.hasMoreVisibleItems)

        let lastVisibleItem = try XCTUnwrap(store.visibleItems.last)
        store.loadMoreItemsIfNeeded(currentItem: lastVisibleItem)

        XCTAssertEqual(store.visibleItems.count, 35)
        XCTAssertFalse(store.hasMoreVisibleItems)
    }

    func testCompositionRootFallsBackToInMemorySwiftDataRepository() throws {
        let repository = AppCompositionRoot.makeRepository(
            persistentContainer: {
                throw TestError.expected
            },
            inMemoryContainer: {
                try makeModelContainer(isStoredInMemoryOnly: true)
            }
        )

        XCTAssertTrue(repository is SwiftDataClipboardRepository)
    }

    func testCompositionRootFallsBackToVolatileRepository() throws {
        let repository = AppCompositionRoot.makeRepository(
            persistentContainer: {
                throw TestError.expected
            },
            inMemoryContainer: {
                throw TestError.expected
            }
        )

        XCTAssertTrue(repository is InMemoryClipboardRepository)
    }

    private func makeRepository() throws -> SwiftDataClipboardRepository {
        let container = try makeModelContainer(isStoredInMemoryOnly: true)
        return SwiftDataClipboardRepository(container: container, maxItems: 10)
    }

    private func makeModelContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let schema = Schema([
            StoredClipboardItem.self,
            StoredPasteboardRepresentation.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func text(_ string: String) -> PasteboardRepresentation {
        representation(type: "public.utf8-plain-text", string: string)
    }

    private func representation(type: String, string: String) -> PasteboardRepresentation {
        representation(type: type, string: string, encoding: .utf8)
    }

    private func representation(
        type: String,
        string: String,
        encoding: String.Encoding
    ) -> PasteboardRepresentation {
        PasteboardRepresentation(itemIndex: 0, type: type, data: string.data(using: encoding) ?? Data())
    }
}

@MainActor
private final class CapturingClipboardWriter: ClipboardWriter {
    private(set) var writtenItems: [ClipboardItem] = []

    func write(_ item: ClipboardItem) {
        writtenItems.append(item)
    }
}
