import AppKit
import MDropCore

final class StatusDropReceiverView: DropReceiverNSView {
    struct DropGatePolicy {
        let acceptsDrop: Bool

        var advertisedOperation: NSDragOperation {
            acceptsDrop ? .copy : []
        }

        var shouldReadPasteboard: Bool {
            acceptsDrop
        }
    }

    var onClick: (() -> Void)?
    var canAcceptDrop: () -> Bool = { true }
    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func accepts(_ sender: NSDraggingInfo) -> Bool {
        dropGatePolicy().shouldReadPasteboard
    }

    static func dropGatePolicy(isEnabled: Bool) -> DropGatePolicy {
        DropGatePolicy(acceptsDrop: isEnabled)
    }

    private func dropGatePolicy() -> DropGatePolicy {
        Self.dropGatePolicy(isEnabled: canAcceptDrop())
    }
}
