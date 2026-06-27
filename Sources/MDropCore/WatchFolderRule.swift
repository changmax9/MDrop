import Foundation

public struct WatchFolderRule: Codable, Hashable, Sendable {
    public var allowedExtensions: Set<String>
    public var nameContains: String?
    public var includesHiddenFiles: Bool

    public init(
        allowedExtensions: Set<String> = [],
        nameContains: String? = nil,
        includesHiddenFiles: Bool = false
    ) {
        self.allowedExtensions = Set(
            allowedExtensions.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
        )
        self.nameContains = nameContains?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.includesHiddenFiles = includesHiddenFiles
    }

    public func matches(_ url: URL) -> Bool {
        let filename = url.lastPathComponent
        if !includesHiddenFiles && filename.hasPrefix(".") {
            return false
        }

        if !allowedExtensions.isEmpty,
           !allowedExtensions.contains(url.pathExtension.lowercased()) {
            return false
        }

        if let nameContains, !nameContains.isEmpty,
           filename.range(of: nameContains, options: [.caseInsensitive, .diacriticInsensitive]) == nil {
            return false
        }

        return true
    }
}
