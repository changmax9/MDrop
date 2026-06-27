import AppKit
import MDropCore

@MainActor
final class ShakeMonitor {
    private var detector = ShakeDetector()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let onShake: (CGPoint) -> Void

    init(onShake: @escaping (CGPoint) -> Void) {
        self.onShake = onShake
    }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) {
            [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) {
            [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        let point = NSEvent.mouseLocation
        if detector.record(x: point.x, at: event.timestamp) {
            onShake(point)
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
}
