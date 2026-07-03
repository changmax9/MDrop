import AppKit

@MainActor
final class FinderRevealController {
    private let activateFileViewer: ([URL]) -> Void

    init(
        activateFileViewer: @escaping ([URL]) -> Void = {
            NSWorkspace.shared.activateFileViewerSelecting($0)
        }
    ) {
        self.activateFileViewer = activateFileViewer
    }

    func reveal(_ fileURLs: [URL], from shelfPanel: NSPanel) {
        guard !fileURLs.isEmpty else { return }
        activateFileViewer(fileURLs)
        shelfPanel.orderOut(nil)
    }
}
