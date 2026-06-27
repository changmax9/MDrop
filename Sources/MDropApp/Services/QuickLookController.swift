import AppKit
@preconcurrency import Quartz

@MainActor
final class QuickLookController: NSObject, @preconcurrency QLPreviewPanelDataSource {
    private var URLs: [URL] = []

    func show(_ urls: [URL]) {
        guard !urls.isEmpty, let previewPanel = QLPreviewPanel.shared() else { return }
        URLs = urls
        previewPanel.dataSource = self
        previewPanel.reloadData()
        previewPanel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        URLs.count
    }

    func previewPanel(
        _ panel: QLPreviewPanel!,
        previewItemAt index: Int
    ) -> (any QLPreviewItem)! {
        URLs[index] as NSURL
    }
}
