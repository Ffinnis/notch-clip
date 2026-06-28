import Combine
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var visibleItems: [ClipboardItem] = []
    @Published private(set) var currentClipboardItem: ClipboardItem?
    @Published var selectedID: ClipboardItem.ID?
    @Published var query = "" {
        didSet { reload() }
    }
    @Published var filter: ClipboardFilter = .history {
        didSet { reload() }
    }

    private let repository: ClipboardRepository
    private let writer: ClipboardWriter
    private var visibleItemLimit = 0

    private static let virtualPageSize = 24
    private static let virtualPrefetchThreshold = 6

    init(repository: ClipboardRepository, writer: ClipboardWriter) {
        self.repository = repository
        self.writer = writer
    }

    var selectedItem: ClipboardItem? {
        items.first { $0.id == selectedID } ?? items.first
    }

    var hasMoreVisibleItems: Bool {
        visibleItems.count < items.count
    }

    func reload(preferredContentHash: String? = nil, preserveVisiblePage: Bool = false) {
        do {
            let activeContentHash = preferredContentHash ?? currentClipboardItem?.contentHash
            let requestedVisibleLimit = preserveVisiblePage ? visibleItemLimit : Self.virtualPageSize
            items = try repository.fetchItems(query: query, filter: filter)
            visibleItemLimit = min(max(requestedVisibleLimit, Self.virtualPageSize), items.count)
            updateVisibleItems()

            if let activeContentHash,
               let activeItem = items.first(where: { $0.contentHash == activeContentHash }) {
                selectedID = activeItem.id
            } else if selectedID == nil || !items.contains(where: { $0.id == selectedID }) {
                selectedID = items.first?.id
            }
        } catch {
            NSLog("Failed to load clipboard items: \(error)")
        }
    }

    func loadMoreItemsIfNeeded(currentItem: ClipboardItem) {
        guard hasMoreVisibleItems,
              let index = visibleItems.firstIndex(where: { $0.id == currentItem.id }),
              index >= max(visibleItems.count - Self.virtualPrefetchThreshold, 0)
        else {
            return
        }

        loadNextVirtualPage()
    }

    func loadNextVirtualPage() {
        guard hasMoreVisibleItems else { return }
        visibleItemLimit = min(visibleItemLimit + Self.virtualPageSize, items.count)
        updateVisibleItems()
    }

    func select(_ item: ClipboardItem) {
        selectedID = item.id
    }

    func selectAndCopy(_ item: ClipboardItem) {
        selectedID = item.id
        currentClipboardItem = item
        writer.write(item)
    }

    func markCurrentClipboard(_ item: ClipboardItem) {
        currentClipboardItem = item
        reload(preferredContentHash: item.contentHash)
    }

    func togglePinSelected() {
        guard let selectedItem else { return }
        do {
            try repository.setPinned(id: selectedItem.id, isPinned: !selectedItem.isPinned)
            reload(preserveVisiblePage: true)
        } catch {
            NSLog("Failed to update pin: \(error)")
        }
    }

    func deleteSelected() {
        guard let selectedItem else { return }
        do {
            try repository.delete(id: selectedItem.id)
            reload(preserveVisiblePage: true)
        } catch {
            NSLog("Failed to delete item: \(error)")
        }
    }

    private func updateVisibleItems() {
        visibleItems = Array(items.prefix(visibleItemLimit))
    }
}
