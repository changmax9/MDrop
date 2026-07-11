import Foundation
import MDropCore
import PDFKit

enum ShelfFileMetadataLoader {
    static let refreshInterval: Duration = .seconds(30)
    private static let maximumConcurrentLoads = 4

    static func metadata(
        for items: [ShelfItemRecord]
    ) async -> [UUID: ShelfFileMetadata] {
        await withTaskGroup(
            of: (UUID, ShelfFileMetadata).self,
            returning: [UUID: ShelfFileMetadata].self
        ) { group in
            var iterator = items.makeIterator()
            for _ in 0..<min(
                maximumConcurrentLoads,
                items.count
            ) {
                guard let item = iterator.next() else { break }
                add(item, to: &group)
            }

            var result: [UUID: ShelfFileMetadata] = [:]
            while let (id, metadata) = await group.next() {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    break
                }
                result[id] = metadata
                if let item = iterator.next() {
                    add(item, to: &group)
                }
            }
            return result
        }
    }

    private static func add(
        _ item: ShelfItemRecord,
        to group: inout TaskGroup<(UUID, ShelfFileMetadata)>
    ) {
        group.addTask(priority: .utility) {
            guard !Task.isCancelled else {
                return (item.id, .empty)
            }
            return (item.id, loadMetadata(for: item))
        }
    }

    private static func loadMetadata(
        for item: ShelfItemRecord
    ) -> ShelfFileMetadata {
        guard let url = item.fileURL else { return .empty }
        let values = try? url.resourceValues(
            forKeys: [
                .fileSizeKey,
                .totalFileAllocatedSizeKey
            ]
        )
        let byteCount = Int64(
            values?.totalFileAllocatedSize
                ?? values?.fileSize
                ?? 0
        )
        let pageCount: Int?
        if !Task.isCancelled,
           url.pathExtension.lowercased() == "pdf" {
            pageCount = PDFDocument(url: url)?.pageCount
        } else {
            pageCount = nil
        }
        return ShelfFileMetadata(
            byteCount: byteCount,
            pdfPageCount: pageCount
        )
    }
}

struct ShelfFileMetadata: Equatable, Sendable {
    let byteCount: Int64
    let pdfPageCount: Int?

    static let empty = Self(
        byteCount: 0,
        pdfPageCount: nil
    )
}
