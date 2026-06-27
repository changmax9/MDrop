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
        archive.recent.removeAll { $0.id == shelf.id }
        archive.recent.insert(shelf, at: 0)

        let pinned = archive.recent.filter(\.isPinned)
        let regular = archive.recent.filter { !$0.isPinned }
        archive.recent = pinned + regular.prefix(maxRecent)
        try save(archive)
    }
}
