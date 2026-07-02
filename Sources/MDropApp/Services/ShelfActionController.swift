import AppKit
import MDropCore

@MainActor
final class ShelfActionController {
    private let executor = BuiltinActionExecutor()
    private let ingestService = DragIngestService(stagingDirectory: AppPaths.staging)
    private let scriptRunner = ScriptRunner()

    func run(
        _ action: BuiltinActionID,
        store: ShelfStore,
        panel: NSPanel,
        onChange: @escaping () -> Void,
        onClose: @escaping () -> Void,
        presetParameters: [String: ActionParameterValue]? = nil
    ) {
        let items = selectedItems(in: store)
        guard !items.isEmpty else { return }

        if action == .systemShare {
            presentSharePicker(items: items, from: panel)
            return
        }

        var parameters = presetParameters ?? [:]
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
            parameters["width"] = parameters["width"] ?? .integer(1600)
            parameters["height"] = parameters["height"] ?? .integer(1600)
        case .compressImages:
            parameters["quality"] = parameters["quality"] ?? .double(0.72)
        case .convertImages:
            parameters["format"] = parameters["format"] ?? .string("png")
        default:
            break
        }

        store.actionProgress = 0
        store.cancelAction = nil
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
                store.cancelAction = nil
                store.isCommandBarPresented = false
                onChange()
                if result.shouldCloseShelf, !store.shelf.isPinned {
                    onClose()
                }
            } catch {
                store.actionProgress = nil
                store.cancelAction = nil
                store.errorMessage = error.localizedDescription
            }
        }
    }

    func run(
        _ preset: CustomActionPreset,
        store: ShelfStore,
        panel: NSPanel,
        onChange: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        run(
            preset.action,
            store: store,
            panel: panel,
            onChange: onChange,
            onClose: onClose,
            presetParameters: preset.parameters
        )
    }

    func run(
        _ script: ScriptDefinition,
        store: ShelfStore,
        onChange: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        let fileURLs = selectedItems(in: store).compactMap(\.fileURL)
        let runID = UUID()
        store.actionProgress = 0
        store.cancelAction = { [weak self, weak store] in
            Task {
                await self?.scriptRunner.cancel(runID)
                await MainActor.run {
                    store?.cancelAction = nil
                }
            }
        }
        Task {
            do {
                let result = try await scriptRunner.run(
                    script,
                    fileURLs: fileURLs,
                    logsDirectory: AppPaths.scriptLogs,
                    runID: runID
                )
                if script.outputMode == .clipboard {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.standardOutput, forType: .string)
                }
                store.actionProgress = nil
                store.cancelAction = nil
                store.isCommandBarPresented = false
                onChange()
                if script.closesShelfOnSuccess {
                    onClose()
                }
            } catch {
                store.actionProgress = nil
                store.cancelAction = nil
                if (error as? ScriptRunError) != .cancelled {
                    store.errorMessage = error.localizedDescription
                }
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
            case .file: item.fileURL
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
        picker.prompt = AppLocalization.string("Choose")
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
        alert.messageText = AppLocalization.string("Rename Item")
        alert.informativeText = AppLocalization.string(
            "Enter a new file name."
        )
        alert.addButton(
            withTitle: AppLocalization.string("Rename")
        )
        alert.addButton(
            withTitle: AppLocalization.string("Cancel")
        )
        let field = NSTextField(string: initial)
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }
}

extension BuiltinActionID {
    var displayTitle: String {
        switch self {
        case .systemShare: AppLocalization.string("Share…")
        case .resizeImages: AppLocalization.string("Resize Images")
        case .convertImages: AppLocalization.string("Convert to PNG")
        case .compressImages: AppLocalization.string("Compress Images")
        case .removeImageMetadata:
            AppLocalization.string("Remove Metadata")
        case .stitchImages: AppLocalization.string("Stitch Images")
        case .extractText: AppLocalization.string("Extract Text")
        case .createPDF: AppLocalization.string("Create PDF")
        case .copyText: AppLocalization.string("Copy Text")
        case .createArchive:
            AppLocalization.string("Create ZIP Archive")
        case .copyTo: AppLocalization.string("Copy to…")
        case .moveTo: AppLocalization.string("Move to…")
        case .rename: AppLocalization.string("Rename…")
        case .copyPath: AppLocalization.string("Copy Path")
        case .moveToTrash: AppLocalization.string("Move to Trash")
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
