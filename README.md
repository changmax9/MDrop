# MDrop

MDrop is a local-first file Shelf for macOS 26. It uses AppKit for
nonactivating floating panels and SwiftUI's native Liquid Glass APIs for the
interface.

The app is independently implemented and does not include cloud uploads,
accounts, payments, telemetry, widgets, Control Center controls, or a Share
Extension. System sharing remains available from inside each Shelf.

## Highlights

- Shake-to-create, global shortcuts, menu-bar drop target, and notch drop target
- Nonactivating Shelves across Spaces, full-screen apps, and multiple displays
- Files, folders, text, URLs, images, and asynchronous file promises
- Compact, detail, command-bar, and docked Liquid Glass presentations
- Selection, reordering, Quick Look, outbound dragging, recent and pinned Shelves
- Image resize/convert/compress/metadata removal/stitch/OCR/PDF actions
- ZIP, copy, move, rename, path copy, clipboard, Trash, and system sharing
- Configurable Instant Actions and reusable Custom Action presets
- Shell, AppleScript, and Automator actions with logs, timeouts, and cancellation
- Screenshot/folder monitoring with filtering and batch debounce
- Services, App Intents/Shortcuts, file-open events, and `mdrop://` URLs
- English and Simplified Chinese String Catalog

## Build and run

Requirements: Xcode 26 and macOS 26.

```bash
./script/build_and_run.sh
```

Run the test suite:

```bash
xcodebuild \
  -project MDrop.xcodeproj \
  -scheme MDrop \
  -configuration Debug \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Build the ad-hoc signed app, DMG, and SHA-256 checksum:

```bash
./script/package_unsigned.sh
```

Release artifacts are written to `dist/release`. The DMG includes Gatekeeper
instructions for the unnotarized build.

## Shortcuts and URLs

- `⌥⇧Space`: new Shelf
- `⌥⇧A`: Shelf from clipboard
- `⌥⇧S`: select a Shelf
- `⌘K`: Command Bar
- Space: Quick Look
- `mdrop://new`, `mdrop://clipboard`, `mdrop://last`, `mdrop://close-all`

Example Alfred and Raycast scripts are in `Integrations`.
