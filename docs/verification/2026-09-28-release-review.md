# MDrop 0.3.0 release review

Reviewed the pending Shelf interaction/settings work and file-action paths. Fixed unchanged-name rename adding a numeric suffix, ZIP text/link filename collisions replacing staged files, and repeated action dispatch while an operation is already active. Added real filesystem regression cases for rename and archive contents while preserving the existing test suite.

Refreshed the editable Folded M SVG into a blue folded ribbon on a pearl macOS tile; regenerated the full ICNS size set. The monochrome menu-bar template is preserved.

Validation:

- `swift test`: 35 XCTest cases, 31 core Swift Testing cases, and 89 app Swift Testing cases passed (155 total).
- `swift build`: passed.
- Xcode Debug build and launch/process verification: passed.
- Xcode Release build and DMG packaging: passed.
- DMG integrity and portable SHA-256 checksum: passed.
- `/Applications/MDrop.app`: version 0.3.0 (6), deep/strict signature verification passed; executable SHA-256 matches the release bundle.
- Previous installed app preserved in the user's MDrop Application Support Backups directory.

Limitations: native UI automation timed out during this review, so current visual interaction checks were not completed. The running release process was sampled in its normal AppKit event loop, without a busy main-thread loop. Sparkle signing is waiting on Keychain access; the existing signed 0.2.3 appcast remains intact until a valid new signature is available. The download is ad-hoc signed, not notarized, consistent with previous releases.
