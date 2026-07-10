import AppKit
import MDropCore

enum ShelfPasteboardWriter {
    @discardableResult
    static func write(
        _ items: [ShelfItemRecord],
        to pasteboard: NSPasteboard
    ) -> Bool {
        guard !items.isEmpty else { return false }

        let fileURLs = items.compactMap(\.fileURL)
        pasteboard.clearContents()

        if fileURLs.count == items.count {
            return pasteboard.writeObjects(fileURLs as [NSURL])
        }

        let values = items.map { item in
            switch item.payload {
            case let .file(reference):
                reference.resolvedURL().path
            case let .text(value):
                value
            case let .url(url):
                url.absoluteString
            }
        }
        return pasteboard.setString(
            values.joined(separator: "\n"),
            forType: .string
        )
    }
}
