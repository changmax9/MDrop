import Foundation

public struct ShelfArchive: Codable, Equatable, Sendable {
    public var visible: [ShelfRecord]
    public var recent: [ShelfRecord]

    public init(visible: [ShelfRecord] = [], recent: [ShelfRecord] = []) {
        self.visible = visible
        self.recent = recent
    }
}

public actor ShelfRepository {
    private let fileURL: URL
    private let maxRecent: Int
    private var latestVisibleRevision = 0

    public init(fileURL: URL, maxRecent: Int = 10) {
        self.fileURL = fileURL
        self.maxRecent = maxRecent
    }

    public func load() throws -> ShelfArchive {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ShelfArchive()
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(ShelfArchive.self, from: data)
    }

    public func save(_ archive: ShelfArchive) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(archive).write(to: fileURL, options: .atomic)
    }

    public func rememberClosed(_ shelf: ShelfRecord) throws {
        var archive = try load()
        remember(shelf, in: &archive)
        try save(archive)
    }

    @discardableResult
    public func saveVisible(
        _ visible: [ShelfRecord],
        revision: Int
    ) throws -> ShelfArchive {
        var archive = try load()
        guard revision >= latestVisibleRevision else {
            return archive
        }
        archive.visible = visible
        latestVisibleRevision = revision
        try save(archive)
        return archive
    }

    @discardableResult
    public func closeShelf(
        _ shelf: ShelfRecord,
        visible: [ShelfRecord],
        revision: Int
    ) throws -> ShelfArchive {
        var archive = try load()
        remember(shelf, in: &archive)
        if revision >= latestVisibleRevision {
            archive.visible = visible
            latestVisibleRevision = revision
        }
        try save(archive)
        return archive
    }

    private func remember(
        _ shelf: ShelfRecord,
        in archive: inout ShelfArchive
    ) {
        archive.recent.removeAll { $0.id == shelf.id }
        archive.recent.append(shelf)

        let pinned = archive.recent
            .filter(\.isPinned)
            .sorted { $0.modifiedAt > $1.modifiedAt }
        let regular = archive.recent
            .filter { !$0.isPinned }
            .sorted { $0.modifiedAt > $1.modifiedAt }
        archive.recent = pinned + regular.prefix(maxRecent)
    }
}
