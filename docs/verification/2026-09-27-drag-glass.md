# Drag and glass verification — 2026-09-27

Implemented against the existing modified implementation checkout, preserving its earlier changes.

## Behavior

- Shared native drop lifecycle for shelf, menu-bar, and top drop targets; clear targeting on exit/cancel and negotiate non-destructive source operations.
- One richest representation per pasteboard item; batch promised files and surface errors.
- Shelf import progress, completion feedback, and native drop-image settlement; honor reduced motion.
- Native glass controls with restrained hover/press springs, and a native settings backdrop.
- Clip the native shelf ancestor to the same continuous corner radius as the SwiftUI glass. Animate both radii using shared timing to prevent the rectangular backdrop patch at corners.

## Verification

- `swift build`: passed.
- `swift test`: 29 core tests and 88 app tests passed, including drop lifecycle and rendered corner alpha after resizing across all shelf modes.
- `./script/build_and_run.sh --build-only`: Xcode build and bundle signing passed.
- Installed `/Applications/MDrop.app`; strict deep signature validation passed and installed executable SHA-256 matches `dist/MDrop.app`.
- Installed executable SHA-256: `ca7029437f22e7108fc9c77a285dc95f6e082e43921d7db4cd65e5dff2e1e72f`.
- Native UI inspected on macOS 27: settings, empty shelf (inactive/active), one-file compact shelf, and expanded detail shelf. The visible square patch beyond rounded corners is no longer present. Detail expansion button works.
- External Finder/browser drag and continuous slow-motion capture were not verified. Native drag handling was covered by automated lifecycle tests; an own-shelf drag was attempted with the fixture remaining a single item.

Pre-edit source snapshot and earlier installed app backup: `/tmp/mdrop-glass-20260926/`.
