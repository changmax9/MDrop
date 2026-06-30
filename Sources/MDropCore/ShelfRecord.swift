import Foundation

public enum DockedEdge: String, Codable, CaseIterable, Sendable {
    case left
    case right
}

public enum ShelfPresentationState: String, Codable, Sendable {
    case empty
    case compact
    case detail
    case instantActions
    case docked
}

public enum ShelfColorTag: String, Codable, CaseIterable, Sendable {
    case none
    case red
    case orange
    case yellow
    case green
    case mint
    case blue
    case purple
    case pink
}

public struct FileReference: Codable, Hashable, Sendable {
    public var url: URL
    public var bookmarkData: Data?

    public init(url: URL, bookmarkData: Data? = nil) {
        self.url = url
        self.bookmarkData = bookmarkData
    }

    public func resolvedURL() -> URL {
        guard let bookmarkData else { return url }
        var isStale = false
        return (
            try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        ) ?? url
    }
}

public enum ShelfItemPayload: Codable, Hashable, Sendable {
    case file(FileReference)
    case text(String)
    case url(URL)
}

public struct ShelfItemRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var payload: ShelfItemPayload
    public var displayName: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        payload: ShelfItemPayload,
        displayName: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.payload = payload
        self.displayName = displayName
        self.createdAt = createdAt
    }

    public static func text(
        _ value: String,
        id: UUID = UUID(),
        now: Date = .now
    ) -> Self {
        Self(
            id: id,
            payload: .text(value),
            displayName: value.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: now
        )
    }
}

public struct ShelfRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var colorTag: ShelfColorTag
    public var items: [ShelfItemRecord]
    public var isPinned: Bool
    public var presentationState: ShelfPresentationState
    public var dockedEdge: DockedEdge?
    public let createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        name: String = "",
        colorTag: ShelfColorTag = .none,
        items: [ShelfItemRecord] = [],
        isPinned: Bool = false,
        presentationState: ShelfPresentationState? = nil,
        dockedEdge: DockedEdge? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorTag = colorTag
        self.items = items
        self.isPinned = isPinned
        self.presentationState = presentationState ?? (items.isEmpty ? .empty : .compact)
        self.dockedEdge = dockedEdge
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    public var shouldAutoClose: Bool {
        items.isEmpty && !isPinned
    }

    public mutating func append(_ newItems: [ShelfItemRecord], now: Date = .now) {
        var seenFilePaths = Set(items.compactMap { item -> String? in
            guard case let .file(reference) = item.payload else { return nil }
            return reference.url.standardizedFileURL.path
        })
        let uniqueItems = newItems.filter { item in
            guard case let .file(reference) = item.payload else { return true }
            return seenFilePaths.insert(
                reference.url.standardizedFileURL.path
            ).inserted
        }
        guard !uniqueItems.isEmpty else { return }
        items.append(contentsOf: uniqueItems)
        presentationState = dockedEdge == nil ? .compact : .docked
        modifiedAt = now
    }

    public mutating func removeAll(now: Date = .now) {
        items.removeAll()
        presentationState = .empty
        modifiedAt = now
    }

    public mutating func moveItem(
        _ itemID: UUID,
        before destinationID: UUID,
        now: Date = .now
    ) {
        guard itemID != destinationID,
              let sourceIndex = items.firstIndex(where: { $0.id == itemID }),
              let originalDestinationIndex = items.firstIndex(where: {
                  $0.id == destinationID
              }) else {
            return
        }

        let item = items.remove(at: sourceIndex)
        let destinationIndex = sourceIndex < originalDestinationIndex
            ? originalDestinationIndex - 1
            : originalDestinationIndex
        items.insert(item, at: destinationIndex)
        modifiedAt = now
    }
}
