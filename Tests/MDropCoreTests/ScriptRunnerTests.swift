import Darwin
import Foundation
import XCTest
@testable import MDropCore

final class ScriptRunnerTests: XCTestCase {
    func testShellScriptReceivesFilePathsAndCapturesOutput() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let script = directory.appending(path: "echo.sh")
        let input = directory.appending(path: "input.txt")
        try Data("#!/bin/zsh\nprintf 'done:%s' \"$1\"\n".utf8).write(to: script)
        try Data().write(to: input)
        chmod(script.path, 0o755)
        let definition = ScriptDefinition(
            name: "Echo",
            url: script,
            kind: .shell,
            outputMode: .clipboard,
            timeout: 2
        )

        let result = try await ScriptRunner().run(
            definition,
            fileURLs: [input],
            logsDirectory: directory.appending(path: "Logs")
        )

        XCTAssertEqual(result.standardOutput, "done:\(input.path)")
        XCTAssertEqual(result.exitCode, 0)
    }

    func testLargeScriptOutputDoesNotBlockProcess() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let script = directory.appending(path: "large-output.sh")
        try Data(
            "#!/bin/zsh\nhead -c 262144 /dev/zero | tr '\\\\0' 'x'\n".utf8
        ).write(to: script)
        chmod(script.path, 0o755)
        let definition = ScriptDefinition(
            name: "Large Output",
            url: script,
            kind: .shell,
            timeout: 10
        )

        let result = try await ScriptRunner().run(
            definition,
            fileURLs: [],
            logsDirectory: directory.appending(path: "Logs")
        )

        XCTAssertEqual(result.standardOutput.count, 262_144)
    }

    func testScriptExceedingTimeoutIsTerminated() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let script = directory.appending(path: "slow.sh")
        try Data("#!/bin/zsh\nsleep 2\n".utf8).write(to: script)
        chmod(script.path, 0o755)
        let definition = ScriptDefinition(
            name: "Slow",
            url: script,
            kind: .shell,
            timeout: 0.1
        )

        let started = ContinuousClock.now
        do {
            _ = try await ScriptRunner().run(
                definition,
                fileURLs: [],
                logsDirectory: directory.appending(path: "Logs")
            )
            XCTFail("Expected timeout")
        } catch ScriptRunError.timedOut {
            XCTAssertLessThan(
                ContinuousClock.now - started,
                .seconds(2),
                "Timeout cleanup must never wait indefinitely for SIGTERM"
            )
        }
    }

    func testCancellingTaskTerminatesScript() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let script = directory.appending(path: "cancel.sh")
        try Data("#!/bin/zsh\nsleep 5\n".utf8).write(to: script)
        chmod(script.path, 0o755)
        let definition = ScriptDefinition(
            name: "Cancel",
            url: script,
            kind: .shell,
            timeout: 10
        )
        let runner = ScriptRunner()
        let task = Task {
            try await runner.run(
                definition,
                fileURLs: [],
                logsDirectory: directory.appending(path: "Logs")
            )
        }

        try await Task.sleep(for: .milliseconds(80))
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch ScriptRunError.cancelled {
            // Expected.
        }
    }

    func testCancellingByRunIDTerminatesScript() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let script = directory.appending(path: "cancel-by-id.sh")
        try Data("#!/bin/zsh\nsleep 5\n".utf8).write(to: script)
        chmod(script.path, 0o755)
        let definition = ScriptDefinition(
            name: "Cancel by ID",
            url: script,
            kind: .shell,
            timeout: 10
        )
        let runner = ScriptRunner()
        let runID = UUID()
        let task = Task {
            try await runner.run(
                definition,
                fileURLs: [],
                logsDirectory: directory.appending(path: "Logs"),
                runID: runID
            )
        }

        try await Task.sleep(for: .milliseconds(80))
        await runner.cancel(runID)

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch ScriptRunError.cancelled {
            // Expected.
        }
    }
}
