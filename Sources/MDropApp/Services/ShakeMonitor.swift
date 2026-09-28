import AppKit
import MDropCore

@MainActor
final class ShakeMonitor {
    private var detector = ShakeDetector()
    private var detectorSensitivity = 0.5
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hasTriggeredDuringDrag = false
    private let onShake: (CGPoint) -> Void
    private let onDrag: ((CGPoint) -> Void)?
    private let onDragEnded: (() -> Void)?

    init(
        onDrag: ((CGPoint) -> Void)? = nil,
        onDragEnded: (() -> Void)? = nil,
        onShake: @escaping (CGPoint) -> Void
    ) {
        self.onDrag = onDrag
        self.onDragEnded = onDragEnded
        self.onShake = onShake
        detectorSensitivity = AppPreferences.shakeSensitivity()
        detector = Self.makeDetector()
    }

    func start() {
        let events: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) {
            [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) {
            [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        if event.type == .leftMouseUp {
            detector.reset()
            hasTriggeredDuringDrag = false
            onDragEnded?()
            return
        }

        guard hasSupportedDragPayload else {
            detector.reset()
            return
        }
        let point = NSEvent.mouseLocation
        onDrag?(point)
        guard AppPreferences.shakeEnabled(),
              !hasTriggeredDuringDrag
        else { return }
        refreshDetectorConfigurationIfNeeded()
        if detector.record(x: point.x, at: event.timestamp) {
            hasTriggeredDuringDrag = true
            onShake(point)
        }
    }

    private func refreshDetectorConfigurationIfNeeded() {
        let sensitivity = AppPreferences.shakeSensitivity()
        guard sensitivity != detectorSensitivity else { return }
        detectorSensitivity = sensitivity
        detector = Self.makeDetector()
    }

    private static func makeDetector() -> ShakeDetector {
        ShakeDetector(
            configuration: .init(
                minimumSegmentDistance:
                    AppPreferences.shakeMinimumSegmentDistance()
            )
        )
    }

    private var hasSupportedDragPayload: Bool {
        let types = NSPasteboard(name: .drag).types ?? []
        let supported = Set(
            [
                NSPasteboard.PasteboardType.fileURL,
                .URL,
                .string,
                .png,
                .tiff
            ] +
            NSFilePromiseReceiver.readableDraggedTypes.map {
                NSPasteboard.PasteboardType(rawValue: $0)
            }
        )
        return types.contains(where: supported.contains)
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
