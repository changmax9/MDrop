import AppKit
import MDropCore

@MainActor
final class ShelfActionController {
    private let executor = BuiltinActionExecutor()
    private let ingestService = DragIngestService(stagingDirectory: AppPaths.staging)

    func run(
        _ action: BuiltinActionID,
        store: ShelfStore,
        panel: NSPanel,
        onChange: @escaping () -> Void
    ) {
        let items = selectedItems(in: store)
        guard !items.isEmpty else { return }

        if action == .systemShare {
            presentSharePicker(items: items, from: panel)
            return
        }

        var parameters: [String: ActionParameterValue] = [:]
        switch action {
        case .copyTo, .moveTo:
            guard let directory = chooseDirectory(relativeTo: panel) else { return }
            parameters["destination"] = .url(directory)
        case .createArchive:
            guard let destination = chooseArchiveDestination(relativeTo: panel) else { return }
            parameters["destination"] = .url(destination)
        case .rename:
            guard let name = requestName(relativeTo: panel, initial: items[0].displayName) else { return }
            parameters["name"] = .string(name)
        case .resizeImages:
            parameters["width"] = .integer(1600)
            parameters["height"] = .integer(1600)
        case .compressImages:
            parameters["quality"] = .double(0.72)
        case .convertImages:
            parameters["format"] = .string("png")
        default:
            break
        }

        store.actionProgress = 0
        Task {
            do {
                let result = try await executor.run(
                    action,
                    request: ActionRequest(items: items, parameters: parameters),
                    progress: { value in
                        Task { @MainActor in
                            store.actionProgress = value
                        }
                    }
                )
                apply(result, action: action, originalItems: items, to: store)
                store.actionProgress = nil
                store.isCommandBarPresented = false
                onChange()
            } catch {
                store.actionProgress = nil
                store.errorMessage = error.localizedDescription
            }
        }
    }

    private func selectedItems(in store: ShelfStore) -> [ShelfItemRecord] {
        if store.selectedItemIDs.isEmpty {
            return store.shelf.items
        }
        return store.shelf.items.filter { store.selectedItemIDs.contains($0.id) }
    }

    private func apply(
        _ result: ActionResult,
        action: BuiltinActionID,
        originalItems: [ShelfItemRecord],
        to store: ShelfStore
    ) {
        if let clipboardText = result.clipboardText {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(clipboardText, forType: .string)
        }

        if action == .moveTo || action == .rename || action == .moveToTrash {
            store.remove(Set(originalItems.map(\.id)))
        }

        if !result.createdFiles.isEmpty {
            let newItems = try? ingestService.ingest(result.createdFiles.map(DropRepresentation.file))
            store.append(newItems ?? [])
        }
    }

    private func presentSharePicker(items: [ShelfItemRecord], from panel: NSPanel) {
        let sharingItems: [Any] = items.compactMap { item in
            switch item.payload {
            case let .file(reference): reference.url
            case let .text(value): value
            case let .url(url): url
            }
        }
        guard let contentView = panel.contentView, !sharingItems.isEmpty else { return }
        NSSharingServicePicker(items: sharingItems).show(
            relativeTo: contentView.bounds,
            of: contentView,
            preferredEdge: .minY
        )
    }

    private func chooseDirectory(relativeTo panel: NSPanel) -> URL? {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.prompt = String(localized: "Choose")
        return picker.runModal() == .OK ? picker.url : nil
    }

    private func chooseArchiveDestination(relativeTo panel: NSPanel) -> URL? {
        let picker = NSSavePanel()
        picker.allowedContentTypes = [.zip]
        picker.nameFieldStringValue = "MDrop Archive.zip"
        return picker.runModal() == .OK ? picker.url : nil
    }

    private func requestName(relativeTo panel: NSPanel, initial: String) -> String? {
        let alert = NSAlert()
        alert.messageText = String(localized: "Rename Item")
        alert.informativeText = String(localized: "Enter a new file name.")
        alert.addButton(withTitle: String(localized: "Rename"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        let field = NSTextField(string: initial)
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }
}

extension BuiltinActionID {
    var displayTitle: String {
        switch self {
        case .systemShare: String(localized: "Share…")
        case .resizeImages: String(localized: "Resize Images")
        case .convertImages: String(localized: "Convert to PNG")
        case .compressImages: String(localized: "Compress Images")
        case .removeImageMetadata: String(localized: "Remove Metadata")
        case .stitchImages: String(localized: "Stitch Images")
        case .extractText: String(localized: "Extract Text")
        case .createPDF: String(localized: "Create PDF")
        case .copyText: String(localized: "Copy Text")
        case .createArchive: String(localized: "Create ZIP Archive")
        case .copyTo: String(localized: "Copy to…")
        case .moveTo: String(localized: "Move to…")
        case .rename: String(localized: "Rename…")
        case .copyPath: String(localized: "Copy Path")
        case .moveToTrash: String(localized: "Move to Trash")
        }
    }

    var symbolName: String {
        switch self {
        case .systemShare: "square.and.arrow.up"
        case .resizeImages: "arrow.up.left.and.arrow.down.right"
        case .convertImages: "arrow.triangle.2.circlepath"
        case .compressImages: "arrow.down.right.and.arrow.up.left"
        case .removeImageMetadata: "eye.slash"
        case .stitchImages: "rectangle.3.group"
        case .extractText: "text.viewfinder"
        case .createPDF: "doc.richtext"
        case .copyText: "doc.on.doc"
        case .createArchive: "archivebox"
        case .copyTo: "square.on.square"
        case .moveTo: "folder"
        case .rename: "pencil"
        case .copyPath: "point.bottomleft.forward.to.point.topright.scurvepath"
        case .moveToTrash: "trash"
        }
    }
}
