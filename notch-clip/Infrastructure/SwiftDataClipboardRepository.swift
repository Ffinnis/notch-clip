import Foundation
import SwiftData

private enum ClipboardRetention {
    nonisolated static let defaultMaxUnpinnedItemAge: TimeInterval = 7 * 24 * 60 * 60
}

@Model
final class StoredClipboardItem {
    var id: UUID
    var createdAt: Date
    var sourceApp: String?
    var isPinned: Bool
    var kindRawValue: String
    var displayTitle: String
    var previewText: String
    @Attribute(.unique) var contentHash: String

    @Relationship(deleteRule: .cascade, inverse: \StoredPasteboardRepresentation.item)
    var representations: [StoredPasteboardRepresentation]

    init(item: ClipboardItem) {
        self.id = item.id
        self.createdAt = item.createdAt
        self.sourceApp = item.sourceApp
        self.isPinned = item.isPinned
        self.kindRawValue = item.kind.rawValue
        self.displayTitle = item.displayTitle
        self.previewText = item.previewText
        self.contentHash = item.contentHash
        self.representations = item.representations.map(StoredPasteboardRepresentation.init)
    }
}

@Model
final class StoredPasteboardRepresentation {
    var id: UUID
    var itemIndex: Int
    var type: String
    var data: Data
    var item: StoredClipboardItem?

    init(representation: PasteboardRepresentation) {
        self.id = representation.id
        self.itemIndex = representation.itemIndex
        self.type = representation.type
        self.data = representation.data
    }
}

@MainActor
final class SwiftDataClipboardRepository: ClipboardRepository {
    private let context: ModelContext
    private let maxItems: Int
    private let maxUnpinnedItemAge: TimeInterval

    init(
        container: ModelContainer,
        maxItems: Int = 250,
        maxUnpinnedItemAge: TimeInterval = ClipboardRetention.defaultMaxUnpinnedItemAge
    ) {
        self.context = ModelContext(container)
        self.maxItems = maxItems
        self.maxUnpinnedItemAge = maxUnpinnedItemAge
    }

    func fetchItems(query: String, filter: ClipboardFilter) throws -> [ClipboardItem] {
        var descriptor = FetchDescriptor<StoredClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.representations]

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return try context.fetch(descriptor)
            .compactMap(map)
            .filter { item in
                switch filter {
                case .history:
                    true
                case .pins:
                    item.isPinned
                }
            }
            .filter { item in
                guard !normalizedQuery.isEmpty else { return true }
                return item.displayTitle.lowercased().contains(normalizedQuery)
                    || item.previewText.lowercased().contains(normalizedQuery)
                    || item.kind.title.lowercased().contains(normalizedQuery)
                    || (item.sourceApp?.lowercased().contains(normalizedQuery) ?? false)
            }
    }

    func saveCapturedItem(_ item: ClipboardItem) throws {
        if try existingItem(contentHash: item.contentHash) != nil {
            return
        }

        context.insert(StoredClipboardItem(item: item))
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let item = try existingItem(id: id) else { return }
        context.delete(item)
        try context.save()
    }

    func setPinned(id: UUID, isPinned: Bool) throws {
        guard let item = try existingItem(id: id) else { return }
        item.isPinned = isPinned
        try context.save()
    }

    func pruneIfNeeded(now: Date) throws {
        let descriptor = FetchDescriptor<StoredClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let allItems = try context.fetch(descriptor)
        let expirationDate = now.addingTimeInterval(-maxUnpinnedItemAge)
        var deletedIDs = Set<UUID>()

        for item in allItems where !item.isPinned && item.createdAt < expirationDate {
            deletedIDs.insert(item.id)
            context.delete(item)
        }

        let removable = allItems.filter { !$0.isPinned && !deletedIDs.contains($0.id) }
        removable
            .dropFirst(maxItems)
            .forEach { item in
                deletedIDs.insert(item.id)
                context.delete(item)
            }

        if !deletedIDs.isEmpty {
            try context.save()
        }
    }

    private func existingItem(id: UUID) throws -> StoredClipboardItem? {
        var descriptor = FetchDescriptor<StoredClipboardItem>(
            predicate: #Predicate { item in
                item.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func existingItem(contentHash: String) throws -> StoredClipboardItem? {
        var descriptor = FetchDescriptor<StoredClipboardItem>(
            predicate: #Predicate { item in
                item.contentHash == contentHash
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func map(_ storedItem: StoredClipboardItem) -> ClipboardItem? {
        let representations = storedItem.representations
            .sorted { lhs, rhs in
                if lhs.itemIndex == rhs.itemIndex {
                    return lhs.type < rhs.type
                }
                return lhs.itemIndex < rhs.itemIndex
            }
            .map {
                PasteboardRepresentation(
                    id: $0.id,
                    itemIndex: $0.itemIndex,
                    type: $0.type,
                    data: $0.data
                )
            }

        let content = ClipboardClassifier.classify(representations)

        return ClipboardItem(
            id: storedItem.id,
            createdAt: storedItem.createdAt,
            sourceApp: storedItem.sourceApp,
            isPinned: storedItem.isPinned,
            content: content,
            displayTitle: storedItem.displayTitle,
            previewText: storedItem.previewText,
            contentHash: storedItem.contentHash,
            representations: representations
        )
    }
}

@MainActor
final class InMemoryClipboardRepository: ClipboardRepository {
    private var items: [ClipboardItem] = []
    private let maxItems: Int
    private let maxUnpinnedItemAge: TimeInterval

    init(maxItems: Int = 250, maxUnpinnedItemAge: TimeInterval = ClipboardRetention.defaultMaxUnpinnedItemAge) {
        self.maxItems = maxItems
        self.maxUnpinnedItemAge = maxUnpinnedItemAge
    }

    func fetchItems(query: String, filter: ClipboardFilter) throws -> [ClipboardItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items
            .sorted { $0.createdAt > $1.createdAt }
            .filter { item in
                switch filter {
                case .history:
                    true
                case .pins:
                    item.isPinned
                }
            }
            .filter { item in
                guard !normalizedQuery.isEmpty else { return true }
                return item.displayTitle.lowercased().contains(normalizedQuery)
                    || item.previewText.lowercased().contains(normalizedQuery)
                    || item.kind.title.lowercased().contains(normalizedQuery)
                    || (item.sourceApp?.lowercased().contains(normalizedQuery) ?? false)
            }
    }

    func saveCapturedItem(_ item: ClipboardItem) throws {
        guard !items.contains(where: { $0.contentHash == item.contentHash }) else { return }
        items.append(item)
    }

    func delete(id: UUID) throws {
        items.removeAll { $0.id == id }
    }

    func setPinned(id: UUID, isPinned: Bool) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned = isPinned
    }

    func pruneIfNeeded(now: Date) throws {
        let expirationDate = now.addingTimeInterval(-maxUnpinnedItemAge)
        var removableIDs = Set(
            items
                .filter { !$0.isPinned && $0.createdAt < expirationDate }
                .map(\.id)
        )

        let removable = items
            .sorted { $0.createdAt > $1.createdAt }
            .filter { !$0.isPinned && !removableIDs.contains($0.id) }

        removableIDs.formUnion(removable.dropFirst(maxItems).map(\.id))

        if !removableIDs.isEmpty {
            items.removeAll { removableIDs.contains($0.id) }
        }
    }
}
