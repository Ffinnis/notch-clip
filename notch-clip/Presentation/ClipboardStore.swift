import Combine
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published var selectedID: ClipboardItem.ID?
    @Published var query = "" {
        didSet { reload() }
    }
    @Published var filter: ClipboardFilter = .history {
        didSet { reload() }
    }

    private let repository: ClipboardRepository
    private let writer: ClipboardWriter

    init(repository: ClipboardRepository, writer: ClipboardWriter) {
        self.repository = repository
        self.writer = writer
    }

    var selectedItem: ClipboardItem? {
        items.first { $0.id == selectedID } ?? items.first
    }

    func reload() {
        do {
            items = try repository.fetchItems(query: query, filter: filter)
            if selectedID == nil || !items.contains(where: { $0.id == selectedID }) {
                selectedID = items.first?.id
            }
        } catch {
            NSLog("Failed to load clipboard items: \(error)")
        }
    }

    func select(_ item: ClipboardItem) {
        selectedID = item.id
    }

    func copySelected() {
        guard let selectedItem else { return }
        writer.write(selectedItem)
    }

    func togglePinSelected() {
        guard let selectedItem else { return }
        do {
            try repository.setPinned(id: selectedItem.id, isPinned: !selectedItem.isPinned)
            reload()
        } catch {
            NSLog("Failed to update pin: \(error)")
        }
    }

    func deleteSelected() {
        guard let selectedItem else { return }
        do {
            try repository.delete(id: selectedItem.id)
            reload()
        } catch {
            NSLog("Failed to delete item: \(error)")
        }
    }
}
