import AppKit
import Foundation
import Testing
@testable import MDropApp

@Suite("Brand assets")
struct BrandAssetTests {
    @Test("Info plist declares the Folded M app icon")
    func appIconDeclaration() throws {
        let root = repositoryRoot
        let data = try Data(
            contentsOf:
                root.appending(path: "Config/Info.plist")
        )
        let plist = try #require(
            PropertyListSerialization.propertyList(
                from: data,
                format: nil
            ) as? [String: Any]
        )

        #expect(plist["CFBundleIconFile"] as? String == "AppIcon")
    }

    @Test("Generated application and menu bar assets exist")
    func generatedAssetsExist() {
        let resources = repositoryRoot.appending(path: "Resources")

        #expect(
            FileManager.default.fileExists(
                atPath:
                    resources.appending(path: "AppIcon.icns").path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath:
                    resources
                        .appending(path: "MDropMenuBarTemplate.pdf")
                        .path
            )
        )
    }

    @Test("Menu bar image is marked as a system template")
    func menuBarImageIsTemplate() {
        let image = NSImage(size: NSSize(width: 18, height: 18))

        let template = BrandAssets.asMenuBarTemplate(image)

        #expect(template.isTemplate)
        #expect(template.size == NSSize(width: 18, height: 18))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
