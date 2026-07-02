import Darwin
import Foundation
import MDropCore
import Observation

@MainActor
@Observable
final class AutomationStore {
    static let shared = AutomationStore()

    private(set) var watchedFolders: [WatchFolderDefinition] = []
    private(set) var scripts: [ScriptDefinition] = []
    private(set) var customActions: [CustomActionPreset] = []
    var errorMessage: String?
    @ObservationIgnored var onChange: (() -> Void)?

    private init() {
        load()
    }

    func addWatchedFolder(_ url: URL, screenshots: Bool = false) {
        let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let imageExtensions: Set<String> = [
            "heic", "jpeg", "jpg", "png", "tif", "tiff"
        ]
        watchedFolders.append(
            WatchFolderDefinition(
                name:
                    screenshots
                        ? AppLocalization.string("Screenshots")
                        : url.lastPathComponent,
                url: url,
                bookmarkData: bookmark,
                rule: WatchFolderRule(
                    allowedExtensions: screenshots ? imageExtensions : []
                ),
                destination: screenshots ? .lastShelf : .newShelf,
                isScreenshotFolder: screenshots
            )
        )
        save()
    }

    func removeWatchedFolders(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            watchedFolders.remove(at: index)
        }
        save()
    }

    func addScript(_ sourceURL: URL) {
        do {
            try FileManager.default.createDirectory(
                at: AppPaths.scripts,
                withIntermediateDirectories: true
            )
            let destination = uniqueScriptURL(sourceURL.lastPathComponent)
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            if scriptKind(for: destination) == .shell {
                chmod(destination.path, 0o755)
            }
            scripts.append(
                ScriptDefinition(
                    name: destination.deletingPathExtension().lastPathComponent,
                    url: destination,
                    kind: scriptKind(for: destination)
                )
            )
            save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeScripts(at offsets: IndexSet) {
        for index in offsets {
            try? FileManager.default.removeItem(at: scripts[index].url)
        }
        for index in offsets.sorted(by: >) {
            scripts.remove(at: index)
        }
        save()
    }

    func updateScript(
        _ id: UUID,
        _ update: (inout ScriptDefinition) -> Void
    ) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else {
            return
        }
        update(&scripts[index])
        save()
    }

    func addPreset(for action: BuiltinActionID) {
        customActions.append(
            CustomActionPreset(
                name: action.displayTitle,
                action: action,
                parameters: defaultParameters(for: action)
            )
        )
        save()
    }

    func removePresets(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            customActions.remove(at: index)
        }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: AppPaths.automation),
              let archive = try? JSONDecoder().decode(AutomationArchive.self, from: data) else {
            return
        }
        watchedFolders = archive.watchedFolders
        scripts = archive.scripts
        customActions = archive.customActions
        resolveWatchedFolderBookmarks()
    }

    private func resolveWatchedFolderBookmarks() {
        var refreshedBookmark = false
        for index in watchedFolders.indices {
            guard let bookmark = watchedFolders[index].bookmarkData else {
                continue
            }
            var isStale = false
            guard let resolved = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                continue
            }
            watchedFolders[index].url = resolved
            if isStale {
                watchedFolders[index].bookmarkData = try? resolved.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                refreshedBookmark = true
            }
        }
        if refreshedBookmark {
            save()
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: AppPaths.applicationSupport,
                withIntermediateDirectories: true
            )
            let archive = AutomationArchive(
                watchedFolders: watchedFolders,
                scripts: scripts,
                customActions: customActions
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(archive).write(to: AppPaths.automation, options: .atomic)
            onChange?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scriptKind(for url: URL) -> ScriptKind {
        switch url.pathExtension.lowercased() {
        case "applescript", "scpt":
            .appleScript
        case "workflow":
            .automator
        default:
            .shell
        }
    }

    private func uniqueScriptURL(_ filename: String) -> URL {
        let preferred = AppPaths.scripts.appending(path: filename)
        guard FileManager.default.fileExists(atPath: preferred.path) else {
            return preferred
        }
        return AppPaths.scripts.appending(
            path: "\(preferred.deletingPathExtension().lastPathComponent)-\(UUID().uuidString.prefix(8)).\(preferred.pathExtension)"
        )
    }

    private func defaultParameters(
        for action: BuiltinActionID
    ) -> [String: ActionParameterValue] {
        switch action {
        case .resizeImages:
            ["width": .integer(1600), "height": .integer(1600)]
        case .compressImages:
            ["quality": .double(0.72)]
        case .convertImages:
            ["format": .string("png")]
        default:
            [:]
        }
    }
}
