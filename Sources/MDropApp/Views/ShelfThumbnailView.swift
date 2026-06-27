import AppKit
import MDropCore
import SwiftUI

struct ShelfThumbnailView: View {
    let item: ShelfItemRecord
    var size: CGSize

    @Environment(\.displayScale) private var displayScale
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(nsImage: fallbackImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size.width, height: size.height)
        .task(id: taskIdentity) {
            guard let url = item.fileURL else { return }
            image = await ThumbnailService.shared.thumbnail(
                for: url,
                size: size,
                scale: displayScale
            )
        }
        .accessibilityLabel(item.displayName)
    }

    private var taskIdentity: String {
        [
            item.id.uuidString,
            String(Int(size.width)),
            String(Int(size.height)),
            String(Int(displayScale))
        ].joined(separator: "-")
    }

    private var fallbackImage: NSImage {
        switch item.payload {
        case .file:
            guard let url = item.fileURL else {
                return systemImage("exclamationmark.triangle")
            }
            return NSWorkspace.shared.icon(forFile: url.path)
        case .text:
            return systemImage("text.quote")
        case .url:
            return systemImage("link")
        }
    }

    private func systemImage(_ name: String) -> NSImage {
        NSImage(
            systemSymbolName: name,
            accessibilityDescription: item.displayName
        ) ?? NSImage()
    }
}
