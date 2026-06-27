import Foundation

public enum BuiltinActionID: String, Codable, CaseIterable, Sendable {
    case systemShare
    case resizeImages
    case convertImages
    case compressImages
    case removeImageMetadata
    case stitchImages
    case extractText
    case createPDF
    case copyText
    case createArchive
    case copyTo
    case moveTo
    case rename
    case copyPath
    case moveToTrash
}

public enum ActionParameterValue: Codable, Hashable, Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case url(URL)
}

public struct ActionRequest: Sendable {
    public var items: [ShelfItemRecord]
    public var parameters: [String: ActionParameterValue]

    public init(
        items: [ShelfItemRecord],
        parameters: [String: ActionParameterValue] = [:]
    ) {
        self.items = items
        self.parameters = parameters
    }
}

public struct ActionResult: Sendable {
    public var createdFiles: [URL]
    public var clipboardText: String?
    public var shouldCloseShelf: Bool

    public init(
        createdFiles: [URL] = [],
        clipboardText: String? = nil,
        shouldCloseShelf: Bool = false
    ) {
        self.createdFiles = createdFiles
        self.clipboardText = clipboardText
        self.shouldCloseShelf = shouldCloseShelf
    }
}

public protocol ShelfAction: Sendable {
    var id: String { get }
    var title: String { get }
    func isAvailable(for items: [ShelfItemRecord]) -> Bool
    func run(
        _ request: ActionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> ActionResult
}

public enum BuiltinActionCatalog {
    private static let imageExtensions: Set<String> = [
        "avif", "bmp", "gif", "heic", "heif", "jpeg", "jpg", "png", "tif", "tiff", "webp"
    ]

    public static func availableActions(
        for items: [ShelfItemRecord]
    ) -> Set<BuiltinActionID> {
        guard !items.isEmpty else { return [] }

        var actions: Set<BuiltinActionID> = [.systemShare, .createArchive]
        let fileURLs = items.compactMap(\.fileURL)
        let allFiles = fileURLs.count == items.count
        let allImages = allFiles && fileURLs.allSatisfy {
            imageExtensions.contains($0.pathExtension.lowercased())
        }

        if allFiles {
            actions.formUnion([.copyTo, .moveTo, .rename, .copyPath, .moveToTrash])
        }

        if allImages {
            actions.formUnion([
                .resizeImages,
                .convertImages,
                .compressImages,
                .removeImageMetadata,
                .stitchImages,
                .extractText,
                .createPDF
            ])
        }

        if items.contains(where: \.containsText) {
            actions.insert(.copyText)
        }

        return actions
    }
}

public extension ShelfItemRecord {
    var fileURL: URL? {
        guard case let .file(reference) = payload else { return nil }
        return reference.resolvedURL()
    }

    var containsText: Bool {
        switch payload {
        case .text:
            true
        case let .file(reference):
            ["json", "md", "rtf", "txt", "xml", "yaml", "yml"]
                .contains(reference.url.pathExtension.lowercased())
        case .url:
            false
        }
    }
}
