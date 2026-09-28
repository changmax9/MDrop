# Accessory window glass isolation

User screenshots disproved both earlier in-host native glass and the extra behind-window blur layer. Removed the blur layer and NSViewRepresentable backdrop. Native clear glass now lives directly under the SwiftUI hosting view as a sibling inside the accessory window. SwiftUI reports layout and accessibility preferences to the window controller; glass and foreground share the same geometry and timing.

Swift and Xcode builds passed; 16 focused tests passed. Installed bundle signature and binary hash verified. Prior bundle retained at /tmp/MDrop-before-window-sibling-20260927.app.

Visual success is pending user feedback. The available app screenshot capture cannot target the detached accessory window. Do not treat passing layout tests or use of NSGlassEffectView as evidence that the flat gray appearance is resolved.
