# Shelf Motion, Glass, and Detail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Match the supplied Shelf references with adaptive clear Liquid Glass, full-background window dragging, a hover/drag handle, long-name marquee, center-origin jelly entrance, and a compact-to-detail morph.

**Architecture:** Keep timing and geometry as pure `MDropCore` values with focused tests. Use an AppKit overlay only for window movement and hover reporting, while SwiftUI owns all appearance, glass, marquee, and content transitions. Keep one nonactivating transparent `NSPanel`; resize it around its center instead of introducing another window.

**Tech Stack:** Swift 6.2, AppKit `NSPanel`/`NSView`, SwiftUI for macOS 26 Liquid Glass, Observation, Swift Testing and XCTest.

---

### Task 1: Encode Reference Motion, Marquee, and Drag Geometry

**Files:**
- Create: `Sources/MDropCore/ShelfMarqueeMetrics.swift`
- Create: `Sources/MDropCore/ShelfDragLayout.swift`
- Modify: `Sources/MDropCore/ShelfMotionProfile.swift`
- Create: `Tests/MDropCoreTests/ShelfMarqueeMetricsTests.swift`
- Create: `Tests/MDropCoreTests/ShelfDragLayoutTests.swift`
- Modify: `Tests/MDropCoreTests/ShelfMotionProfileTests.swift`

- [ ] **Step 1: Write failing marquee and drag-layout tests**

```swift
@Test func overflowUsesMeasuredTravelAndSpeed() {
    let metrics = ShelfMarqueeMetrics.measure(
        textWidth: 180,
        viewportWidth: 112
    )
    #expect(metrics.travelDistance == 68)
    #expect(metrics.travelDuration == 68.0 / 24.0)
}

@Test func fittingTextDoesNotTravel() {
    #expect(
        ShelfMarqueeMetrics.measure(
            textWidth: 80,
            viewportWidth: 112
        ).travelDistance == 0
    )
}

func testCompactInteractiveRegionsProtectControlsAndFileDrag() {
    let layout = ShelfDragLayout.compact(panelSize: .init(width: 198, height: 207))
    XCTAssertTrue(layout.isInteractive(CGPoint(x: 23, y: 184)))
    XCTAssertTrue(layout.isInteractive(CGPoint(x: 99, y: 105)))
    XCTAssertTrue(layout.isInteractive(CGPoint(x: 99, y: 20)))
    XCTAssertFalse(layout.isInteractive(CGPoint(x: 20, y: 100)))
}
```

- [ ] **Step 2: Run focused tests and verify they fail**

Run:

```bash
swift test --filter ShelfMarqueeMetricsTests
swift test --filter ShelfDragLayoutTests
```

Expected: compilation fails because `ShelfMarqueeMetrics` and `ShelfDragLayout` do not exist.

- [ ] **Step 3: Add pure metrics and geometry**

```swift
public struct ShelfMarqueeMetrics: Equatable, Sendable {
    public let travelDistance: Double
    public let travelDuration: Double

    public static func measure(
        textWidth: Double,
        viewportWidth: Double,
        pointsPerSecond: Double = 24
    ) -> Self {
        let distance = max(0, textWidth - viewportWidth)
        return .init(
            travelDistance: distance,
            travelDuration: distance == 0 ? 0 : distance / pointsPerSecond
        )
    }
}

public struct ShelfDragLayout: Equatable, Sendable {
    public let interactiveRegions: [CGRect]

    public func isInteractive(_ point: CGPoint) -> Bool {
        interactiveRegions.contains { $0.contains(point) }
    }

    public static func compact(panelSize: CGSize) -> Self {
        .init(interactiveRegions: [
            CGRect(x: 7, y: panelSize.height - 39, width: 32, height: 32),
            CGRect(x: panelSize.width - 39, y: panelSize.height - 39, width: 32, height: 32),
            CGRect(x: 48, y: 45, width: 102, height: 118),
            CGRect(x: 32, y: 5, width: 134, height: 34)
        ])
    }
}
```

- [ ] **Step 4: Extend the reference motion profile**

Add fixed values for:

```swift
handleHoverWidth: 20,
handleDraggingWidth: 36,
handleHeight: 4,
marqueeInitialDelay: 0.7,
marqueePointsPerSecond: 24,
jellyDuration: 0.42,
jellyContentDelay: 0.09,
frameMorphDuration: 0.36,
layoutFadeDuration: 0.11,
reducedMotionDuration: 0.16
```

Update `ShelfMotionProfileTests` to assert every value.

- [ ] **Step 5: Run the focused core tests**

Run:

```bash
swift test --filter ShelfMarqueeMetricsTests
swift test --filter ShelfDragLayoutTests
swift test --filter ShelfMotionProfileTests
```

Expected: all focused tests pass.

- [ ] **Step 6: Commit the pure behavior**

```bash
git add Sources/MDropCore Tests/MDropCoreTests
git commit -m "feat: encode shelf interaction and motion metrics"
```

### Task 2: Make the Whole Non-Interactive Shelf Move

**Files:**
- Modify: `Sources/MDropApp/AppKit/ShelfPanelController.swift`
- Modify: `Sources/MDropApp/Stores/ShelfStore.swift`

- [ ] **Step 1: Add transient interaction state**

Add these non-persisted properties to `ShelfStore`:

```swift
var isShelfHovered = false
var isWindowDragging = false
var isLayoutContentVisible = true
let animatesInitialAppearance: Bool

init(shelf: ShelfRecord, animatesInitialAppearance: Bool = true) {
    self.shelf = shelf
    self.animatesInitialAppearance = animatesInitialAppearance
}
```

- [ ] **Step 2: Replace the top-only drag handle with a drag surface**

Implement `ShelfWindowDragSurfaceView` as a transparent sibling above the
hosting view. Its `hitTest(_:)` returns `nil` for right-click events and for
points inside `ShelfDragLayout` interactive regions; otherwise it returns
itself. Its `mouseDown(with:)` sets `onDraggingChanged(true)`, calls
`window?.performDrag(with:)`, then resets the state with
`onDraggingChanged(false)`.

```swift
final class ShelfWindowDragSurfaceView: NSView {
    var layout: () -> ShelfDragLayout = {
        .init(interactiveRegions: [])
    }
    var onDraggingChanged: (Bool) -> Void = { _ in }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if NSApp.currentEvent?.type == .rightMouseDown {
            return nil
        }
        return layout().isInteractive(point) ? nil : self
    }

    override func mouseDown(with event: NSEvent) {
        onDraggingChanged(true)
        window?.performDrag(with: event)
        onDraggingChanged(false)
    }
}
```

- [ ] **Step 3: Track hover without activating the panel**

Add an `.activeAlways` tracking area to `ShelfDropContainerView`. Report
`mouseEntered`/`mouseExited` to `store.isShelfHovered`. Preserve
`ShelfPanel.canBecomeKey == false`, `panel.hasShadow == false`, and the clear,
non-opaque content layers so clicking never reveals a rectangular focus box.

- [ ] **Step 4: Select exclusion geometry for every presentation state**

Use `ShelfDragLayout.compact` for compact/instant-actions, a close-button
exclusion for empty, all controls/items for detail, and the undock/close
controls for docked. Refresh the drag surface when the presentation state or
item count changes.

- [ ] **Step 5: Build the application target**

Run:

```bash
swift build --product MDrop
```

Expected: the `MDrop` product builds successfully.

- [ ] **Step 6: Commit AppKit movement**

```bash
git add Sources/MDropApp/AppKit/ShelfPanelController.swift Sources/MDropApp/Stores/ShelfStore.swift
git commit -m "feat: drag shelf from its full background"
```

### Task 3: Add Adaptive Glass, Handle Motion, and Filename Marquee

**Files:**
- Create: `Sources/MDropApp/Views/ShelfMarqueeText.swift`
- Modify: `Sources/MDropApp/Views/CompactStackedShelfView.swift`
- Modify: `Sources/MDropApp/Views/ShelfView.swift`

- [ ] **Step 1: Implement a measured marquee view**

`ShelfMarqueeText` measures its text and clipped viewport, waits 700 ms, moves
left at 24 pt/s, pauses 700 ms, returns, and repeats. It cancels its task when
the text, width, or view lifecycle changes. Under Reduce Motion it uses one
line with middle truncation.

```swift
struct ShelfMarqueeText: View {
    let text: String
    @State private var textWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var task: Task<Void, Never>?

    private var metrics: ShelfMarqueeMetrics {
        .measure(
            textWidth: textWidth,
            viewportWidth: viewportWidth
        )
    }
}
```

- [ ] **Step 2: Replace middle truncation in the bottom capsule**

Keep the chevron in a fixed trailing slot and place `ShelfMarqueeText` in a
clipped leading viewport. The capsule remains at most 126 pt wide and keeps its
29 pt height.

- [ ] **Step 3: Drive the handle from Shelf hover and movement**

Render one 4 pt capsule at the top:

```swift
Capsule()
    .fill(.secondary.opacity(0.55))
    .frame(
        width: store.isWindowDragging ? 36 : 20,
        height: 4
    )
    .opacity(store.isShelfHovered || store.isWindowDragging ? 1 : 0)
```

Use a damped spring for width and opacity, and apply the same component to
empty and compact layouts. Do not scale the close or actions buttons.

- [ ] **Step 4: Match light and dark circular controls**

Read `colorScheme` in `ShelfCircleControlLabel`. Light mode uses a dark icon,
subtle dark translucent fill, and dark outline. Dark mode uses a near-white
icon, translucent charcoal fill, faint white outline, and the same smooth black
hover shadow. Hover changes only shadow opacity/radius/y.

- [ ] **Step 5: Change the root material to clear Liquid Glass**

Use `.clear` for the root Shelf glass and retain the adaptive continuous rounded
outline. Keep the window itself transparent; do not add a color-filled
rectangle behind the rounded glass.

- [ ] **Step 6: Run tests and build**

Run:

```bash
swift test
swift build --product MDrop
```

Expected: all tests pass and the app target builds.

- [ ] **Step 7: Commit the visual interaction pass**

```bash
git add Sources/MDropApp/Views
git commit -m "feat: match shelf glass handle and filename motion"
```

### Task 4: Add the Center-Origin Jelly Entrance

**Files:**
- Modify: `Sources/MDropApp/Services/ShelfCoordinator.swift`
- Modify: `Sources/MDropApp/AppKit/ShelfPanelController.swift`
- Modify: `Sources/MDropApp/Views/ShelfView.swift`

- [ ] **Step 1: Distinguish new and restored shelves**

Change `show` and `ShelfPanelController.init` to accept
`animatesInitialAppearance`. `restore()` passes `false`; shake/hot-key/drop
creation passes `true`.

- [ ] **Step 2: Separate surface motion from content motion**

In `ShelfView`, put clear glass in its own rounded surface layer. For an animated
entrance initialize:

```swift
surfaceScaleX = 0.18
surfaceScaleY = 0.12
surfaceOpacity = 0
contentOpacity = 0
contentScale = 0.96
```

Keep the panel frame at final size and apply `.scaleEffect(x:y:anchor:.center)`
only to the surface. Start horizontal and vertical damped springs together,
with vertical settling through 1.04 to 1.0. After 90 ms, fade/scale content to
1.0. Restored shelves start at all final values.

- [ ] **Step 3: Provide the reduced-motion entrance**

When either Reduce Motion source is active, leave both scales at 1 and animate
only opacity for 160 ms.

- [ ] **Step 4: Build and manually trigger the shake path**

Run:

```bash
swift build --product MDrop
```

Launch the built app, drag a file in Finder, shake the pointer, and verify the
Shelf grows from its own center without a position jump.

- [ ] **Step 5: Commit the entrance**

```bash
git add Sources/MDropApp
git commit -m "feat: add center-origin jelly shelf entrance"
```

### Task 5: Rebuild the Reference Detail Shelf and Morph

**Files:**
- Modify: `Sources/MDropApp/AppKit/ShelfPanelController.swift`
- Modify: `Sources/MDropApp/Views/ShelfView.swift`
- Modify: `Sources/MDropApp/Stores/ShelfStore.swift`

- [ ] **Step 1: Set the reference detail dimensions**

Change `detailSize` to 430 × 180 pt. Rewrite `resize(to:)` so both axes remain
centered:

```swift
frame.origin.x += (frame.width - size.width) / 2
frame.origin.y += (frame.height - size.height) / 2
frame.size = size
```

Clamp the final frame to the active screen visible frame and animate it for
360 ms when motion is enabled.

- [ ] **Step 2: Crossfade layout content around the frame morph**

Set `isLayoutContentVisible` false, begin the centered frame resize, switch
`presentationState`, then reveal the new layout after 120 ms. Use a 110 ms
fade for old content and a damped content scale from 0.98 to 1.0. Reduced
Motion crossfades for 160 ms without overshoot.

- [ ] **Step 3: Replace the tall list with the supplied horizontal detail**

Build a 430 × 180 layout with:

- circular back control plus live “1 Document”/“N Documents” and total size at
  top left;
- customize/view controls at top right;
- horizontally scrollable file thumbnails and names;
- a `Reveal in Finder` action that calls
  `NSWorkspace.shared.activateFileViewerSelecting(urls)`;
- file `.onDrag` providers so Finder drag-out works in detail mode.

- [ ] **Step 4: Verify inverse morph and interaction exclusions**

Open and close detail repeatedly. Confirm center anchoring, no rectangular
backing, no overlapping full-opacity layouts, no window movement when dragging
a file, and no Pro/trial content.

- [ ] **Step 5: Run full verification**

Run:

```bash
swift test
swift build --configuration release --product MDrop
```

Expected: all tests pass and Release builds successfully.

- [ ] **Step 6: Commit the detail morph**

```bash
git add Sources/MDropApp
git commit -m "feat: morph compact shelf into reference detail layout"
```

### Task 6: Package, Sign, and Run the Final App

**Files:**
- Modify only if required by verification: `script/build_and_run.sh`
- Modify only if required by verification: `script/package_unsigned.sh`

- [ ] **Step 1: Run the complete regression suite**

Run:

```bash
swift test
swift build --configuration release --product MDrop
```

Expected: the full test suite and Release product succeed.

- [ ] **Step 2: Build the app bundle and verify signing**

Run the repository packaging scripts, using the stable ad-hoc designated
requirement in `Config/MDrop.requirements`. Verify:

```bash
codesign --verify --deep --strict dist/release/MDrop.app
codesign -d -r- dist/release/MDrop.app
```

Expected: strict verification succeeds and the requirement identifies
`com.maxchang.MDrop`.

- [ ] **Step 3: Produce the DMG and checksum**

Run `script/package_unsigned.sh`, then:

```bash
shasum -a 256 dist/release/MDrop-0.1.0-arm64-adhoc.dmg
```

Record the exact SHA-256.

- [ ] **Step 4: Launch the final bundle**

Quit any prior MDrop process and open
`/Users/maxchang/Documents/MDrop/dist/release/MDrop.app`. Verify the menu-bar
item appears and a Finder shake creates the final animated Shelf.
