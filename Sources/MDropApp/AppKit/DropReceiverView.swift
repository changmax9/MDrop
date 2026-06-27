import AppKit
import MDropCore
import SwiftUI

struct DropReceiverView: NSViewRepresentable {
    let onTargeted: (Bool) -> Void
    let onDrop: ([DropRepresentation]) -> Void

    func makeNSView(context: Context) -> DropReceiverNSView {
        let view = DropReceiverNSView()
        view.onTargeted = onTargeted
        view.onDrop = onDrop
        return view
    }

    func updateNSView(_ nsView: DropReceiverNSView, context: Context) {
        nsView.onTargeted = onTargeted
        nsView.onDrop = onDrop
    }
}

final class DropReceiverNSView: NSView {
    var onTargeted: ((Bool) -> Void)?
    var onDrop: (([DropRepresentation]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .URL, .string, .png, .tiff])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL, .string, .png, .tiff])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onTargeted?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargeted?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let representations = PasteboardReader.representations(from: sender.draggingPasteboard)
        guard !representations.isEmpty else { return false }
        onTargeted?(false)
        onDrop?(representations)
        return true
    }
}
