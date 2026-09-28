import AppKit
import MDropCore
import Testing
@testable import MDropApp

@MainActor
@Suite("Native shelf drag source")
struct ShelfItemsDragSourceViewTests {
    @Test("Uses Finder modifiers unless always-copy is enabled")
    func sourceOperationPolicy() {
        #expect(
            ShelfItemsDragBehavior.sourceOperationMask(
                alwaysCopyDraggedItems: false
            ) == [.copy, .move]
        )
        #expect(
            !ShelfItemsDragBehavior.ignoresModifierKeys(
                alwaysCopyDraggedItems: false
            )
        )
        #expect(
            ShelfItemsDragBehavior.sourceOperationMask(
                alwaysCopyDraggedItems: true
            ) == .copy
        )
        #expect(
            ShelfItemsDragBehavior.ignoresModifierKeys(
                alwaysCopyDraggedItems: true
            )
        )
    }

    @Test("Cancelled and Shift-modified drags keep the Shelf")
    func cancelledAndShiftModifiedDragsKeepShelf() {
        let itemID = UUID()
        let cancelled = ShelfItemsDragCompletion(
            draggedItemIDs: [itemID],
            operation: [],
            modifierFlags: []
        )
        let shifted = ShelfItemsDragCompletion(
            draggedItemIDs: [itemID],
            operation: .copy,
            modifierFlags: .shift
        )

        #expect(
            ShelfItemsDragBehavior.completionAction(
                shelfItemIDs: [itemID],
                completion: cancelled
            ) == .none
        )
        #expect(
            ShelfItemsDragBehavior.completionAction(
                shelfItemIDs: [itemID],
                completion: shifted
            ) == .none
        )
    }

    @Test("Successful subset drag removes only dragged items")
    func successfulSubsetDragRemovesOnlyDraggedItems() {
        let draggedItemID = UUID()
        let keptItemID = UUID()
        let completion = ShelfItemsDragCompletion(
            draggedItemIDs: [draggedItemID],
            operation: .move,
            modifierFlags: []
        )

        #expect(
            ShelfItemsDragBehavior.completionAction(
                shelfItemIDs: [draggedItemID, keptItemID],
                completion: completion
            ) == .remove(itemIDs: [draggedItemID])
        )
    }

    @Test("Successful whole-Shelf drag closes the Shelf")
    func successfulWholeShelfDragClosesShelf() {
        let itemIDs = [UUID(), UUID(), UUID()]
        let completion = ShelfItemsDragCompletion(
            draggedItemIDs: Set(itemIDs),
            operation: .copy,
            modifierFlags: []
        )

        #expect(
            ShelfItemsDragBehavior.completionAction(
                shelfItemIDs: itemIDs,
                completion: completion
            ) == .close(itemIDs: Set(itemIDs))
        )
    }

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
