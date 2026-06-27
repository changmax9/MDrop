import Darwin
import Foundation

public enum ScriptKind: String, Codable, CaseIterable, Sendable {
    case shell
    case appleScript
    case automator
}

public enum ScriptOutputMode: String, Codable, CaseIterable, Sendable {
    case ignore
    case clipboard
}

public struct ScriptDefinition: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var url: URL
    public var kind: ScriptKind
    public var outputMode: ScriptOutputMode
    public var closesShelfOnSuccess: Bool
    public var showsInMainMenu: Bool
    public var timeout: TimeInterval

    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        kind: ScriptKind,
        outputMode: ScriptOutputMode = .ignore,
        closesShelfOnSuccess: Bool = false,
        showsInMainMenu: Bool = false,
        timeout: TimeInterval = 30
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.kind = kind
        self.outputMode = outputMode
        self.closesShelfOnSuccess = closesShelfOnSuccess
        self.showsInMainMenu = showsInMainMenu
        self.timeout = timeout
    }
}

public struct ScriptRunResult: Sendable {
    public var standardOutput: String
    public var standardError: String
    public var exitCode: Int32

    public init(standardOutput: String, standardError: String, exitCode: Int32) {
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.exitCode = exitCode
    }
}

public enum ScriptRunError: LocalizedError, Equatable, Sendable {
    case timedOut
    case cancelled
    case failed(exitCode: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .timedOut:
            "The script exceeded its time limit."
        case .cancelled:
            "The script was cancelled."
        case let .failed(exitCode, message):
            "The script exited with code \(exitCode): \(message)"
        }
    }
}

public actor ScriptRunner {
    private var processes: [UUID: Process] = [:]
    private var cancelledRuns: Set<UUID> = []

    public init() {}

    public func run(
        _ definition: ScriptDefinition,
        fileURLs: [URL],
        logsDirectory: URL,
        runID: UUID = UUID()
    ) async throws -> ScriptRunResult {
        let process = configuredProcess(definition, fileURLs: fileURLs)
        let captureDirectory = FileManager.default.temporaryDirectory
            .appending(
                path: "MDrop-Script-\(runID.uuidString)",
                directoryHint: .isDirectory
            )
        try FileManager.default.createDirectory(
            at: captureDirectory,
            withIntermediateDirectories: true
        )
        let outputURL = captureDirectory.appending(path: "stdout")
        let errorURL = captureDirectory.appending(path: "stderr")
        _ = FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        _ = FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        processes[runID] = process
        defer {
            try? outputHandle.close()
            try? errorHandle.close()
            try? FileManager.default.removeItem(at: captureDirectory)
            processes.removeValue(forKey: runID)
            cancelledRuns.remove(runID)
        }

        try process.run()
        let started = Date()
        do {
            while process.isRunning {
                try Task.checkCancellation()
                if cancelledRuns.contains(runID) {
                    await stop(process)
                    throw ScriptRunError.cancelled
                }
                if Date().timeIntervalSince(started) >= definition.timeout {
                    await stop(process)
                    throw ScriptRunError.timedOut
                }
                try await Task.sleep(for: .milliseconds(20))
            }
        } catch is CancellationError {
            await stop(process)
            throw ScriptRunError.cancelled
        }

        try outputHandle.close()
        try errorHandle.close()
        let outputData = try Data(contentsOf: outputURL)
        let errorData = try Data(contentsOf: errorURL)
        let output = String(decoding: outputData, as: UTF8.self)
        let error = String(decoding: errorData, as: UTF8.self)
        if cancelledRuns.contains(runID) {
            throw ScriptRunError.cancelled
        }
        try writeLogs(
            definition: definition,
            output: outputData,
            error: errorData,
            directory: logsDirectory
        )

        guard process.terminationStatus == 0 else {
            throw ScriptRunError.failed(
                exitCode: process.terminationStatus,
                message: error.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return ScriptRunResult(
            standardOutput: output,
            standardError: error,
            exitCode: process.terminationStatus
        )
    }

    public func cancel(_ runID: UUID) {
        cancelledRuns.insert(runID)
        processes[runID]?.terminate()
    }

    private func stop(_ process: Process) async {
        guard process.isRunning else { return }

        process.terminate()
        if await waitForExit(process, timeout: .milliseconds(250)) {
            return
        }

        Darwin.kill(process.processIdentifier, SIGKILL)
        _ = await waitForExit(process, timeout: .seconds(1))
    }

    private func waitForExit(
        _ process: Process,
        timeout: Duration
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while process.isRunning, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return !process.isRunning
    }

    private func configuredProcess(
        _ definition: ScriptDefinition,
        fileURLs: [URL]
    ) -> Process {
        let process = Process()
        let filePaths = fileURLs.map(\.path)
        switch definition.kind {
        case .shell:
            process.executableURL = definition.url
            process.arguments = filePaths
        case .appleScript:
            process.executableURL = URL(filePath: "/usr/bin/osascript")
            process.arguments = [definition.url.path] + filePaths
        case .automator:
            process.executableURL = URL(filePath: "/usr/bin/automator")
            process.arguments = ["-i"] + filePaths + [definition.url.path]
        }
        return process
    }

    private func writeLogs(
        definition: ScriptDefinition,
        output: Data,
        error: Data,
        directory: URL
    ) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = definition.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        try output.write(to: directory.appending(path: "\(base)-output.log"), options: .atomic)
        try error.write(to: directory.appending(path: "\(base)-error.log"), options: .atomic)
    }
}

public struct CustomActionPreset: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var action: BuiltinActionID
    public var parameters: [String: ActionParameterValue]
    public var showsInMainMenu: Bool
    public var isInstantAction: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        action: BuiltinActionID,
        parameters: [String: ActionParameterValue],
        showsInMainMenu: Bool = false,
        isInstantAction: Bool = false
    ) {
        self.id = id
        self.name = name
        self.action = action
        self.parameters = parameters
        self.showsInMainMenu = showsInMainMenu
        self.isInstantAction = isInstantAction
    }
}
