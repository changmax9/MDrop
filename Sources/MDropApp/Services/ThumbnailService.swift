import AppKit
import MDropCore
import QuickLookThumbnailing

@MainActor
final class ThumbnailService {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 256
        cache.totalCostLimit = 64 * 1_024 * 1_024
    }

    func thumbnail(
        for url: URL,
        size: CGSize,
        scale: CGFloat
    ) async -> NSImage {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let key = ThumbnailCacheKey(
            url: url,
            modificationDate: values?.contentModificationDate,
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded()),
            scale: Int(scale.rounded())
        )
        let cacheKey = makeCacheKey(key)
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: [.thumbnail, .icon]
        )
        let image: NSImage
        do {
            let representation = try await QLThumbnailGenerator.shared
                .generateBestRepresentation(for: request)
            image = representation.nsImage
        } catch {
            image = NSWorkspace.shared.icon(forFile: url.path)
        }

        let pixelCost = max(
            1,
            Int(size.width * size.height * scale * scale * 4)
        )
        cache.setObject(image, forKey: cacheKey, cost: pixelCost)
        return image
    }

    private func makeCacheKey(_ key: ThumbnailCacheKey) -> NSString {
        let modified = key.modificationDate?.timeIntervalSinceReferenceDate ?? -1
        return "\(key.standardizedPath)|\(modified)|\(key.width)x\(key.height)@\(key.scale)" as NSString
    }
}
