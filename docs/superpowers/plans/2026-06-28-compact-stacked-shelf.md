# Compact Stacked Shelf Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild MDrop’s populated compact Shelf as the supplied small vertical dark-glass card, with real thumbnails, a rotated multi-file stack, filename/count capsule, and a complete native action menu.

**Architecture:** Keep `ShelfRecord` and the AppKit `NSPanel` lifecycle unchanged. Add pure layout/cache-key models to `MDropCore`, an app-scoped Quick Look thumbnail service, and focused SwiftUI views for the compact stack and menu. `ShelfPanelController` remains the owner of panel sizing, Quick Look, and drop ingestion.

**Tech Stack:** Swift 6.2, macOS 26, SwiftUI Liquid Glass, AppKit `NSPanel`/`NSSharingService`, QuickLookThumbnailing, XCTest, Xcode 26.

---

### Task 1: Pure Compact Layout Rules

**Files:**
- Create: `Sources/MDropCore/CompactShelfLayout.swift`
- Create: `Tests/MDropCoreTests/CompactShelfLayoutTests.swift`

- [ ] **Step 1: Write failing layout tests**

```swift
import XCTest
@testable import MDropCore

final class CompactShelfLayoutTests: XCTestCase {
    func testPopulatedCompactShelfUsesVerticalReferenceSize() {
        XCTAssertEqual(
            CompactShelfLayout.panelMetrics(itemCount: 1),
            .init(width: 166, height: 164)
        )
        XCTAssertEqual(
            CompactShelfLayout.panelMetrics(itemCount: 8),
            .init(width: 166, height: 164)
        )
    }

    func testThreeItemStackUsesOpposingRearRotations() {
        XCTAssertEqual(
            CompactShelfLayout.transforms(itemCount: 3, reduceMotion: false),
            [
                .init(x: -7, y: 1, rotationDegrees: -7, scale: 0.96),
                .init(x: 7, y: 1, rotationDegrees: 6, scale: 0.97),
                .init(x: 0, y: 0, rotationDegrees: 0, scale: 1)
            ]
        )
    }

    func testReduceMotionRemovesRotation() {
        XCTAssertTrue(
            CompactShelfLayout.transforms(itemCount: 3, reduceMotion: true)
                .allSatisfy { $0.rotationDegrees == 0 }
        )
    }
}
```

- [ ] **Step 2: Run the focused tests and verify they fail**

Run:

```bash
swift test --filter CompactShelfLayoutTests
```

Expected: compilation fails because `CompactShelfLayout` is undefined.

- [ ] **Step 3: Implement deterministic metrics and transforms**

```swift
import Foundation

public struct ShelfPanelMetrics: Equatable, Sendable {
    public var width: Double
    public var height: Double
}

public struct ShelfStackTransform: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var rotationDegrees: Double
    public var scale: Double
}

public enum CompactShelfLayout {
    public static func panelMetrics(itemCount: Int) -> ShelfPanelMetrics {
        ShelfPanelMetrics(width: 166, height: 164)
    }

    public static func transforms(
        itemCount: Int,
        reduceMotion: Bool
    ) -> [ShelfStackTransform] {
        let visibleCount = min(max(itemCount, 0), 3)
        let base = Array([
            ShelfStackTransform(x: -7, y: 1, rotationDegrees: -7, scale: 0.96),
            ShelfStackTransform(x: 7, y: 1, rotationDegrees: 6, scale: 0.97),
            ShelfStackTransform(x: 0, y: 0, rotationDegrees: 0, scale: 1)
        ].suffix(visibleCount))
        guard reduceMotion else { return base }
        return base.map {
            ShelfStackTransform(
                x: $0.x,
                y: $0.y,
                rotationDegrees: 0,
                scale: $0.scale
            )
        }
    }
}
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
swift test --filter CompactShelfLayoutTests
```

Expected: all `CompactShelfLayoutTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/MDropCore/CompactShelfLayout.swift Tests/MDropCoreTests/CompactShelfLayoutTests.swift
git commit -m "feat: define compact shelf layout rules"
```

### Task 2: Thumbnail Cache Identity and Quick Look Service

**Files:**
- Create: `Sources/MDropCore/ThumbnailCacheKey.swift`
- Create: `Tests/MDropCoreTests/ThumbnailCacheKeyTests.swift`
- Create: `Sources/MDropApp/Services/ThumbnailService.swift`
- Create: `Sources/MDropApp/Views/ShelfThumbnailView.swift`

- [ ] **Step 1: Write a failing cache-key test**

```swift
import Foundation
import XCTest
@testable import MDropCore

final class ThumbnailCacheKeyTests: XCTestCase {
    func testKeyChangesWithFileModificationOrRequestedSize() {
        let url = URL(filePath: "/tmp/example.pdf")
        let first = ThumbnailCacheKey(
            url: url,
            modificationDate: Date(timeIntervalSince1970: 1),
            width: 80,
            height: 96,
            scale: 2
        )
        let modified = ThumbnailCacheKey(
            url: url,
            modificationDate: Date(timeIntervalSince1970: 2),
            width: 80,
            height: 96,
            scale: 2
        )
        let resized = ThumbnailCacheKey(
            url: url,
            modificationDate: Date(timeIntervalSince1970: 1),
            width: 120,
            height: 120,
            scale: 2
        )

        XCTAssertNotEqual(first, modified)
        XCTAssertNotEqual(first, resized)
    }
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
swift test --filter ThumbnailCacheKeyTests
```

Expected: compilation fails because `ThumbnailCacheKey` is undefined.

- [ ] **Step 3: Implement `ThumbnailCacheKey`**

```swift
import Foundation

public struct ThumbnailCacheKey: Hashable, Sendable {
    public var standardizedPath: String
    public var modificationDate: Date?
    public var width: Int
    public var height: Int
    public var scale: Int

    public init(
        url: URL,
        modificationDate: Date?,
        width: Int,
        height: Int,
        scale: Int
    ) {
        standardizedPath = url.standardizedFileURL.path
        self.modificationDate = modificationDate
        self.width = width
        self.height = height
        self.scale = scale
    }
}
```

- [ ] **Step 4: Implement the thumbnail service**

Create a `@MainActor` singleton with:

```swift
import AppKit
import MDropCore
import QuickLookThumbnailing

@MainActor
final class ThumbnailService {
    static let shared = ThumbnailService()
    private let cache = NSCache<NSString, NSImage>()

    func thumbnail(
        for url: URL,
        size: CGSize,
        scale: CGFloat
    ) async -> NSImage {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let key = ThumbnailCacheKey(
            url: url,
            modificationDate: values?.contentModificationDate,
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded()),
            scale: Int(scale.rounded())
        )
        let cacheKey = String(describing: key) as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        let image = await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(
                for: request
            ) { representation, _ in
                continuation.resume(
                    returning: representation?.nsImage
                    ?? NSWorkspace.shared.icon(forFile: url.path)
                )
            }
        }
        cache.setObject(image, forKey: cacheKey)
        return image
    }
}
```

- [ ] **Step 5: Implement `ShelfThumbnailView`**

The view must show the Finder icon immediately, request an 80×96 thumbnail in
`.task(id:)`, crossfade when loaded, preserve aspect ratio, and expose
`.onDrag { makeItemProvider(for:) }`.

- [ ] **Step 6: Run focused tests and build**

```bash
swift test --filter ThumbnailCacheKeyTests
swift build
```

Expected: tests pass and MDrop builds without warnings.

- [ ] **Step 7: Commit**

```bash
git add Sources/MDropCore/ThumbnailCacheKey.swift Tests/MDropCoreTests/ThumbnailCacheKeyTests.swift Sources/MDropApp/Services/ThumbnailService.swift Sources/MDropApp/Views/ShelfThumbnailView.swift
git commit -m "feat: add quick look shelf thumbnails"
```

### Task 3: Compact Stacked Shelf View

**Files:**
- Create: `Sources/MDropApp/Views/CompactStackedShelfView.swift`
- Modify: `Sources/MDropApp/Views/ShelfView.swift`
- Modify: `Sources/MDropApp/Views/SettingsView.swift`

- [ ] **Step 1: Extract the populated compact presentation**

Create `CompactStackedShelfView` with explicit callbacks:

```swift
struct CompactStackedShelfView: View {
    @Bindable var store: ShelfStore
    let onExpand: () -> Void
    let onDock: () -> Void
    let onQuickLook: () -> Void
    let onAddClipboard: () -> Void
    let onAction: (BuiltinActionID) -> Void
    let onChange: () -> Void
    let onClose: () -> Void
}
```

Use a `ZStack` for:

- centered `Capsule().frame(width: 34, height: 5)` drag handle;
- 30×30 glass close and menu controls;
- a 78×94 `ShelfThumbnailStack`;
- bottom glass filename/count capsule;
- the existing instant-action buttons when expanded.

- [ ] **Step 2: Implement the stack**

Render only `store.shelf.items.suffix(3)` and pair items with
`CompactShelfLayout.transforms`. Apply:

```swift
.offset(x: transform.x, y: transform.y)
.rotationEffect(.degrees(transform.rotationDegrees))
.scaleEffect(transform.scale)
.zIndex(Double(index))
```

Use `.snappy` when motion is enabled and `.linear(duration: 0.12)` when either
MDrop or the system Reduce Motion setting is enabled.

- [ ] **Step 3: Implement filename/count labels**

- One item: truncate the item’s display name in the middle.
- Multiple files whose URLs are all directories: `"\(count) Folders"`.
- Multiple non-folder files: `"\(count) Documents"`.
- Mixed payloads: `"\(count) Items"`.
- The capsule is a button that calls `onExpand`.

- [ ] **Step 4: Apply the dark glass treatment**

At the Shelf root:

```swift
.environment(\.colorScheme, .dark)
.glassEffect(
    .regular.tint(Color(red: 0.06, green: 0.10, blue: 0.16).opacity(0.72))
        .interactive(),
    in: .rect(cornerRadius: 30)
)
```

Keep one `GlassEffectContainer`, semantic foreground colors, and a thin
high-contrast overlay only when accessibility contrast is increased.

- [ ] **Step 5: Replace the old `CompactShelfView`**

Update `ShelfView` to instantiate `CompactStackedShelfView` for `.compact` and
`.instantActions`. Delete the old horizontal compact implementation after the
new view builds.

- [ ] **Step 6: Build and run**

```bash
swift build
./script/build_and_run.sh --verify
```

Expected: a populated Shelf is vertical, 166×164, dark glass, and shows a
rotated stack for multiple items.

- [ ] **Step 7: Commit**

```bash
git add Sources/MDropApp/Views/CompactStackedShelfView.swift Sources/MDropApp/Views/ShelfView.swift Sources/MDropApp/Views/SettingsView.swift
git commit -m "feat: redesign compact shelf as stacked glass card"
```

### Task 4: Native Shelf Action Menu

**Files:**
- Create: `Sources/MDropApp/Views/ShelfMenuContent.swift`
- Modify: `Sources/MDropApp/Views/CompactStackedShelfView.swift`
- Modify: `Sources/MDropApp/AppKit/ShelfPanelController.swift`

- [ ] **Step 1: Add controller-owned callbacks**

Pass two new closures into `ShelfView` and `CompactStackedShelfView`:

```swift
onQuickLook: { [weak self] in self?.quickLookSelectedItems() }
onAddClipboard: {
    onDrop(PasteboardReader.representations(from: .general))
}
```

`quickLookSelectedItems()` resolves the selected items or all items and calls
the existing `QuickLookController`.

- [ ] **Step 2: Implement native menu content**

Create reusable `ShelfMenuContent` that renders:

- an Open With submenu from
  `NSWorkspace.shared.urlsForApplications(toOpen:)`;
- Show in Finder and Quick Look;
- available `NSSharingService.sharingServices(forItems:)`;
- Add From Clipboard;
- Copy item URLs/text to `NSPasteboard.general`;
- Copy to…, Move to…, and All Actions using existing callbacks;
- Clear Shelf, Dock to Edge, Pin/Unpin;
- Settings via `showSettingsWindow:`.

Do not add cloud-link, account, upgrade, Widget, Control Center, or Share
Extension entries.

- [ ] **Step 3: Connect menu entry points**

Use `Menu` with the circular chevron-down label and attach the same content to
`.contextMenu` on the whole Shelf.

- [ ] **Step 4: Verify actions manually**

From a two-file Shelf verify:

- Show in Finder selects the files;
- Quick Look opens;
- system sharing services are present;
- Copy to and Move to open their panels;
- Clear returns the Shelf to the large empty state;
- Dock to Edge still works.

- [ ] **Step 5: Commit**

```bash
git add Sources/MDropApp/Views/ShelfMenuContent.swift Sources/MDropApp/Views/CompactStackedShelfView.swift Sources/MDropApp/AppKit/ShelfPanelController.swift
git commit -m "feat: add native compact shelf menu"
```

### Task 5: Content-Aware Panel Sizing and Morph

**Files:**
- Modify: `Sources/MDropApp/AppKit/ShelfPanelController.swift`
- Modify: `Sources/MDropApp/Views/ShelfView.swift`

- [ ] **Step 1: Use core compact metrics**

Replace the fixed 300×146 compact size with:

```swift
let metrics = CompactShelfLayout.panelMetrics(
    itemCount: store.shelf.items.count
)
let compactSize = NSSize(width: metrics.width, height: metrics.height)
```

Keep empty, detail, and docked sizes unchanged.

- [ ] **Step 2: Preserve top-edge anchoring**

Retain the current `frame.origin.y += frame.height - size.height` behavior and
ensure `refreshSize()` runs after every ingest, remove, clear, and presentation
state change.

- [ ] **Step 3: Tune corner radius and transitions**

Use 30 points for populated compact, 44 for empty, 26 for detail, and 20 for
docked. Keep `glassEffectID(store.shelf.id, in:)` stable across morphs.

- [ ] **Step 4: Run shake/drop regression**

Use Finder and `MDropHarness` to verify:

- shaking a dragged file opens the 396×414 target;
- dropping it morphs to 166×164 without moving the top edge;
- adding two more files produces the rotated stack and correct count;
- dropping a fourth item updates the count while rendering only three cards.

- [ ] **Step 5: Commit**

```bash
git add Sources/MDropApp/AppKit/ShelfPanelController.swift Sources/MDropApp/Views/ShelfView.swift
git commit -m "feat: morph shelf into compact stacked layout"
```

### Task 6: Full Verification and Release Artifacts

**Files:**
- Modify only if verification reveals a defect.

- [ ] **Step 1: Run all tests**

```bash
swift test
xcodebuild -project MDrop.xcodeproj -scheme MDrop -configuration Debug -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
```

Expected: all existing and new tests pass.

- [ ] **Step 2: Verify source compatibility**

```bash
xcodebuild -project MDrop.xcodeproj -scheme MDrop -configuration Release -derivedDataPath DerivedData-x86 -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO build
```

Expected: x86_64 source-compatible Release build succeeds.

- [ ] **Step 3: Run visual and interaction regression**

Verify single file, stacked files, folder stack, right-click/menu, drag-out,
shake activation, close, clear, detail, docked edge, Reduce Motion, and
high-contrast appearance in the real `.app`.

- [ ] **Step 4: Package**

```bash
./script/package_unsigned.sh
shasum -a 256 -c dist/release/MDrop-0.1.0-arm64-unsigned.dmg.sha256
codesign --verify --deep --strict dist/release/MDrop.app
```

Expected: `.app`, `.dmg`, and checksum are regenerated and valid.

- [ ] **Step 5: Commit final fixes if any**

```bash
git add .
git commit -m "fix: finish compact shelf visual regression"
```
