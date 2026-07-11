import CoreGraphics
import Foundation
import MDropCore
import Testing
@testable import MDropApp

@Suite("Lightweight Shelf presentation")
struct ShelfVisualPolishTests {
    @Test("Chrome depth stays restrained")
    func chromeDepthStaysRestrained() {
        #expect(ShelfChromeStyle.outerStrokeOpacity <= 0.10)
        #expect(ShelfChromeStyle.cardRestingShadowOpacity <= 0.10)
        #expect(ShelfChromeStyle.cardHoverShadowOpacity <= 0.16)
        #expect(ShelfChromeStyle.controlRestingShadowOpacityDark <= 0.14)
        #expect(ShelfChromeStyle.controlHoverShadowOpacityDark <= 0.22)
        #expect(ShelfChromeStyle.commandBarShadowOpacity <= 0.12)
        #expect(ShelfChromeStyle.commandBarShadowRadius <= 16)
    }

    @Test("File metadata is loaded outside the SwiftUI render path")
    func fileMetadataLoadsAsynchronously() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "MDrop Metadata Test-\(UUID()).txt")
        try Data(repeating: 0x41, count: 2_048).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let fileItem = ShelfItemRecord(
            payload: .file(FileReference(url: fileURL)),
            displayName: fileURL.lastPathComponent
        )
        let textItem = ShelfItemRecord.text("No file metadata")

        let metadata = await ShelfFileMetadataLoader.metadata(
            for: [fileItem, textItem]
        )

        #expect((metadata[fileItem.id]?.byteCount ?? 0) >= 2_048)
        #expect(metadata[fileItem.id]?.pdfPageCount == nil)
        #expect(metadata[textItem.id] == .empty)
    }

    @Test("Async metadata preserves PDF page counts")
    func asyncMetadataPreservesPDFPageCounts() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "MDrop Metadata Test-\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var mediaBox = CGRect(x: 0, y: 0, width: 100, height: 100)
        let consumer = try #require(
            CGDataConsumer(url: fileURL as CFURL)
        )
        let context = try #require(
            CGContext(
                consumer: consumer,
                mediaBox: &mediaBox,
                nil
            )
        )
        for _ in 0..<2 {
            context.beginPDFPage(nil)
            context.endPDFPage()
        }
        context.closePDF()

        let item = ShelfItemRecord(
            payload: .file(FileReference(url: fileURL)),
            displayName: fileURL.lastPathComponent
        )
        let metadata = await ShelfFileMetadataLoader.metadata(
            for: [item]
        )

        #expect(metadata[item.id]?.pdfPageCount == 2)
    }
}
