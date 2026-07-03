import AppKit
import MDropCore
import SwiftUI

struct ShelfMenuContent: View {
    @Bindable var store: ShelfStore
    let onDock: () -> Void
    let onQuickLook: () -> Void
    let onAddClipboard: () -> Void
    let onRevealInFinder: ([URL]) -> Void
    let onAction: (BuiltinActionID) -> Void
    let onChange: () -> Void

    var body: some View {
        Group {
            if !openWithApplications.isEmpty {
                Menu("Open With", systemImage: "square.stack.3d.up") {
                    ForEach(openWithApplications, id: \.self) { applicationURL in
                        Button(applicationName(applicationURL)) {
                            open(with: applicationURL)
                        }
                    }
                }
            }

            Button("Show in Finder", systemImage: "finder") {
                onRevealInFinder(fileURLs)
            }
            .disabled(fileURLs.isEmpty)

            Button("Quick Look", systemImage: "eye", action: onQuickLook)
                .disabled(fileURLs.isEmpty)

            if !sharingServices.isEmpty {
                Divider()
                ForEach(Array(sharingServices.enumerated()), id: \.offset) { _, service in
                    Button {
                        service.perform(withItems: sharingItems)
                    } label: {
                        Label {
                            Text(service.title)
                        } icon: {
                            Image(nsImage: service.image)
                        }
                    }
                }
            }

            Divider()

            Button("Add From Clipboard", systemImage: "clipboard", action: onAddClipboard)
            Button(copyTitle, systemImage: "doc.on.doc", action: copyItems)

            if availableActions.contains(.copyTo) {
                Button("Copy to…", systemImage: "arrow.right.doc.on.clipboard") {
                    onAction(.copyTo)
                }
            }
            if availableActions.contains(.moveTo) {
                Button("Move to…", systemImage: "arrow.right.circle") {
                    onAction(.moveTo)
                }
            }

            Menu("All Actions", systemImage: "ellipsis.circle") {
                ForEach(orderedActions, id: \.rawValue) { action in
                    Button(action.displayTitle, systemImage: action.symbolName) {
                        onAction(action)
                    }
                }
            }

            Divider()

            Button("Clear Shelf", systemImage: "xmark.bin") {
                store.remove(Set(store.shelf.items.map(\.id)))
                onChange()
            }
            Button("Dock to Edge", systemImage: "rectangle.lefthalf.inset.filled", action: onDock)
            Button(
                AppLocalization.string(
                    store.shelf.isPinned
                        ? "Unpin Shelf"
                        : "Pin Shelf"
                ),
                systemImage: store.shelf.isPinned ? "pin.slash" : "pin"
            ) {
                store.shelf.isPinned.toggle()
                onChange()
            }

            Divider()

            Button("Settings…", systemImage: "gearshape") {
                NSApp.sendAction(
                    Selector(("showSettingsWindow:")),
                    to: nil,
                    from: nil
                )
            }
        }
    }

    private var selectedItems: [ShelfItemRecord] {
        guard !store.selectedItemIDs.isEmpty else {
            return store.shelf.items
        }
        return store.shelf.items.filter {
            store.selectedItemIDs.contains($0.id)
        }
    }

    private var fileURLs: [URL] {
        selectedItems.compactMap(\.fileURL)
    }

    private var sharingItems: [Any] {
        selectedItems.map {
            switch $0.payload {
            case let .file(reference):
                reference.resolvedURL() as NSURL
            case let .text(value):
                value as NSString
            case let .url(url):
                url as NSURL
            }
        }
    }

    private var sharingServices: [NSSharingService] {
        let selector = NSSelectorFromString("sharingServicesForItems:")
        return (NSSharingService.self as AnyObject)
            .perform(selector, with: sharingItems)?
            .takeUnretainedValue() as? [NSSharingService] ?? []
    }

    private var availableActions: Set<BuiltinActionID> {
        BuiltinActionCatalog.availableActions(for: selectedItems)
    }

    private var orderedActions: [BuiltinActionID] {
        BuiltinActionID.allCases.filter {
            availableActions.contains($0)
        }
    }

    private var openWithApplications: [URL] {
        guard let first = fileURLs.first else { return [] }
        return NSWorkspace.shared.urlsForApplications(toOpen: first)
            .sorted {
                applicationName($0)
                    .localizedCaseInsensitiveCompare(applicationName($1))
                    == .orderedAscending
            }
    }

    private var copyTitle: String {
        guard selectedItems.count == 1, let item = selectedItems.first else {
            return AppLocalization.format(
                "Copy %lld Items",
                Int64(selectedItems.count)
            )
        }
        return AppLocalization.format(
            "Copy “%@”",
            item.displayName
        )
    }

    private func applicationName(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    private func open(with applicationURL: URL) {
        guard !fileURLs.isEmpty else { return }
        NSWorkspace.shared.open(
            fileURLs,
            withApplicationAt: applicationURL,
            configuration: .init()
        ) { _, _ in }
    }

    private func copyItems() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if fileURLs.count == selectedItems.count {
            pasteboard.writeObjects(fileURLs as [NSURL])
            return
        }

        let values = selectedItems.map {
            switch $0.payload {
            case let .file(reference):
                reference.resolvedURL().path
            case let .text(value):
                value
            case let .url(url):
                url.absoluteString
            }
        }
        pasteboard.setString(values.joined(separator: "\n"), forType: .string)
    }
}
