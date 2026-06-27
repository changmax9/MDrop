import AppKit
import MDropCore

final class StatusDropReceiverView: NSView {
    var onClick: (() -> Void)?
    var onDrop: (([DropRepresentation]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(
            [.fileURL, .URL, .string, .png, .tiff] +
            NSFilePromiseReceiver.readableDraggedTypes.map {
                NSPasteboard.PasteboardType(rawValue: $0)
            }
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        DragPasteboardReceiver.perform(sender, onDrop: onDrop)
    }
}
