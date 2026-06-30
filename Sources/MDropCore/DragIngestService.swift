import Foundation

public enum DropRepresentation: Sendable {
    case file(URL)
    case text(String)
    case url(URL)
    case binary(Data, suggestedFilename: String)
}

public struct DragIngestService: Sendable {
    public let stagingDirectory: URL

    public init(stagingDirectory: URL) {
        self.stagingDirectory = stagingDirectory
    }

    public func ingest(
        _ representations: [DropRepresentation],
        now: Date = .now
    ) throws -> [ShelfItemRecord] {
        var items: [ShelfItemRecord] = []
        var seenFilePaths = Set<String>()

        for representation in representations {
            switch representation {
            case let .file(url):
                let normalizedURL = url.standardizedFileURL
                guard seenFilePaths.insert(normalizedURL.path).inserted else {
                    continue
                }
                items.append(fileItem(for: normalizedURL, now: now))

            case let .text(value):
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                items.append(.text(trimmed, now: now))

            case let .url(url):
                items.append(
                    ShelfItemRecord(
                        payload: .url(url),
                        displayName: url.host() ?? url.absoluteString,
                        createdAt: now
                    )
                )

            case let .binary(data, suggestedFilename):
                let stagedURL = try stage(data, suggestedFilename: suggestedFilename)
                items.append(fileItem(for: stagedURL, now: now))
            }
        }

        return items
    }

    private func fileItem(for url: URL, now: Date) -> ShelfItemRecord {
        let bookmark = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return ShelfItemRecord(
            payload: .file(FileReference(url: url, bookmarkData: bookmark)),
            displayName: url.lastPathComponent,
            createdAt: now
        )
    }

    private func stage(_ data: Data, suggestedFilename: String) throws -> URL {
        try FileManager.default.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: true
        )

        let safeName = URL(filePath: suggestedFilename).lastPathComponent
        let preferredName = safeName.isEmpty ? "Dropped Item" : safeName
        var destination = stagingDirectory.appending(path: preferredName)
        if FileManager.default.fileExists(atPath: destination.path) {
            let stem = destination.deletingPathExtension().lastPathComponent
            let pathExtension = destination.pathExtension
            let suffix = UUID().uuidString.prefix(8)
            let uniqueName = pathExtension.isEmpty
                ? "\(stem)-\(suffix)"
                : "\(stem)-\(suffix).\(pathExtension)"
            destination = stagingDirectory.appending(path: uniqueName)
        }

        try data.write(to: destination, options: .atomic)
        return destination
    }
}
