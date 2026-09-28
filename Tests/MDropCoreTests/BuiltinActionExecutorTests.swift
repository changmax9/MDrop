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

    func testRenameCannotEscapeSourceDirectory() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appending(path: "source.txt")
        try Data("safe".utf8).write(to: source)
        let request = ActionRequest(
            items: [
                ShelfItemRecord(
                    payload: .file(FileReference(url: source)),
                    displayName: source.lastPathComponent
                )
            ],
            parameters: ["name": .string("../escaped.txt")]
        )

        let result = try await BuiltinActionExecutor().run(
            .rename,
            request: request
        )

        XCTAssertEqual(
            result.createdFiles.first?.deletingLastPathComponent(),
            directory
        )
        XCTAssertEqual(result.createdFiles.first?.lastPathComponent, "escaped.txt")
    }
}

import Foundation
import Testing
@testable import MDropCore

@Suite("File action regressions")
struct FileActionRegressionTests {
    @Test("Renaming to the existing name preserves the path and contents")
    func unchangedName() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appending(path: "Notes.txt")
        try Data("original".utf8).write(to: source)
        let items = try DragIngestService(stagingDirectory: directory).ingest([.file(source)])
        let result = try await BuiltinActionExecutor().run(.rename, request: ActionRequest(
            items: items, parameters: ["name": .string("Notes.txt")]
        ))
        #expect(result.createdFiles.map { $0.resolvingSymlinksInPath() } == [source.resolvingSymlinksInPath()])
        #expect(try String(contentsOf: source, encoding: .utf8) == "original")
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["Notes.txt"])
    }

    @Test("ZIP preserves file contents when generated text and link names collide")
    func archiveNameCollisions() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let text = directory.appending(path: "Text 3.txt")
        let link = directory.appending(path: "Link 4.txt")
        try Data("original text file".utf8).write(to: text)
        try Data("original link file".utf8).write(to: link)
        let items = try DragIngestService(stagingDirectory: directory).ingest([
            .file(text), .file(link), .text("pasted text"), .url(URL(string: "https://example.com")!)
        ])
        let zip = directory.appending(path: "Archive.zip")
        _ = try await BuiltinActionExecutor().run(.createArchive, request: ActionRequest(
            items: items, parameters: ["destination": .url(zip)]
        ))
        let unpacked = directory.appending(path: "Unpacked")
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zip.path, unpacked.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        let root = try #require(FileManager.default.contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil).first)
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        let contents = try Set(files.map { try String(contentsOf: $0, encoding: .utf8) })
        #expect(contents == ["original text file", "original link file", "pasted text", "https://example.com"])
        #expect(files.count == 4)
    }
}
