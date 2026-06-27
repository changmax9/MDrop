import Foundation

public enum WatchDestination: String, Codable, CaseIterable, Sendable {
    case newShelf
    case lastShelf
}

public struct WatchFolderDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var url: URL
    public var bookmarkData: Data?
    public var rule: WatchFolderRule
    public var destination: WatchDestination
    public var isScreenshotFolder: Bool
    public var copiesToClipboard: Bool
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        bookmarkData: Data? = nil,
        rule: WatchFolderRule = .init(),
        destination: WatchDestination = .newShelf,
        isScreenshotFolder: Bool = false,
        copiesToClipboard: Bool = false,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.bookmarkData = bookmarkData
        self.rule = rule
        self.destination = destination
        self.isScreenshotFolder = isScreenshotFolder
        self.copiesToClipboard = copiesToClipboard
        self.isEnabled = isEnabled
    }
}

public struct AutomationArchive: Codable, Equatable, Sendable {
    public var watchedFolders: [WatchFolderDefinition]
    public var scripts: [ScriptDefinition]
    public var customActions: [CustomActionPreset]

    public init(
        watchedFolders: [WatchFolderDefinition] = [],
        scripts: [ScriptDefinition] = [],
        customActions: [CustomActionPreset] = []
    ) {
        self.watchedFolders = watchedFolders
        self.scripts = scripts
        self.customActions = customActions
    }
}
