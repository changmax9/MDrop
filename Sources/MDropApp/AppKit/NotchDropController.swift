import AppKit
import MDropCore
import SwiftUI

@MainActor
final class NotchDropController {
    private let panel: NSPanel
    private var isImporting = false
    private var hideTask: Task<Void, Never>?

    init(onDrop: @escaping ([DropRepresentation]) -> Void) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 58),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = NSHostingController(
            rootView: NotchDropView(
                onDrop: { [weak self] representations in
                    onDrop(representations)
                    self?.isImporting = false
                    self?.hide()
                },
                onImportingChanged: { [weak self] importing in
                    self?.isImporting = importing
                    if !importing { self?.hide() }
                }
            )
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
        scheduleIdleHide()
    }

    private func scheduleIdleHide() {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, let self else { return }
            if NSEvent.pressedMouseButtons & 1 != 0,
               panel.frame.insetBy(dx: -24, dy: -24).contains(NSEvent.mouseLocation) {
                // Pausing over the target must never make it disappear under the file.
                scheduleIdleHide()
            } else {
                hide()
            }
        }
    }

    func hide() {
        guard !isImporting else { return }
        hideTask?.cancel()
        hideTask = nil
        panel.orderOut(nil)
    }
}

private struct NotchDropView: View {
    let onDrop: ([DropRepresentation]) -> Void
    var onImportingChanged: (Bool) -> Void
    @State private var isTargeted = false
    @State private var isImporting = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(AppPreferences.reduceMotionKey) private var reduceShelfMotion = false
    @State private var languageController =
        AppLanguageController.shared

    var body: some View {
        HStack(spacing: 9) {
            if isImporting {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "square.stack.3d.up.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            Text(isImporting ? AppLocalization.string("Adding items…") : AppLocalization.string(isTargeted ? "Release to add" : "Drop to MDrop"))
                .font(.system(size: 13, weight: .medium))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(ShelfGlassSurface(shape: RoundedRectangle(cornerRadius: 24)))
        .scaleEffect(isTargeted && !systemReduceMotion && !reduceShelfMotion ? 1.015 : 1)
        .animation(systemReduceMotion || reduceShelfMotion ? nil : .spring(response: 0.28, dampingFraction: 0.84), value: isTargeted)
        .overlay {
            DropReceiverView(
                onTargeted: { isTargeted = $0 },
                onDrop: onDrop,
                onImportingChanged: { importing in
                    isImporting = importing
                    onImportingChanged(importing)
                }
            )
        }
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.tint, lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
        }
        .padding(5)
        .environment(languageController)
        .environment(\.locale, languageController.locale)
    }
}
