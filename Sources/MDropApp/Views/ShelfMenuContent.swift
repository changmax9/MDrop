import AppKit
import MDropCore
import SwiftUI

struct ShelfSharingMenuSections<Service> {
    let primary: [Service]
    let overflow: [Service]
}

enum ShelfSharingMenuPolicy {
    static let primaryLimit = 4

    static func sections<Service>(
        for services: [Service],
        primaryLimit: Int = primaryLimit
    ) -> ShelfSharingMenuSections<Service> {
        let splitIndex = min(max(primaryLimit, 0), services.count)
        return ShelfSharingMenuSections(
            primary: Array(services[..<splitIndex]),
            overflow: Array(services[splitIndex...])
        )
    }
}

enum ShelfActionMenuPolicy {
    private static let promotedActions: Set<BuiltinActionID> = [
        .systemShare,
        .copyTo,
        .moveTo
    ]
    private static let textActionOrder: [BuiltinActionID] = [
        .copyText
    ]
    private static let imageActionOrder: [BuiltinActionID] = [
        .resizeImages,
        .convertImages,
        .compressImages,
        .removeImageMetadata,
        .stitchImages,
        .extractText,
        .createPDF
    ]
    private static let generalActionOrder: [BuiltinActionID] = [
        .rename,
        .createArchive,
        .copyPath,
        .moveToTrash
    ]

    struct Sections {
        let text: [BuiltinActionID]
        let image: [BuiltinActionID]
        let general: [BuiltinActionID]

        var isEmpty: Bool {
            text.isEmpty && image.isEmpty && general.isEmpty
        }
    }

    static func sections(
        from availableActions: Set<BuiltinActionID>
    ) -> Sections {
        let remaining = BuiltinActionID.allCases.filter {
            availableActions.contains($0)
                && !promotedActions.contains($0)
                && !textActionOrder.contains($0)
                && !imageActionOrder.contains($0)
                && !generalActionOrder.contains($0)
        }
        return Sections(
            text: textActionOrder.filter(availableActions.contains),
            image: imageActionOrder.filter(availableActions.contains),
            general:
                generalActionOrder.filter(availableActions.contains)
                + remaining
        )
    }

    static func submenuActions(
        from availableActions: Set<BuiltinActionID>
    ) -> [BuiltinActionID] {
        let sections = sections(from: availableActions)
        return sections.text + sections.image + sections.general
    }
}

struct ShelfMenuContent: View {
    @Bindable var store: ShelfStore
    let onDock: () -> Void
    let onQuickLook: () -> Void
    let onAddClipboard: () -> Void
    let onRevealInFinder: ([URL]) -> Void
    let onAction: (BuiltinActionID) -> Void
    let onChange: () -> Void

    var body: some View {
        let applications = openWithApplications
        let services = sharingServices
        let sharingSections = ShelfSharingMenuPolicy.sections(
            for: services
        )
        let actions = availableActions
        let actionSections = ShelfActionMenuPolicy.sections(
            from: actions
        )

        Group {
            if !applications.isEmpty {
                ShelfActionSubmenu {
                    ForEach(applications, id: \.self) { applicationURL in
                        Button {
                            open(with: applicationURL)
                        } label: {
                            Label {
                                Text(applicationName(applicationURL))
                            } icon: {
                                Image(nsImage: applicationIcon(applicationURL))
                                    .resizable().scaledToFit().frame(width: 16, height: 16)
                            }
                        }
                    }
                } label: {
                    Label {
                        Text(AppLocalization.string("Open With"))
                    } icon: {
                        Image(nsImage: applicationIcon(applications[0]))
                            .resizable().scaledToFit().frame(width: 16, height: 16)
                    }
                }
            }

            Button(AppLocalization.string("Show in Finder"), systemImage: "finder") {
                onRevealInFinder(fileURLs)
            }
            .disabled(fileURLs.isEmpty)

            Button(AppLocalization.string("Quick Look"), systemImage: "eye", action: onQuickLook)
                .disabled(fileURLs.isEmpty)

            if !services.isEmpty {
                Divider()
                ForEach(
                    Array(sharingSections.primary.enumerated()),
                    id: \.offset
                ) { _, service in
                    sharingServiceButton(service)
                }
                if !sharingSections.overflow.isEmpty {
                    ShelfActionSubmenu("More", systemImage: "ellipsis") {
                        ForEach(
                            Array(sharingSections.overflow.enumerated()),
                            id: \.offset
                        ) { _, service in
                            sharingServiceButton(service)
                        }
                    }
                }
            }

            Divider()

            Button(
                AppLocalization.string("Add From Clipboard"),
                systemImage: "square.and.arrow.down",
                action: onAddClipboard
            )
            Button(
                copyTitle,
                systemImage: "document.on.document",
                action: copyItems
            )

            if actions.contains(.copyTo) {
                Button(
                    AppLocalization.string("Copy to…"),
                    systemImage: BuiltinActionID.copyTo.symbolName
                ) {
                    onAction(.copyTo)
                }
            }
            if actions.contains(.moveTo) {
                Button(
                    AppLocalization.string("Move to…"),
                    systemImage: BuiltinActionID.moveTo.symbolName
                ) {
                    onAction(.moveTo)
                }
            }

            if !actionSections.isEmpty {
                ShelfActionSubmenu("All Actions", systemImage: "ellipsis.circle") {
                    if !actionSections.text.isEmpty {
                        ShelfActionSection("Text Actions") {
                            actionButtons(actionSections.text)
                        }
                    }
                    if !actionSections.image.isEmpty {
                        ShelfActionSection("Image Actions") {
                            actionButtons(actionSections.image)
                        }
                    }
                    if !actionSections.general.isEmpty {
                        ShelfActionSection("General Actions") {
                            actionButtons(actionSections.general)
                        }
                    }
                }
            }

            Divider()

            Button(AppLocalization.string("Clear Shelf"), systemImage: "xmark.bin") {
                store.remove(Set(store.shelf.items.map(\.id)))
                onChange()
            }
            Button(
                AppLocalization.string("Dock to Edge"),
                systemImage: "dock.rectangle",
                action: onDock
            )
            Button(AppLocalization.string("Customize"), systemImage: "paintbrush.pointed.fill") {
                store.isCustomizationPresented = true
            }

            Divider()

            Button(AppLocalization.string("Settings…"), systemImage: "gearshape") {
                AppServices.openSettings?()
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

    private var openWithApplications: [URL] {
        guard let first = fileURLs.first else { return [] }
        let defaultApplication = NSWorkspace.shared
            .urlForApplication(toOpen: first)?
            .standardizedFileURL
        return NSWorkspace.shared.urlsForApplications(toOpen: first)
            .sorted { lhs, rhs in
                let normalizedLHS = lhs.standardizedFileURL
                let normalizedRHS = rhs.standardizedFileURL
                if normalizedLHS == defaultApplication {
                    return normalizedRHS != defaultApplication
                }
                if normalizedRHS == defaultApplication {
                    return false
                }
                return applicationName(lhs)
                    .localizedCaseInsensitiveCompare(applicationName(rhs))
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

    private func applicationIcon(_ url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    private func sharingServiceButton(
        _ service: NSSharingService
    ) -> some View {
        Button {
            service.perform(withItems: sharingItems)
        } label: {
            Label {
                Text(service.title)
            } icon: {
                Image(nsImage: service.image)
                    .resizable().scaledToFit().frame(width: 16, height: 16)
            }
        }
    }

    @ViewBuilder
    private func actionButtons(
        _ actions: [BuiltinActionID]
    ) -> some View {
        ForEach(actions, id: \.rawValue) { action in
            Button(
                action.displayTitle,
                systemImage: action.symbolName
            ) {
                onAction(action)
            }
        }
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
        ShelfPasteboardWriter.write(
            selectedItems,
            to: .general
        )
    }
}

private struct ShelfUsesActionPopoverKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var shelfUsesActionPopover: Bool {
        get { self[ShelfUsesActionPopoverKey.self] }
        set { self[ShelfUsesActionPopoverKey.self] = newValue }
    }
}

/// Preserve native context menus, but keep popover submenus in the same glass surface.
private struct ShelfActionSubmenu<Content: View, Title: View>: View {
    @Environment(\.shelfUsesActionPopover) private var usesPopover
    @State private var isExpanded = false
    let content: Content
    let title: Title

    init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Title) {
        self.content = content()
        self.title = label()
    }

    init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content)
    where Title == Label<Text, Image> {
        self.content = content()
        self.title = Label { Text(AppLocalization.string(title)) } icon: { Image(systemName: systemImage) }
    }

    var body: some View {
        if usesPopover {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 2) { content }
            } label: {
                title
                    .labelStyle(ShelfActionLabelStyle())
                    .font(.system(size: 13))
                    .padding(.vertical, 7)
            }
            .disclosureGroupStyle(ShelfPopoverDisclosureStyle())
        } else {
            Menu { content } label: { title }
        }
    }
}

struct ShelfPopoverRowStyle: PrimitiveButtonStyle {
    let dismiss: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        ShelfPopoverRow(configuration: configuration, dismiss: dismiss)
    }
}

private struct ShelfPopoverRow: View {
    let configuration: PrimitiveButtonStyleConfiguration
    let dismiss: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Button {
            dismiss()
            // Let the menu close before presenting a picker or customization popover.
            Task { @MainActor in
                await Task.yield()
                configuration.trigger()
            }
        } label: {
            configuration.label
                .font(.system(size: 13))
                .labelStyle(ShelfActionLabelStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
        .background(isHovered && isEnabled ? Color.primary.opacity(0.08) : .clear,
                    in: RoundedRectangle(cornerRadius: 7))
        .onHover { isHovered = $0 }
    }
}

/// A full-row target with visible feedback; it never invokes the action-row dismiss style.
private struct ShelfPopoverDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        ShelfPopoverDisclosure(configuration: configuration)
    }
}

private struct ShelfPopoverDisclosure: View {
    let configuration: DisclosureGroupStyleConfiguration
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(AppPreferences.reduceMotionKey) private var reduceShelfMotion = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(systemReduceMotion || reduceShelfMotion
                    ? .easeOut(duration: 0.1)
                    : .spring(response: 0.3, dampingFraction: 0.88)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    configuration.label
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .background(isHovered ? Color.primary.opacity(0.08) : .clear,
                        in: RoundedRectangle(cornerRadius: 7))
            .onHover { isHovered = $0 }
            .accessibilityValue(configuration.isExpanded
                ? AppLocalization.string("Expanded") : AppLocalization.string("Collapsed"))

            if configuration.isExpanded {
                configuration.content
                    .padding(.leading, 12)
                    .transition(.opacity)
            }
        }
    }
}

/// Section's menu-specific layout does not provide header spacing inside a VStack.
private struct ShelfActionSection<Content: View>: View {
    @Environment(\.shelfUsesActionPopover) private var usesPopover
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        if usesPopover {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalization.string(title))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                content
            }
            .padding(.bottom, 6)
        } else {
            Section(AppLocalization.string(title)) { content }
        }
    }
}

struct ShelfActionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 9) {
            configuration.icon
                .frame(width: 18, height: 18)
            configuration.title
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
