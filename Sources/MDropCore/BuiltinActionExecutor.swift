import Foundation

public enum ActionExecutionError: LocalizedError, Sendable {
    case missingParameter(String)
    case unsupportedAction(BuiltinActionID)
    case noCompatibleItems
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .missingParameter(name):
            "Missing action parameter: \(name)"
        case let .unsupportedAction(action):
            "The \(action.rawValue) action must be presented by the app."
        case .noCompatibleItems:
            "The selected items are not compatible with this action."
        case let .commandFailed(message):
            message
        }
    }
}

public struct BuiltinActionExecutor: Sendable {
    public init() {}

    public func run(
        _ action: BuiltinActionID,
        request: ActionRequest,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> ActionResult {
        switch action {
        case .copyText:
            return try copyText(from: request.items)
        case .copyPath:
            return copyPaths(from: request.items)
        case .copyTo:
            return try transfer(request, movesItems: false, progress: progress)
        case .moveTo:
            return try transfer(request, movesItems: true, progress: progress)
        case .rename:
            return try rename(request)
        case .moveToTrash:
            return try trash(request.items, progress: progress)
        case .createArchive:
            return try createArchive(request, progress: progress)
        case .resizeImages,
             .convertImages,
             .compressImages,
             .removeImageMetadata,
             .stitchImages,
             .extractText,
             .createPDF:
            return try ImageActionProcessor().run(
                action,
                request: request,
                progress: progress
            )
        case .systemShare:
            throw ActionExecutionError.unsupportedAction(action)
        }
    }

    private func copyText(from items: [ShelfItemRecord]) throws -> ActionResult {
        let parts = try items.compactMap { item -> String? in
            switch item.payload {
            case let .text(value):
                value
            case let .url(url):
                url.absoluteString
            case let .file(reference) where item.containsText:
                try String(contentsOf: reference.url, encoding: .utf8)
            case .file:
                nil
            }
        }
        guard !parts.isEmpty else {
            throw ActionExecutionError.noCompatibleItems
        }
        return ActionResult(clipboardText: parts.joined(separator: "\n"))
    }

    private func copyPaths(from items: [ShelfItemRecord]) -> ActionResult {
        let paths = items.compactMap(\.fileURL).map(\.path)
        return ActionResult(clipboardText: paths.joined(separator: "\n"))
    }

    private func transfer(
        _ request: ActionRequest,
        movesItems: Bool,
        progress: @escaping @Sendable (Double) -> Void
    ) throws -> ActionResult {
        guard case let .url(destinationDirectory)? = request.parameters["destination"] else {
            throw ActionExecutionError.missingParameter("destination")
        }

        let sourceURLs = request.items.compactMap(\.fileURL)
        guard !sourceURLs.isEmpty else {
            throw ActionExecutionError.noCompatibleItems
        }

        var created: [URL] = []
        for (index, source) in sourceURLs.enumerated() {
            let destination = uniqueDestination(
                for: source.lastPathComponent,
                in: destinationDirectory
            )
            if movesItems {
                try FileManager.default.moveItem(at: source, to: destination)
            } else {
                try FileManager.default.copyItem(at: source, to: destination)
            }
            created.append(destination)
            progress(Double(index + 1) / Double(sourceURLs.count))
        }
        return ActionResult(createdFiles: created, shouldCloseShelf: movesItems)
    }

    private func rename(_ request: ActionRequest) throws -> ActionResult {
        guard let source = request.items.compactMap(\.fileURL).first else {
            throw ActionExecutionError.noCompatibleItems
        }
        guard case let .string(name)? = request.parameters["name"],
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ActionExecutionError.missingParameter("name")
        }
        let destination = uniqueDestination(
            for: name,
            in: source.deletingLastPathComponent()
        )
        try FileManager.default.moveItem(at: source, to: destination)
        return ActionResult(createdFiles: [destination])
    }

    private func trash(
        _ items: [ShelfItemRecord],
        progress: @escaping @Sendable (Double) -> Void
    ) throws -> ActionResult {
        let urls = items.compactMap(\.fileURL)
        guard !urls.isEmpty else {
            throw ActionExecutionError.noCompatibleItems
        }
        for (index, url) in urls.enumerated() {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            progress(Double(index + 1) / Double(urls.count))
        }
        return ActionResult(shouldCloseShelf: true)
    }

    private func createArchive(
        _ request: ActionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) throws -> ActionResult {
        guard case let .url(destination)? = request.parameters["destination"] else {
            throw ActionExecutionError.missingParameter("destination")
        }
        guard !request.items.isEmpty else {
            throw ActionExecutionError.noCompatibleItems
        }

        let staging = FileManager.default.temporaryDirectory
            .appending(path: "MDrop-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        for (index, item) in request.items.enumerated() {
            switch item.payload {
            case let .file(reference):
                let target = uniqueDestination(
                    for: reference.url.lastPathComponent,
                    in: staging
                )
                try FileManager.default.copyItem(at: reference.url, to: target)
            case let .text(value):
                let target = staging.appending(path: "Text \(index + 1).txt")
                try Data(value.utf8).write(to: target)
            case let .url(url):
                let target = staging.appending(path: "Link \(index + 1).txt")
                try Data(url.absoluteString.utf8).write(to: target)
            }
            progress(Double(index + 1) / Double(request.items.count + 1))
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = [
            "-c", "-k", "--sequesterRsrc", "--keepParent",
            staging.path,
            destination.path
        ]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            throw ActionExecutionError.commandFailed(
                String(decoding: data, as: UTF8.self)
            )
        }
        progress(1)
        return ActionResult(createdFiles: [destination])
    }

    private func uniqueDestination(for filename: String, in directory: URL) -> URL {
        let preferred = directory.appending(path: filename)
        guard FileManager.default.fileExists(atPath: preferred.path) else {
            return preferred
        }

        let pathExtension = preferred.pathExtension
        let stem = preferred.deletingPathExtension().lastPathComponent
        var index = 2
        while true {
            let candidateName = pathExtension.isEmpty
                ? "\(stem) \(index)"
                : "\(stem) \(index).\(pathExtension)"
            let candidate = directory.appending(path: candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}
