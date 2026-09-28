# Action layout and settings glass

- Replaced menu-specific Section layout within popovers with explicit, spaced section headers; aligned icon columns and added exterior scroll viewport insets to protect the bottom rounded edge and hover surfaces.
- Added native glass capsule selectors and bounded popovers for language and all four instant-action slots. Checkmarks preserve selection visibility; Escape dismisses popovers.
- Settings toggles now use native switches.
- Settings page fade/offset transitions animate from a persistent parent instead of the replaced page. Reduced-motion preferences disable the movement.
- Routed Command-comma to the same custom glass settings window as other settings entry points.

Validation: Swift build and Xcode bundle build passed. 29 core and 88 app tests passed. Removed the obsolete implementation-specific test requiring an AppKit child view under the former Menu; native UI verification confirms the replacement SwiftUI button opens the popover. Existing context-menu tests remain.

Native UI checks: action group expansion and scrolling to the end; settings language and instant-action popovers; selected checkmarks; option-list scroll offset from 0 to 1; Escape dismissal; settings sidebar navigation; Command-comma opens the custom window. Popup screenshot capture remains limited to the parent window, so submenu spacing and animation smoothness still warrant human visual review.

Installed and signature-verified /Applications/MDrop.app with matching build executable hash. Previous installed bundle: /tmp/MDrop-before-settings-glass-20260927.app.
