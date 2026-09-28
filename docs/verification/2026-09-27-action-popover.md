# Shelf action popover — 2026-09-27

- Replaced the compact shelf action menu button with a native SwiftUI popover, following Nexora's action popover pattern.
- Kept native context menus available; shared action content uses disclosure sections only in the popover.
- Bounded the scroll viewport to 560 points (less on small screens), removing vertical fixed-size sizing that let expanded content overflow without scrolling.
- Added full-row disclosure targets, hover feedback, animated arrows and spring expansion/collapse, with reduced-motion support.
- Retained Chinese action titles and constrained application/sharing icons to 16 points.
- Switched the instant-action circles and collapsed lightning surface to native clear glass, retaining accessibility fallbacks.

## Verification

- `swift build` and the Xcode app build passed.
- 15 focused presentation and interaction tests passed.
- Live UI: expanded Open With, scrolled from offset 0 to 1 and back through native scroll actions, expanded/collapsed All Actions, and opened Customize from the action popover.
- Direct wheel automation was unavailable for the detached popover (`windowNotFoundAtPosition`); native accessibility scrolling was verified. The capture API returned only the parent shelf, so popup animation appearance was not independently screenshot-verified.
- Installed `/Applications/MDrop.app`; strict signature verification passed and its executable SHA-256 matched the build: `faa7181b1cce60446f525a9553a58af0e90fb4dac639272b1dd0b9c344ab9e3f`.
- Previous installed bundle preserved at `/tmp/MDrop-before-action-popover-20260927.app`.
