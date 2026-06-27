import Foundation

public struct ThumbnailCacheKey: Hashable, Sendable {
    public var standardizedPath: String
    public var modificationDate: Date?
    public var width: Int
    public var height: Int
    public var scale: Int

    public init(
        url: URL,
        modificationDate: Date?,
        width: Int,
        height: Int,
        scale: Int
    ) {
        standardizedPath = url.standardizedFileURL.path
        self.modificationDate = modificationDate
        self.width = width
        self.height = height
        self.scale = scale
    }
}
