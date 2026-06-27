import Foundation

enum AppPaths {
    static let applicationSupport: URL = {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return base.appending(path: "MDrop", directoryHint: .isDirectory)
    }()

    static let archive = applicationSupport.appending(path: "shelves.json")
    static let staging = applicationSupport.appending(path: "Staging", directoryHint: .isDirectory)
    static let scriptLogs = applicationSupport.appending(path: "Script Logs", directoryHint: .isDirectory)
    static let scripts = applicationSupport.appending(path: "Scripts", directoryHint: .isDirectory)
    static let automation = applicationSupport.appending(path: "automation.json")
}
