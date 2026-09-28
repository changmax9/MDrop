# Native action glass and icon alignment

The action rail now has an AppKit NSGlassEffectContainerView with four NSGlassEffectView surfaces, separate from SwiftUI button-label shadow, opacity, and brightness compositing. The surface and glyph layers share the same position policy and ease-in-out duration. Native glass retains reduced-transparency fallback, and empty/collapsed rails hide unused surfaces. This addresses a suspected cause of the flat gray rendering; final visual appearance requires inspection of the detached accessory window.

Menu icons now align to the vertical center of their text block with a fixed 18-point column. Removed the incorrect icon-center-to-text-baseline alignment guide.

Verification: swift build and Xcode bundle build passed. All 29 core and 89 app tests passed, including new native surface bounds, circular radius, expansion, collapse, and empty-state checks. Native geometry checks allow subpixel floating-point differences. Installed bundle passed strict signature validation and its executable matches dist. Previous app preserved at /tmp/MDrop-before-native-rail-20260927.app.

The available screenshot API captures the parent shelf rather than its detached accessory window or popover. Neither final glass appearance nor icon alignment was visually certified through that API.
