import AppKit
import MDropCore
import SwiftUI

@MainActor
final class NotchDropController {
    private let panel: NSPanel
    private var hideTask: Task<Void, Never>?

    init(onDrop: @escaping ([DropRepresentation]) -> Void) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 58),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = NSHostingController(
            rootView: NotchDropView { [weak self] representations in
                onDrop(representations)
                self?.hide()
            }
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
    }

    func update(pointer: CGPoint) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) else {
            hide()
            return
        }
        let target = NSRect(
            x: screen.frame.midX - 170,
            y: screen.frame.maxY - 100,
            width: 340,
            height: 100
        )
        guard target.contains(pointer) else {
            hide()
            return
        }

        let origin = NSPoint(
            x: screen.frame.midX - panel.frame.width / 2,
            y: screen.frame.maxY - panel.frame.height - 8
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        panel.orderOut(nil)
    }
}

private struct NotchDropView: View {
    let onDrop: ([DropRepresentation]) -> Void
    @State private var isTargeted = false
    @State private var languageController =
        AppLanguageController.shared

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "square.stack.3d.up.fill")
            Text("Drop to MDrop")
                .font(.system(size: 13, weight: .semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: 24)
        )
        .overlay {
            DropReceiverView(
                onTargeted: { isTargeted = $0 },
                onDrop: onDrop
            )
        }
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.tint, lineWidth: 3)
            }
        }
        .padding(5)
        .environment(languageController)
        .environment(\.locale, languageController.locale)
    }
}
