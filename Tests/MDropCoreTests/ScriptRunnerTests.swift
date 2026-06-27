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

        do {
            _ = try await ScriptRunner().run(
                definition,
                fileURLs: [],
                logsDirectory: directory.appending(path: "Logs")
            )
            XCTFail("Expected timeout")
        } catch ScriptRunError.timedOut {
            // Expected.
        }
    }
}
