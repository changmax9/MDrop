import AppIntents
import Foundation
import MDropCore

struct NewShelfIntent: AppIntent {
    static let title: LocalizedStringResource = "New MDrop Shelf"
    static let description = IntentDescription("Creates an empty floating MDrop Shelf.")
    static var supportedModes: IntentModes { .foreground(.immediate) }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppServices.coordinator?.createShelf()
        }
        return .result()
    }
}

struct ClipboardShelfIntent: AppIntent {
    static let title: LocalizedStringResource = "New Clipboard Shelf"
    static let description = IntentDescription("Creates a Shelf from the current clipboard.")
    static var supportedModes: IntentModes { .foreground(.immediate) }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppServices.coordinator?.createClipboardShelf()
        }
        return .result()
    }
}

struct AddFilesToShelfIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Files to MDrop"
    static let description = IntentDescription("Creates a Shelf containing the supplied files.")
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Files")
    var files: [IntentFile]

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$files) to MDrop")
    }

    func perform() async throws -> some IntentResult {
        let urls = files.compactMap(\.fileURL)
        await MainActor.run {
            AppServices.coordinator?.createShelf(
                with: urls.map(DropRepresentation.file)
            )
        }
        return .result()
    }
}

struct OpenLastShelfIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Last MDrop Shelf"
    static var supportedModes: IntentModes { .foreground(.immediate) }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppServices.coordinator?.openLastShelf()
        }
        return .result()
    }
}

struct CloseAllShelvesIntent: AppIntent {
    static let title: LocalizedStringResource = "Close All MDrop Shelves"
    static var supportedModes: IntentModes { .foreground(.immediate) }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppServices.coordinator?.closeAll()
        }
        return .result()
    }
}

struct GetVisibleShelfFilesIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Visible MDrop Files"
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        let urls = await MainActor.run {
            AppServices.coordinator?.visibleFileURLs() ?? []
        }
        return .result(value: urls.map { IntentFile(fileURL: $0) })
    }
}

struct MDropAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewShelfIntent(),
            phrases: ["Create a shelf in \(.applicationName)"],
            shortTitle: "New Shelf",
            systemImageName: "square.stack.3d.up"
        )
        AppShortcut(
            intent: ClipboardShelfIntent(),
            phrases: ["Open the clipboard in \(.applicationName)"],
            shortTitle: "Clipboard Shelf",
            systemImageName: "clipboard"
        )
        AppShortcut(
            intent: OpenLastShelfIntent(),
            phrases: ["Open my last \(.applicationName) shelf"],
            shortTitle: "Open Last Shelf",
            systemImageName: "clock.arrow.circlepath"
        )
    }
}
