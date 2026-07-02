import AppKit
import MDropCore
import Testing
@testable import MDropApp

@MainActor
@Suite("Native shelf drag source")
struct ShelfItemsDragSourceViewTests {
    @Test("Creates one pasteboard item for every file")
    func createsOnePasteboardItemForEveryFile() {
        let urls = [
            URL(fileURLWithPath: "/tmp/one.txt"),
            URL(fileURLWithPath: "/tmp/two.txt"),
            URL(fileURLWithPath: "/tmp/three.txt")
        ]
        let view = ShelfItemsDragSourceNSView()
        view.items = urls.map {
            ShelfItemRecord(
                payload: .file(FileReference(url: $0)),
                displayName: $0.lastPathComponent
            )
        }

        let draggingItems = view.makeDraggingItems(
            at: CGPoint(x: 50, y: 50)
        )

        #expect(draggingItems.count == urls.count)
        #expect(
            draggingItems.compactMap { $0.item as? NSURL }
                .map { $0 as URL }
                == urls
        )

        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let writers = draggingItems.compactMap {
            $0.item as? any NSPasteboardWriting
        }

        #expect(pasteboard.writeObjects(writers))
        #expect(pasteboard.pasteboardItems?.count == urls.count)
        #expect(
            pasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            )?.count == urls.count
        )
    }
}
