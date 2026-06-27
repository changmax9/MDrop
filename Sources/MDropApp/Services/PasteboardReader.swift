import AppKit
import MDropCore

enum PasteboardReader {
    static func representations(from pasteboard: NSPasteboard) -> [DropRepresentation] {
        var result: [DropRepresentation] = []
        let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        result.append(contentsOf: fileURLs.map(DropRepresentation.file))

        for item in pasteboard.pasteboardItems ?? [] {
            if let urlString = item.string(forType: .URL),
               let url = URL(string: urlString),
               !url.isFileURL {
                result.append(.url(url))
                continue
            }
            if let string = item.string(forType: .string),
               !string.isEmpty,
               !fileURLs.contains(where: { $0.absoluteString == string }) {
                result.append(.text(string))
                continue
            }
            if let data = item.data(forType: .png) {
                result.append(.binary(data, suggestedFilename: "Dropped Image.png"))
            } else if let data = item.data(forType: .tiff) {
                result.append(.binary(data, suggestedFilename: "Dropped Image.tiff"))
            }
        }
        return result
    }
}
