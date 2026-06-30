import AppKit
import MDropCore

@MainActor
final class ShelfCoordinator {
    private let repository = ShelfRepository(fileURL: AppPaths.archive)
    private let ingestQueue = DragIngestQueue(
        service: DragIngestService(stagingDirectory: AppPaths.staging)
    )
    private var panels: [UUID: ShelfPanelController] = [:]
    private var recent: [ShelfRecord] = []
    private var persistenceRevision = 0

    func restore() {
        Task {
            do {
                let archive = try await repository.load()
                recent = archive.recent
                for shelf in archive.visible {
                    show(
                        shelf,
                        animatesInitialAppearance: false
                    )
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
        let shelf = ShelfRecord()
        show(shelf, at: point)
        persistVisible()
        guard !representations.isEmpty else { return }

        Task {
            do {
                let items = try await ingestQueue.ingest(representations)
                guard let panel = panels[shelf.id] else { return }
                panel.store.append(items)
                panel.refreshSize()
                persistVisible()
            } catch {
                panels[shelf.id]?.store.errorMessage = error.localizedDescription
            }
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
        guard panels[shelfID] != nil else { return }
        Task {
            do {
                let items = try await ingestQueue.ingest(representations)
                guard let panel = panels[shelfID] else { return }
                panel.store.append(items)
                panel.refreshSize()
                persistVisible()
            } catch {
                panels[shelfID]?.store.errorMessage = error.localizedDescription
            }
        }
    }

    func close(_ shelfID: UUID) {
        guard let panel = panels.removeValue(forKey: shelfID) else { return }
        var shelf = panel.store.shelf
        shelf.modifiedAt = .now
        panel.close()
        persistenceRevision += 1
        let revision = persistenceRevision
        let visible = panels.values.map(\.store.shelf)
        Task {
            do {
                let archive = try await repository.closeShelf(
                    shelf,
                    visible: visible,
                    revision: revision
                )
                recent = archive.recent
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

    func shelvesForMenu() -> [ShelfRecord] {
        let visible = panels.values.map(\.store.shelf)
        let visibleIDs = Set(visible.map(\.id))
        let closed = recent.filter { !visibleIDs.contains($0.id) }
        return (visible + closed).sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned
            }
            return $0.modifiedAt > $1.modifiedAt
        }
    }

    func isShelfVisible(_ shelfID: UUID) -> Bool {
        panels[shelfID] != nil
    }

    func openShelf(_ shelfID: UUID) {
        if let panel = panels[shelfID] {
            panel.panel.orderFrontRegardless()
            return
        }
        guard let shelf = recent.first(where: { $0.id == shelfID }) else { return }
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

    func receiveWatchedFiles(
        _ urls: [URL],
        definition: WatchFolderDefinition
    ) {
        guard !urls.isEmpty else { return }
        if definition.copiesToClipboard {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects(urls as [NSURL])
        }

        let representations = urls.map(DropRepresentation.file)
        if definition.destination == .lastShelf,
           let latest = panels.values.max(by: {
               $0.store.shelf.modifiedAt < $1.store.shelf.modifiedAt
           }) {
            receive(representations, into: latest.store.shelf.id)
        } else {
            createShelf(with: representations)
        }
    }

    func shelfDidChange(_ shelfID: UUID) {
        panels[shelfID]?.refreshSize()
        persistVisible()
    }

    func visibleFileURLs() -> [URL] {
        panels.values
            .flatMap { $0.store.shelf.items }
            .compactMap(\.fileURL)
    }

    func handle(_ url: URL) {
        switch url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) {
        case "new":
            createShelf()
        case "clipboard":
            createClipboardShelf()
        case "last":
            openLastShelf()
        case "close-all":
            closeAll()
        default:
            break
        }
    }

    private func show(
        _ shelf: ShelfRecord,
        at point: CGPoint? = nil,
        animatesInitialAppearance: Bool = true
    ) {
        if let existing = panels[shelf.id] {
            existing.panel.orderFrontRegardless()
            return
        }
        let panel = ShelfPanelController(
            shelf: shelf,
            location: point,
            animatesInitialAppearance: animatesInitialAppearance,
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
        persistenceRevision += 1
        let revision = persistenceRevision
        Task {
            do {
                let archive = try await repository.saveVisible(
                    visible,
                    revision: revision
                )
                recent = archive.recent
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

private actor DragIngestQueue {
    let service: DragIngestService

    init(service: DragIngestService) {
        self.service = service
    }

    func ingest(
        _ representations: [DropRepresentation]
    ) throws -> [ShelfItemRecord] {
        try service.ingest(representations)
    }
}
