# MDrop Dropover-Style Compact Shelf Design

## Goal

Replace MDrop's current horizontal compact Shelf with the compact vertical
presentation shown in the supplied screenshots and screen recording. Preserve
MDrop branding, native Liquid Glass, local-only behavior, shake activation,
drag-and-drop, accessibility, and the existing action engine.

## Presentation States

### Empty drop target

- Keep the existing 396×414 shake-created drop target.
- Use the same dark blue-black glass treatment as the populated Shelf.
- Keep the centered “Drop files here” label, top drag handle, close button, and
  actions/menu button.
- Dropping the first item morphs the panel into the compact populated size.

### Compact populated Shelf

- Target content size: 166×164 points, with the existing outer glass padding.
- Top chrome:
  - circular close button at top-left;
  - short drag handle centered at the top;
  - circular chevron-down menu button at top-right.
- Center content:
  - one item: one large Quick Look thumbnail;
  - multiple items: up to three thumbnails in the same location, with the rear
    cards offset and rotated approximately -7° and +6°;
  - folders use their native Finder icon and participate in the same stack.
- Bottom:
  - a glass capsule containing the truncated filename for one item;
  - a localized count/type label such as “3 Documents” or “4 Items” for
    multiple items;
  - a trailing chevron opens the existing detail presentation.
- Adding or removing items animates the stack, count, and panel size with a
  spring. Reduce Motion replaces the spring with a short fade.

### Detail and docked states

- Retain the existing detail list, Command Bar, actions, and edge-docked state.
- The compact bottom capsule transitions into the detail header using the
  existing stable Shelf identity.

## Visual Treatment

- Force the floating Shelf itself into a dark appearance to match the reference;
  settings continue following the system appearance.
- Use native `GlassEffectContainer`, interactive `glassEffect`, glass buttons,
  and semantic foreground styles.
- Apply one restrained blue-black glass tint, a thin cool highlight, and the
  system glass shadow. Avoid opaque custom backgrounds.
- Keep the outer corner radius near 30 points for the compact Shelf and 44
  points for the large empty target.

## Thumbnails

- Add a reusable asynchronous thumbnail view backed by
  `QLThumbnailGenerator`.
- Request a representation sized for the current backing scale.
- Show the Finder icon immediately, then crossfade to the generated thumbnail.
- Cache thumbnails by standardized URL, modification date, and requested size.
- Missing files show the current warning icon and remain removable.

## Shelf Menu

The top-right chevron and right-clicking the Shelf expose the same native menu:

1. Open With
2. Show in Finder
3. Quick Look
4. System sharing services, including AirDrop, Mail, Messages, and Notes when
   macOS reports them available
5. Add From Clipboard
6. Copy selected item(s)
7. Copy to…
8. Move to…
9. All Actions
10. Clear Shelf
11. Dock to Edge
12. Pin or Unpin
13. Customize / Settings

Cloud links, accounts, upgrade prompts, Share Extension, Widget, and Control
Center controls remain excluded.

## Window Sizing and Interaction

- Panel sizing becomes content-aware:
  - empty: 396×414;
  - populated compact: 166×164;
  - detail and docked retain their current sizes.
- Resize from empty to compact while keeping the panel’s top edge visually
  anchored.
- The top-center handle remains a reliable window drag region.
- Dragging files out, dropping additional files in, keyboard shortcuts, Quick
  Look, multi-screen placement, and all-Spaces behavior remain unchanged.

## Accessibility

- Close and menu buttons have explicit labels and 30-point hit targets.
- The stack announces item count and the front item name.
- Full Keyboard Access can reach close, menu, filename/detail, and action
  controls.
- High contrast strengthens the border and foreground rather than replacing
  native glass.
- Reduce Motion removes rotation/spring transitions while preserving state
  changes.

## Verification

- Unit-test content-aware presentation sizing, stack transforms, count labels,
  and thumbnail cache keys.
- Run the existing full SwiftPM and Xcode test suites.
- Use the drag harness and Finder to verify:
  - shake to empty target;
  - first drop morphs into compact vertical Shelf;
  - second and third drops form a rotated stack;
  - menu actions, Quick Look, drag-out, clear, and close work;
  - light/dark desktop backgrounds, Reduce Motion, and multiple Spaces.
- Rebuild and verify the ad-hoc signed `.app`, `.dmg`, and SHA-256.
