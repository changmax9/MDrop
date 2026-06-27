import AppKit
import MDropCore

@MainActor
final class ShelfCoordinator {
    private let repository = ShelfRepository(fileURL: AppPaths.archive)
    private let ingestService = DragIngestService(stagingDirectory: AppPaths.staging)
    private var panels: [UUID: ShelfPanelController] = [:]
    private var recent: [ShelfRecord] = []

    func restore() {
        Task {
            do {
                let archive = try await repository.load()
                recent = archive.recent
                for shelf in archive.visible {
                    show(shelf)
                }
            } catch {
                presentError(error)
            }
        }
    }

    func createShelf(
        at point: CGPoint? = nil,
        with representations: [DropRepresentation] = []
    ) {
        do {
            let items = try ingestService.ingest(representations)
            let shelf = ShelfRecord(items: items)
            show(shelf, at: point)
            persistVisible()
        } catch {
            presentError(error)
        }
    }

    func createShelf(with representations: [DropRepresentation]) {
        createShelf(at: nil, with: representations)
    }

    func createClipboardShelf() {
        let representations = PasteboardReader.representations(from: .general)
        createShelf(with: representations)
    }

    func receive(_ representations: [DropRepresentation], into shelfID: UUID) {
        guard let panel = panels[shelfID] else { return }
        do {
            panel.store.append(try ingestService.ingest(representations))
            panel.refreshSize()
            persistVisible()
        } catch {
            panel.store.errorMessage = error.localizedDescription
        }
    }

    func close(_ shelfID: UUID) {
        guard let panel = panels.removeValue(forKey: shelfID) else { return }
        let shelf = panel.store.shelf
        panel.close()
        Task {
            do {
                try await repository.rememberClosed(shelf)
                let archive = try await repository.load()
                recent = archive.recent
                persistVisible()
            } catch {
                presentError(error)
            }
        }
    }

    func closeAll() {
        let ids = Array(panels.keys)
        for id in ids {
            close(id)
        }
    }

    func openLastShelf() {
        guard let shelf = recent.first else { return }
        show(shelf)
        persistVisible()
    }

    func selectShelf() {
        let ordered = panels.values.sorted {
            $0.panel.frame.minX < $1.panel.frame.minX
        }
        guard let panel = ordered.first else { return }
        panel.panel.makeKeyAndOrderFront(nil)
    }

    func shelfDidChange(_ shelfID: UUID) {
        panels[shelfID]?.refreshSize()
        persistVisible()
    }

    private func show(_ shelf: ShelfRecord, at point: CGPoint? = nil) {
        if let existing = panels[shelf.id] {
            existing.panel.orderFrontRegardless()
            return
        }
        let panel = ShelfPanelController(
            shelf: shelf,
            location: point,
            onDrop: { [weak self] representations in
                self?.receive(representations, into: shelf.id)
            },
            onChange: { [weak self] in
                self?.shelfDidChange(shelf.id)
            },
            onClose: { [weak self] in
                self?.close(shelf.id)
            }
        )
        panels[shelf.id] = panel
        panel.show()
    }

    private func persistVisible() {
        let visible = panels.values.map(\.store.shelf)
        let recent = recent
        Task {
            do {
                try await repository.save(ShelfArchive(visible: visible, recent: recent))
            } catch {
                presentError(error)
            }
        }
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}
