# MDrop Polish, Localization, Updates, and Release Design

## Goal

Ship MDrop 0.2.0 with the reference top-bar Liquid Glass animation, a polished
settings window, complete runtime localization in eight languages, a Folded M
application and menu-bar identity, Sparkle updates, regression coverage, and a
GitHub DMG release.

## Reference Interaction

The supplied 6.738-second, 230 × 110, 120 fps recording is the source of truth
for the detail view's grid/list control.

- The control remains a single glass capsule with two equal hit targets.
- The selected item has a persistent rounded glass lens.
- Hovering the other item creates a lighter transient glass lens without
  removing the selected lens.
- Clicking moves and morphs the selected lens across the capsule. The lens
  stretches slightly through the midpoint and settles without a hard crossfade.
- The implementation uses `GlassEffectContainer`, `glassEffect`,
  `glassEffectID`, and stable identities so the system performs the Liquid
  Glass morph.
- The hit targets, capsule frame, icons, and surrounding detail header geometry
  remain unchanged.
- Reduced Motion replaces the spring morph with a short opacity transition.
  Hover and selected-state contrast remain visible.

The options menu beside the mode picker retains its existing circular Liquid
Glass treatment and receives no unrelated geometry changes.

## Brand Identity

Use the approved Folded M mark:

- A dark rounded-square application icon contains a white folded M.
- A restrained cyan center stroke communicates the downward drop path.
- The application icon is rendered at all required macOS icon sizes from a
  deterministic vector master.
- The menu-bar item uses a one-color template version of the same geometry so
  macOS can adapt it to light, dark, selected, and increased-contrast states.
- The mark contains no text, gradients in the template asset, or fine detail
  that disappears at 16 points.

## Settings Structure

Keep the dedicated SwiftUI `Settings` scene and use a native
`NavigationSplitView`. The sidebar uses the system material and selection
treatment; it is not painted with an opaque custom background. Detail content
uses grouped forms and sparing Liquid Glass for branded or custom surfaces.

The existing settings are reorganized into seven stable sections:

1. General
2. Activation & Interaction
3. Actions & Automation
4. Shortcuts & Integrations
5. Appearance
6. Privacy & Legal
7. About

General contains language, launch-at-login, Dock visibility, file-reference
behavior, default drag behavior, and detail auto-close. The remaining existing
preferences stay available in the closest matching section.

Privacy & Legal states that MDrop is local-first, has no account, cloud upload,
or telemetry, and stores references to original files. Its disclaimer explains
that move, delete, overwrite, script, and automation actions can change original
files; users should keep backups; and the software is provided as-is.

About contains the Folded M mark, version and build numbers, minimum macOS
version, a Check for Updates button, automatic-update preferences, the
application-support-folder action, and the GitHub project link.

The window remains 760 × 520 points. Long translations and legal text scroll
inside the detail column. Sidebar and detail content stay within safe bounds at
the minimum size, and popovers, sheets, menus, and scroll content never render
through adjacent panes.

## Runtime Localization

Support these explicit application languages:

- English (`en`)
- Simplified Chinese (`zh-Hans`)
- Traditional Chinese (`zh-Hant`)
- Japanese (`ja`)
- French (`fr`)
- Russian (`ru`)
- Spanish (`es`)
- Portuguese (`pt`)

An observable `AppLanguageController` owns the selected language and persists
its identifier in `UserDefaults`. It exposes the selected `Locale` and a
locale-aware string lookup.

SwiftUI roots receive the selected locale through the environment. This covers
the Settings scene, every floating Shelf, notch-drop UI, command bar, alerts,
menus hosted by SwiftUI, help text, and accessibility labels.

AppKit surfaces use the controller's explicit lookup instead of process-global
`String(localized:)`. When the language changes, the status menu is rebuilt and
visible Shelf roots are refreshed. No process restart is required.

Dynamic titles, counts, page labels, file-kind labels, error presentation, and
built-in action names use localized format keys rather than concatenated
English fragments.

The string catalog contains a value for every supported locale and every
user-facing key. Automated coverage verifies:

- every key has all eight localizations;
- no locale silently falls back to another non-English locale;
- representative labels differ where expected;
- plural and formatted values resolve with the requested locale;
- changing the controller updates both SwiftUI locale state and AppKit lookup.

## Sparkle Updates

Integrate Sparkle 2.9.2 through Swift Package Manager and use
`SPUStandardUpdaterController` with Sparkle's standard update UI.

- The app exposes Check for Updates in the menu-bar menu and About settings.
- The automatic-check and automatic-download controls bind directly to
  Sparkle's updater preferences; MDrop does not create duplicate defaults.
- The feed uses HTTPS and points to the repository's raw `appcast.xml`.
- `CFBundleVersion` increases monotonically and
  `CFBundleShortVersionString` is 0.2.0.
- The appcast points to the matching GitHub Release DMG, specifies macOS 26 as
  the minimum system version, and includes the archive length and Sparkle EdDSA
  signature.
- The public EdDSA key is embedded in the app. The private key remains in the
  local Keychain and is never committed.
- Sparkle.framework and its helpers are embedded and signed as nested code in
  both Xcode and SwiftPM fallback packaging paths.

MDrop currently has an Apple Development identity but no Developer ID
Application identity. Version 0.2.0 is therefore distributed as an ad-hoc
signed, unnotarized arm64 build with an explicit Gatekeeper note. Sparkle's
EdDSA signature still authenticates the update archive. A future Developer ID
identity can be added without changing the update UI or feed architecture.

## Bug Audit and Validation

The audit covers:

- baseline and focused unit tests;
- locale completeness and runtime switching;
- view-mode state transitions and hit targets;
- settings minimum-size layout, long translations, scroll boundaries, and
  light/dark appearances;
- menu rebuilds and update-action availability;
- Shelf create, compact/detail morph, grid/list switching, drag-out, Quick
  Look, close, Dock, and menu-bar activation;
- Sparkle configuration, embedded framework paths, appcast parsing, update
  signature, and release URL;
- app icon and menu-bar template rendering;
- full `swift test`, explicit `swift build`, Release bundle build, code-sign
  verification, app launch smoke test, DMG mount inspection, and SHA-256.

Any discovered defect receives a focused failing regression test before its
fix. Existing uncommitted Shelf motion and drag work in this worktree is
preserved and verified rather than overwritten.

## GitHub Release

Publish the complete current product to a public `changmax9/MDrop` repository.
Push the implementation branch as the repository's `main` branch, tag the
verified build `v0.2.0`, and create a non-draft GitHub Release containing:

- `MDrop-0.2.0-arm64.dmg`
- `MDrop-0.2.0-arm64.dmg.sha256`
- concise release notes and the unnotarized-build installation note

The DMG contains `MDrop.app`, an Applications shortcut, and a localized or
language-neutral README with the Gatekeeper instruction.
