import Foundation
import XCTest
@testable import MDropCore

final class DragIngestServiceTests: XCTestCase {
    func testDuplicateFileURLsAreCollapsedWithoutChangingFirstSeenOrder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let firstURL = directory.appending(path: "first.txt")
        let secondURL = directory.appending(path: "second.txt")
        try Data().write(to: firstURL)
        try Data().write(to: secondURL)
        let service = DragIngestService(stagingDirectory: directory.appending(path: "Staging"))

        let items = try service.ingest([
            .file(firstURL),
            .file(firstURL),
            .file(secondURL)
        ])

        XCTAssertEqual(items.map(\.displayName), ["first.txt", "second.txt"])
    }

    func testEmptyTextIsIgnoredAndURLKeepsItsOwnPayload() throws {
        let service = DragIngestService(
            stagingDirectory: FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        )
        let url = URL(string: "https://example.com/reference")!

        let items = try service.ingest([
            .text("   \n"),
            .text("Release notes"),
            .url(url)
        ])

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].payload, .text("Release notes"))
        XCTAssertEqual(items[1].payload, .url(url))
    }

    func testBinaryRepresentationIsWrittenIntoStagingDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let service = DragIngestService(stagingDirectory: directory)

        let items = try service.ingest([
            .binary(Data("image".utf8), suggestedFilename: "web-image.png")
        ])

        guard case let .file(reference) = try XCTUnwrap(items.first).payload else {
            return XCTFail("Expected staged file payload")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: reference.url.path))
        XCTAssertEqual(reference.url.lastPathComponent, "web-image.png")
    }
}
