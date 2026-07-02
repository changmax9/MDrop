import Foundation
import Testing
@testable import MDropApp

@Suite("Sparkle update configuration")
struct UpdateConfigurationTests {
    @Test("Uses the pinned Sparkle release and production feed")
    func packageAndFeed() throws {
        let root = repositoryRoot
        let package = try String(
            contentsOf: root.appending(path: "Package.swift"),
            encoding: .utf8
        )

        #expect(package.contains("exact: \"2.9.2\""))
        #expect(
            UpdateConfiguration.feedURL
                == URL(
                    string:
                        "https://raw.githubusercontent.com/changmax9/MDrop/main/appcast.xml"
                )
        )
    }

    @Test("Info plist opts into secure automatic updates")
    func infoPlist() throws {
        let data = try Data(
            contentsOf:
                repositoryRoot.appending(path: "Config/Info.plist")
        )
        let plist = try #require(
            PropertyListSerialization.propertyList(
                from: data,
                format: nil
            ) as? [String: Any]
        )

        #expect(
            plist["SUFeedURL"] as? String
                == UpdateConfiguration.feedURL.absoluteString
        )
        #expect(plist["SUEnableAutomaticChecks"] as? Bool == true)
        #expect(plist["SUAutomaticallyUpdate"] as? Bool == false)
        let publicKey = try #require(plist["SUPublicEDKey"] as? String)
        #expect(!publicKey.isEmpty)
        #expect(!publicKey.contains("PLACEHOLDER"))
    }

    @Test("Release metadata is monotonic and current")
    func releaseMetadata() throws {
        let info = try String(
            contentsOf:
                repositoryRoot.appending(path: "Config/Info.plist"),
            encoding: .utf8
        )
        let project = try String(
            contentsOf:
                repositoryRoot
                    .appending(path: "MDrop.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )

        #expect(info.contains("$(MARKETING_VERSION)"))
        #expect(info.contains("$(CURRENT_PROJECT_VERSION)"))
        #expect(project.contains("MARKETING_VERSION = 0.2.0;"))
        #expect(project.contains("CURRENT_PROJECT_VERSION = 2;"))
    }

    @Test("SwiftPM release bundle can load the embedded framework")
    func swiftPMFrameworkRuntimePath() throws {
        let root = repositoryRoot
        let package = try String(
            contentsOf: root.appending(path: "Package.swift"),
            encoding: .utf8
        )
        let buildScript = try String(
            contentsOf:
                root.appending(path: "script/build_and_run.sh"),
            encoding: .utf8
        )

        #expect(
            package.contains("@executable_path/../Frameworks")
        )
        #expect(buildScript.contains("Sparkle.framework"))
    }

    @Test("Dockless app declares gentle scheduled reminders")
    func gentleReminders() throws {
        let source = try String(
            contentsOf:
                repositoryRoot.appending(
                    path:
                        "Sources/MDropApp/Services/UpdateService.swift"
                ),
            encoding: .utf8
        )

        #expect(
            source.contains(
                "supportsGentleScheduledUpdateReminders"
            )
        )
    }

    @Test("Appcast describes the signed GitHub release")
    func appcast() throws {
        let appcast = try String(
            contentsOf:
                repositoryRoot.appending(path: "appcast.xml"),
            encoding: .utf8
        )

        #expect(appcast.contains("<sparkle:version>2</sparkle:version>"))
        #expect(
            appcast.contains(
                "<sparkle:shortVersionString>0.2.0</sparkle:shortVersionString>"
            )
        )
        #expect(
            appcast.contains(
                "<sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>"
            )
        )
        #expect(
            appcast.contains(
                "releases/download/v0.2.0/MDrop-0.2.0-arm64.dmg"
            )
        )
        #expect(appcast.contains("length=\"3134049\""))
        #expect(appcast.contains("sparkle:edSignature="))
    }

    @Test("Release checksum is portable outside the build machine")
    func portableChecksum() throws {
        let script = try String(
            contentsOf:
                repositoryRoot.appending(
                    path: "script/package_unsigned.sh"
                ),
            encoding: .utf8
        )

        #expect(
            script.contains(
                "shasum -a 256 \"$(basename \"$DMG_PATH\")\""
            )
        )
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
