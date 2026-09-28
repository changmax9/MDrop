import AppKit
import MDropCore
import Testing
@testable import MDropApp

@MainActor
@Suite("Inbound drop lifecycle")
struct DropReceivingTests {
    @Test("A file's text fallback is not collected as a second item")
    func fileFallbackIsNotDuplicated() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("file:///tmp/Example%20File.txt", forType: .fileURL)
        item.setString("/tmp/Example File.txt", forType: .string)
        pasteboard.writeObjects([item])
        let result = PasteboardReader.representations(from: pasteboard)
        #expect(result.count == 1)
        guard case let .file(url) = try #require(result.first) else {
            Issue.record("Expected the file representation")
            return
        }
        #expect(url.path == "/tmp/Example File.txt")
    }

    @Test("Mixed files, links, image data, and text retain their source order")
    func mixedPayloadOrder() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let file = NSPasteboardItem()
        file.setString("file:///tmp/One.txt", forType: .fileURL)
        let link = NSPasteboardItem()
        link.setString("https://example.com", forType: .URL)
        link.setString("Example", forType: .string)
        let image = NSPasteboardItem()
        image.setData(Data([1, 2, 3]), forType: .png)
        image.setString("Image caption", forType: .string)
        let text = NSPasteboardItem()
        text.setString("A note", forType: .string)
        pasteboard.writeObjects([file, link, image, text])
        let kinds = PasteboardReader.representations(from: pasteboard).map { item in
            switch item {
            case .file: "file"
            case .url: "url"
            case .binary: "image"
            case .text: "text"
            }
        }
        #expect(kinds == ["file", "url", "image", "text"])
    }

    @Test("Unsupported payloads and move-only drags are rejected")
    func operationNegotiation() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("unknown", forType: .init("test.unsupported"))
        #expect(DragPasteboardReceiver.operation(for: pasteboard, sourceMask: .every).isEmpty)
        pasteboard.clearContents()
        pasteboard.setString("A note", forType: .string)
        #expect(DragPasteboardReceiver.operation(for: pasteboard, sourceMask: [.move, .delete]).isEmpty)
        #expect(DragPasteboardReceiver.operation(for: pasteboard, sourceMask: [.copy, .move]) == .copy)
        #expect(DragPasteboardReceiver.operation(for: pasteboard, sourceMask: .generic) == .generic)
        #expect(DragPasteboardReceiver.operation(for: pasteboard, sourceMask: .link) == .link)
    }

    @Test("Leaving or cancelling a drag resets both the target and its count")
    func dragCancellationClearsFeedback() {
        let info = TestDraggingInfo()
        defer { info.draggingPasteboard.releaseGlobally() }
        info.draggingPasteboard.setString("Hello", forType: .string)
        let view = DropReceiverNSView(frame: NSRect(x: 0, y: 0, width: 198, height: 207))
        var isTargeted = false
        var count = 0
        view.onTargeted = { isTargeted = $0 }
        view.onTargetedItemCount = { count = $0 }
        #expect(view.draggingEntered(info) == .copy)
        #expect(isTargeted && count == 1)
        view.draggingExited(info)
        #expect(!isTargeted && count == 0)
        _ = view.draggingEntered(info)
        view.draggingEnded(info)
        #expect(!isTargeted && count == 0)
    }

    @Test("A source-mask change during hover withdraws acceptance")
    func updatedOperationClearsTarget() {
        let info = TestDraggingInfo()
        defer { info.draggingPasteboard.releaseGlobally() }
        info.draggingPasteboard.setString("Hello", forType: .string)
        let view = DropReceiverNSView()
        var isTargeted = false
        view.onTargeted = { isTargeted = $0 }
        _ = view.draggingEntered(info)
        info.draggingSourceOperationMask = .move
        #expect(view.draggingUpdated(info).isEmpty)
        #expect(!isTargeted)
        #expect(!view.prepareForDragOperation(info))
    }

    @Test("A successful drop is delivered once and clears hover state")
    func successfulDrop() {
        let info = TestDraggingInfo()
        defer { info.draggingPasteboard.releaseGlobally() }
        info.draggingPasteboard.setString("Hello", forType: .string)
        let view = DropReceiverNSView()
        var delivered = 0
        var targeted = false
        view.onDrop = { delivered += $0.count }
        view.onTargeted = { targeted = $0 }
        _ = view.draggingEntered(info)
        #expect(view.performDragOperation(info))
        #expect(delivered == 1 && !targeted)
    }

    @Test("A shelf cannot collect its own drag, but accepts another shelf")
    func ownShelfRejection() {
        _ = NSApplication.shared
        let first = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        let second = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        let view = ShelfDropContainerView()
        first.contentView = view
        let info = TestDraggingInfo()
        defer { info.draggingPasteboard.releaseGlobally() }
        info.draggingPasteboard.setString("Hello", forType: .string)
        info.draggingSource = first
        #expect(view.draggingEntered(info).isEmpty)
        info.draggingSource = second
        #expect(view.draggingEntered(info) == .copy)
    }

    @Test("Menu bar disabling is enforced on enter and at the final drop")
    func disabledMenuBarCannotIngest() {
        let info = TestDraggingInfo()
        defer { info.draggingPasteboard.releaseGlobally() }
        info.draggingPasteboard.setString("Hello", forType: .string)
        let view = StatusDropReceiverView()
        var enabled = true
        var delivered = 0
        view.canAcceptDrop = { enabled }
        view.onDrop = { delivered += $0.count }
        #expect(view.draggingEntered(info) == .copy)
        enabled = false
        #expect(view.draggingUpdated(info).isEmpty)
        #expect(!view.performDragOperation(info))
        #expect(delivered == 0)
    }

    @Test("File promises aggregate out-of-order completion, partial failures, and multiple files")
    func promiseBatchCompletesOnce() {
        var delivered: [URL] = []
        var errorReported = false
        var completions = 0
        let batch = PromisedDropBatch(fileCounts: [2, 1]) { items, error in
            completions += 1
            delivered = items.compactMap { if case let .file(url) = $0 { url } else { nil } }
            errorReported = error != nil
        }
        let first = URL(filePath: "/tmp/first.txt")
        let second = URL(filePath: "/tmp/second.txt")
        batch.receive(second, error: nil, at: 1)
        batch.receive(first, error: nil, at: 0)
        #expect(completions == 0)
        batch.receive(first, error: CocoaError(.fileReadUnknown), at: 0)
        #expect(completions == 1 && errorReported)
        #expect(delivered == [first, second])
        batch.receive(first, error: nil, at: 0)
        #expect(completions == 1)
    }

    @Test("Overlapping imports keep busy feedback until both finish")
    func concurrentImportFeedback() throws {
        let store = ShelfStore(shelf: ShelfRecord())
        store.beginImport()
        store.beginImport()
        store.endImport()
        #expect(store.isImporting)
        store.endImport()
        #expect(!store.isImporting)
        store.confirmDrop(count: 2)
        let oldID = try #require(store.dropReceipt?.id)
        store.confirmDrop(count: 3)
        store.clearDropReceipt(id: oldID)
        #expect(store.dropReceipt?.count == 3)
        store.beginImport()
        #expect(store.dropReceipt == nil)
    }
}

@MainActor
private final class TestDraggingInfo: NSObject, NSDraggingInfo {
    var draggingDestinationWindow: NSWindow?
    var draggingSourceOperationMask: NSDragOperation = .copy
    var draggingLocation: NSPoint = .zero
    var draggedImageLocation: NSPoint = .zero
    nonisolated var draggedImage: NSImage? { nil }
    let draggingPasteboard = NSPasteboard.withUniqueName()
    var draggingSource: Any?
    var draggingSequenceNumber = 1
    var draggingFormation: NSDraggingFormation = .default
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 0
    var springLoadingHighlight: NSSpringLoadingHighlight = .none
    func slideDraggedImage(to screenPoint: NSPoint) {}
    nonisolated override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(
        options enumOpts: NSDraggingItemEnumerationOptions = [],
        for view: NSView?,
        classes classArray: [AnyClass],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {}
}
