import AppKit
import MDropCore

@MainActor
enum PasteboardReader {
    static func representations(from pasteboard: NSPasteboard) -> [DropRepresentation] {
        // One logical item can advertise a file, image, URL, and plain-text fallback.
        // Choose its richest representation instead of adding the fallback as another item.
        (pasteboard.pasteboardItems ?? []).compactMap { item in
            if let value = item.string(forType: .fileURL),
               let url = URL(string: value), url.isFileURL {
                return .file(url)
            }
            if let value = item.string(forType: .URL),
               let url = URL(string: value), url.scheme != nil {
                return url.isFileURL ? .file(url) : .url(url)
            }
            if let data = item.data(forType: .png), !data.isEmpty {
                return .binary(data, suggestedFilename: "Dropped Image.png")
            }
            if let data = item.data(forType: .tiff), !data.isEmpty {
                return .binary(data, suggestedFilename: "Dropped Image.tiff")
            }
            if let string = item.string(forType: .string),
               !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .text(string)
            }
            return nil
        }
    }
}
