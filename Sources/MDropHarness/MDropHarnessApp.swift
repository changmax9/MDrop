import AppKit
import SwiftUI

@main
struct MDropHarnessApp: App {
    var body: some Scene {
        WindowGroup("MDrop Drag Harness") {
            HarnessView()
                .frame(width: 520, height: 320)
        }
    }
}

private struct HarnessView: View {
    @State private var lastDrop = "Nothing dropped yet"

    var body: some View {
        VStack(spacing: 24) {
            Text("MDrop Drag Harness")
                .font(.title2.bold())
            HStack(spacing: 18) {
                dragSource("Text", symbol: "text.quote") {
                    NSItemProvider(object: "Hello from MDrop Harness" as NSString)
                }
                dragSource("URL", symbol: "link") {
                    NSItemProvider(object: URL(string: "https://example.com")! as NSURL)
                }
                dragSource("File", symbol: "doc") {
                    let url = FileManager.default.temporaryDirectory
                        .appending(path: "MDrop Harness.txt")
                    try? Data("MDrop Harness".utf8).write(to: url)
                    return NSItemProvider(contentsOf: url) ?? NSItemProvider()
                }
            }
            Text(lastDrop)
                .foregroundStyle(.secondary)
            Text("Use these sources to verify MDrop inbound and outbound drags.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
    }

    private func dragSource(
        _ title: String,
        symbol: String,
        provider: @escaping () -> NSItemProvider
    ) -> some View {
        Label(title, systemImage: symbol)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
            .onDrag(provider)
    }
}
