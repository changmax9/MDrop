import AppKit
import QuartzCore
import CoreGraphics
import Foundation
import MDropCore
import Testing
@testable import MDropApp

@Suite("Lightweight Shelf presentation")
struct ShelfVisualPolishTests {
    @MainActor
    @Test("Native instant-action glass stays circular and aligned through expansion")
    func instantActionGlassGeometry() throws {
        let view = InstantActionGlassView(frame: NSRect(x: 0, y: 0, width: 198, height: 44))
        view.update(count: 4, expanded: true, reduceMotion: true)
        let content = try #require(view.contentView)
        let surfaces = content.subviews.compactMap { $0 as? NSGlassEffectView }
        #expect(surfaces.count == 4)
        #expect(surfaces.allSatisfy { $0.style == .clear })
        for (index, surface) in surfaces.enumerated() {
            let expectedX = 99 + ShelfInstantActionLayout.horizontalOffset(
                index: index, buttonCount: 4, isExpanded: true
            )
            #expect(abs(surface.frame.midX - expectedX) < 0.5)
            #expect(surface.frame.midY == 22)
            #expect(surface.cornerRadius == surface.frame.width / 2)
            #expect(surface.alphaValue == 1)
            #expect(view.bounds.contains(surface.frame))
        }
        view.update(count: 4, expanded: false, reduceMotion: true)
        #expect(surfaces.filter { $0.alphaValue == 1 }.count == 1)
        #expect(surfaces[0].frame.midX == 99)
        #expect(abs(surfaces[0].frame.width - ShelfInstantActionLayout.entryVisibleDiameter) < 0.5)
        view.update(count: 0, expanded: false, reduceMotion: true)
        #expect(surfaces.allSatisfy { $0.alphaValue == 0 })
    }

    @MainActor
    @Test("The native glass ancestor leaves corner pixels transparent after resizing")
    func nativeGlassCornersStayTransparent() throws {
        let container = ShelfDropContainerView(frame: CGRect(x: 0, y: 0, width: 198, height: 207))
        container.setGlassCornerRadius(ShelfChromeStyle.cornerRadius(for: .empty))
        let layer = try #require(container.layer)
        let backdrop = CALayer()
        backdrop.backgroundColor = NSColor.red.cgColor
        layer.addSublayer(backdrop)
        for (state, width, height) in [
            (ShelfPresentationState.empty, 198, 207),
            (.compact, 198, 207),
            (.detail, 400, 300),
            (.docked, 92, 250)
        ] {
            container.setFrameSize(CGSize(width: width, height: height))
            container.setGlassCornerRadius(ShelfChromeStyle.cornerRadius(for: state))
            backdrop.frame = container.bounds
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            try pixels.withUnsafeMutableBytes { buffer in
                let context = try #require(CGContext(
                    data: buffer.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ))
                layer.render(in: context)
            }
            for (x, y) in [(1, 1), (width - 2, 1), (1, height - 2), (width - 2, height - 2)] {
                #expect(pixels[(y * width + x) * 4 + 3] == 0)
            }
            #expect(pixels[((height / 2) * width + width / 2) * 4 + 3] == 255)
        }
    }

    @Test("Root glass surface clips its external halo to the same corners")
    func rootGlassSurfaceUsesSharedCornerClip() throws {
        let source = try String(
            contentsOf: repositoryRoot.appending(
                path: "Sources/MDropApp/Views/ShelfView.swift"
            ),
            encoding: .utf8
        )
        let normalizedSource = source.filter { !$0.isWhitespace }
        let glassMarker =
            ".glassEffect(.regular,in:.rect(cornerRadius:animatedCornerRadius))"
        let glassRange = try #require(
            normalizedSource.range(of: glassMarker)
        )
        let glassIDRange = try #require(
            normalizedSource.range(
                of: ".glassEffectID(",
                range: glassRange.upperBound..<normalizedSource.endIndex
            )
        )
        let rootGlassSurface = normalizedSource[
            glassRange.upperBound..<glassIDRange.lowerBound
        ]

        #expect(rootGlassSurface.contains(".clipShape("))
        #expect(
            rootGlassSurface.contains(
                "cornerRadius:animatedCornerRadius"
            )
        )
        #expect(rootGlassSurface.contains("RoundedRectangle"))
    }

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

        #expect(metadata[fileItem.id]?.byteCount == 2_048)
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

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
