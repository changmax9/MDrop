import AppKit

@MainActor
final class MDropServicesProvider: NSObject {
    private weak var coordinator: ShelfCoordinator?

    init(coordinator: ShelfCoordinator) {
        self.coordinator = coordinator
    }

    @objc func addToShelf(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let representations = PasteboardReader.representations(from: pasteboard)
        guard !representations.isEmpty else {
            error.pointee = "No compatible files or content were found."
            return
        }
        coordinator?.createShelf(with: representations)
    }
}
