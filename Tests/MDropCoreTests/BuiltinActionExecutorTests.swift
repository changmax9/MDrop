import Foundation
import XCTest
@testable import MDropCore

final class BuiltinActionExecutorTests: XCTestCase {
    func testCopyTextCombinesTextPayloadsAndTextFiles() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: "notes.txt")
        try Data("from file".utf8).write(to: fileURL)
        let request = ActionRequest(items: [
            .text("from shelf"),
            ShelfItemRecord(
                payload: .file(FileReference(url: fileURL)),
                displayName: "notes.txt"
            )
        ])

        let result = try await BuiltinActionExecutor().run(.copyText, request: request)

        XCTAssertEqual(result.clipboardText, "from shelf\nfrom file")
    }

    func testCopyPathReturnsOnlyFilePaths() async throws {
        let fileURL = URL(filePath: "/tmp/design.png")
        let request = ActionRequest(items: [
            ShelfItemRecord(
                payload: .file(FileReference(url: fileURL)),
                displayName: "design.png"
            ),
            .text("ignored")
        ])

        let result = try await BuiltinActionExecutor().run(.copyPath, request: request)

        XCTAssertEqual(result.clipboardText, "/tmp/design.png")
    }

    func testCopyToCreatesUniqueFileWhenDestinationAlreadyExists() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let sourceDirectory = directory.appending(path: "Source", directoryHint: .isDirectory)
        let destination = directory.appending(path: "Destination", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let source = sourceDirectory.appending(path: "asset.txt")
        try Data("new".utf8).write(to: source)
        try Data("old".utf8).write(to: destination.appending(path: "asset.txt"))
        let request = ActionRequest(
            items: [
                ShelfItemRecord(
                    payload: .file(FileReference(url: source)),
                    displayName: "asset.txt"
                )
            ],
            parameters: ["destination": .url(destination)]
        )

        let result = try await BuiltinActionExecutor().run(.copyTo, request: request)

        XCTAssertEqual(result.createdFiles.count, 1)
        XCTAssertNotEqual(result.createdFiles.first?.lastPathComponent, "asset.txt")
        XCTAssertEqual(
            try String(contentsOf: result.createdFiles[0], encoding: .utf8),
            "new"
        )
    }

    func testCreateArchiveProducesZipAtRequestedDestination() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appending(path: "brief.txt")
        let archive = directory.appending(path: "brief.zip")
        try Data("brief".utf8).write(to: source)
        let request = ActionRequest(
            items: [
                ShelfItemRecord(
                    payload: .file(FileReference(url: source)),
                    displayName: "brief.txt"
                )
            ],
            parameters: ["destination": .url(archive)]
        )

        let result = try await BuiltinActionExecutor().run(.createArchive, request: request)

        XCTAssertEqual(result.createdFiles, [archive])
        XCTAssertTrue(FileManager.default.fileExists(atPath: archive.path))
        XCTAssertGreaterThan(
            try FileManager.default.attributesOfItem(atPath: archive.path)[.size] as? Int ?? 0,
            0
        )
    }
}
