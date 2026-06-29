# Reference Shelf Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Match the supplied Dropover recording’s empty Shelf size and fast shake appearance, then give MDrop’s large-to-compact morph, hover chrome, stack, and close transitions one coherent motion profile.

**Architecture:** Put measured geometry and timing values in a pure `MDropCore` profile so they are unit-testable. `ShelfPanelController` owns real `NSPanel` frame and close animations; `ShelfView` and its empty/compact children own content opacity, hover chrome, and stack transitions. The existing shelf records, drag ingestion, and action system remain unchanged.

**Tech Stack:** Swift 6.2, macOS 26 AppKit `NSPanel`, SwiftUI Liquid Glass, XCTest, Xcode 26.

---

### Task 1: Reference Geometry and Timing Profile

**Files:**
- Create: `Sources/MDropCore/ShelfMotionProfile.swift`
- Create: `Tests/MDropCoreTests/ShelfMotionProfileTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import MDropCore

final class ShelfMotionProfileTests: XCTestCase {
    func testEmptyPanelMatchesMeasuredReferenceSurface() {
        XCTAssertEqual(
            ShelfMotionProfile.reference.emptyPanel,
            .init(width: 382, height: 400)
        )
        XCTAssertEqual(
            ShelfMotionProfile.reference.emptyGlassBody,
            .init(width: 362, height: 380)
        )
        XCTAssertEqual(ShelfMotionProfile.reference.emptyCornerRadius, 36)
        XCTAssertEqual(ShelfMotionProfile.reference.emptyLabelPointSize, 15)
    }

    func testMotionDurationsStaySnappy() {
        let profile = ShelfMotionProfile.reference
        XCTAssertEqual(profile.appearanceDuration, 0.08)
        XCTAssertEqual(profile.frameMorphDuration, 0.22)
        XCTAssertEqual(profile.hoverChromeDuration, 0.14)
        XCTAssertEqual(profile.stackDuration, 0.28)
        XCTAssertEqual(profile.closeDuration, 0.10)
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
swift test --filter ShelfMotionProfileTests
```

Expected: compilation fails because `ShelfMotionProfile` is undefined.

- [ ] **Step 3: Implement the measured profile**

```swift
import Foundation

public struct ShelfMotionProfile: Equatable, Sendable {
    public var emptyPanel: ShelfPanelMetrics
    public var emptyGlassBody: ShelfPanelMetrics
    public var emptyCornerRadius: Double
    public var emptyLabelPointSize: Double
    public var appearanceDuration: Double
    public var frameMorphDuration: Double
    public var hoverChromeDuration: Double
    public var stackDuration: Double
    public var closeDuration: Double

    public static let reference = Self(
        emptyPanel: .init(width: 382, height: 400),
        emptyGlassBody: .init(width: 362, height: 380),
        emptyCornerRadius: 36,
        emptyLabelPointSize: 15,
        appearanceDuration: 0.08,
        frameMorphDuration: 0.22,
        hoverChromeDuration: 0.14,
        stackDuration: 0.28,
        closeDuration: 0.10
    )
}
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run:

```bash
swift test --filter ShelfMotionProfileTests
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/MDropCore/ShelfMotionProfile.swift Tests/MDropCoreTests/ShelfMotionProfileTests.swift
git commit -m "feat: define reference shelf motion profile"
```

### Task 2: Exact Empty Shelf Presentation

**Files:**
- Modify: `Sources/MDropApp/Views/ShelfView.swift`
- Modify: `Sources/MDropApp/Stores/ShelfStore.swift`

- [ ] **Step 1: Add view-state fields to `ShelfStore`**

```swift
var isClosing = false
```

- [ ] **Step 2: Make the empty target match the recording**

Pass `store.isReceivingDrop` into `EmptyShelfView`. Change the view to:

```swift
private struct EmptyShelfView: View {
    let isReceivingDrop: Bool
    let onClose: () -> Void
    @State private var isHovering = false

    var body: some View {
        ZStack {
            Text("Drop files here")
                .font(.system(
                    size: ShelfMotionProfile.reference.emptyLabelPointSize,
                    weight: .medium,
                    design: .rounded
                ))
                .foregroundStyle(.secondary)

            emptyChrome
                .opacity(showsChrome ? 1 : 0)
                .scaleEffect(showsChrome ? 1 : 0.92)
        }
        .onHover { hovering in
            withAnimation(.easeOut(
                duration: ShelfMotionProfile.reference.hoverChromeDuration
            )) {
                isHovering = hovering
            }
        }
    }

    private var showsChrome: Bool {
        isHovering && !isReceivingDrop
    }
}
```

Keep the requested close button and drag handle inside `emptyChrome`; do not
show them during an active file drag.

- [ ] **Step 3: Add the content appearance and state transitions**

Add a local `@State private var hasAppeared = false` and Reduce Motion checks
to `ShelfView`. Apply:

```swift
.opacity(store.isClosing ? 0 : (hasAppeared ? 1 : 0))
.scaleEffect(
    store.isClosing ? 0.985 : (hasAppeared ? 1 : 0.985)
)
.onAppear {
    let duration = reduceMotion
        ? 0
        : ShelfMotionProfile.reference.appearanceDuration
    withAnimation(.easeOut(duration: duration)) {
        hasAppeared = true
    }
}
.animation(
    reduceMotion
        ? .linear(duration: 0.01)
        : .snappy(duration: ShelfMotionProfile.reference.stackDuration),
    value: store.shelf.presentationState
)
```

Use `ShelfMotionProfile.reference.emptyCornerRadius` for the empty glass shape.

- [ ] **Step 4: Build**

Run:

```bash
swift build
```

Expected: MDrop builds without warnings.

- [ ] **Step 5: Commit**

```bash
git add Sources/MDropApp/Views/ShelfView.swift Sources/MDropApp/Stores/ShelfStore.swift
git commit -m "feat: match reference empty shelf presentation"
```

### Task 3: Panel Morph and Close Animation

**Files:**
- Modify: `Sources/MDropApp/AppKit/ShelfPanelController.swift`
- Modify: `Sources/MDropApp/Views/CompactStackedShelfView.swift`

- [ ] **Step 1: Use measured empty panel metrics**

Replace the fixed empty size with:

```swift
private let emptySize = NSSize(
    width: ShelfMotionProfile.reference.emptyPanel.width,
    height: ShelfMotionProfile.reference.emptyPanel.height
)
```

- [ ] **Step 2: Replace default frame animation with a controlled ease-out**

```swift
private func resize(to size: NSSize) {
    var frame = panel.frame
    frame.origin.y += frame.height - size.height
    frame.size = size

    guard !reduceMotion else {
        panel.setFrame(frame, display: true)
        return
    }

    NSAnimationContext.runAnimationGroup { context in
        context.duration = ShelfMotionProfile.reference.frameMorphDuration
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        panel.animator().setFrame(frame, display: true)
    }
}
```

Add `import QuartzCore` and a controller-local `reduceMotion` computed property
that combines MDrop’s preference with the system setting.

- [ ] **Step 3: Animate close before coordinator removal**

Give all `ShelfView` close callbacks `requestClose()` instead of directly
calling the coordinator:

```swift
private func requestClose() {
    guard !store.isClosing else { return }
    store.isClosing = true
    let delay = reduceMotion
        ? 0
        : ShelfMotionProfile.reference.closeDuration
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        self.onClose()
    }
}
```

Command-W must call the same method. `close()` remains the final panel teardown.

- [ ] **Step 4: Use the measured stack duration**

In `CompactStackedShelfView`, replace the 0.32-second stack duration with:

```swift
private var stackAnimation: Animation {
    reduceMotion
        ? .linear(duration: 0.12)
        : .snappy(duration: ShelfMotionProfile.reference.stackDuration)
}
```

- [ ] **Step 5: Build and run**

Run:

```bash
swift build
./script/build_and_run.sh --verify
```

Expected: the app launches as a signed `.app`; empty Shelf is 382×400 and first
drop morphs to 166×164 while retaining its top edge.

- [ ] **Step 6: Commit**

```bash
git add Sources/MDropApp/AppKit/ShelfPanelController.swift Sources/MDropApp/Views/CompactStackedShelfView.swift
git commit -m "feat: tune shelf window motion to reference"
```

### Task 4: Free Edition Guard and Release Verification

**Files:**
- Modify only if verification reveals a defect.

- [ ] **Step 1: Verify monetization UI is absent**

Run:

```bash
rg -n -i 'upgrade to pro|trial has expired|trial countdown|premium feature|paid only' Sources Resources Config
```

Expected: no matches.

- [ ] **Step 2: Run all tests**

Run:

```bash
swift test
xcodebuild -project MDrop.xcodeproj -scheme MDrop -configuration Debug -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
```

Expected: all SwiftPM tests pass and Xcode reports `** TEST SUCCEEDED **`.

- [ ] **Step 3: Verify Release and x86_64 source compatibility**

Run:

```bash
xcodebuild -project MDrop.xcodeproj -scheme MDrop -configuration Release -derivedDataPath DerivedData-Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MDrop.xcodeproj -scheme MDrop -configuration Release -derivedDataPath DerivedData-x86 -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO build
```

Expected: both builds report `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Perform real Finder interaction regression**

Verify:

1. start a Finder drag and shake;
2. the 382×400 final frame appears immediately below the pointer;
3. active drag shows only the centered label;
4. ordinary hover reveals close and drag handle;
5. first drop keeps the top edge and morphs to 166×164;
6. two more drops produce the three-card stack;
7. close fades before the window is removed.

- [ ] **Step 5: Package and validate**

Run:

```bash
./script/package_unsigned.sh
shasum -a 256 -c dist/release/MDrop-0.1.0-arm64-unsigned.dmg.sha256
codesign --verify --deep --strict dist/release/MDrop.app
hdiutil verify dist/release/MDrop-0.1.0-arm64-unsigned.dmg
```

Expected: checksum is `OK`, code signature is valid on disk, and the DMG
checksum is valid. Gatekeeper rejection remains expected for ad-hoc signing.
