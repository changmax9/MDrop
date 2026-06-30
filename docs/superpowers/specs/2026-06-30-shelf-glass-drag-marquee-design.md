# MDrop Shelf Glass, Drag, and Marquee Design

## Goal

Match the supplied Dropover reference for compact Shelf glass, movement, handle
motion, filename behavior, center-origin entrance, compact-to-detail morph, and
adaptive light/dark controls without regressing file drag-out.

## Surface

- Keep the compact Shelf at 198 × 207 pt with a 28 pt continuous corner radius.
- Use the macOS 26 clear Liquid Glass variant so the surface visibly samples,
  refracts, and colors itself from content behind the Shelf.
- Preserve a thin adaptive outline and a rounded alpha-derived shadow. No
  rectangular window background, key-window highlight, or rectangular shadow
  may appear before, during, or after clicking.
- Keep related glass elements in the existing `GlassEffectContainer`.

## Adaptive Controls

- Close and actions controls remain 32 × 32 pt circles with centers 23 pt from
  the top and side edges.
- Hover changes only the button shadow; it never changes button scale or frame.
- Light mode uses a dark icon and a subtle dark translucent circle.
- Dark mode follows the supplied reference: near-white icon, translucent
  charcoal circle, faint white outline, and a soft black hover shadow.
- The bottom filename capsule uses adaptive foreground and glass treatment so
  it remains readable in both appearances.

## Shelf Movement

- The Shelf moves from any non-interactive background region, not only from the
  top handle.
- The close button, actions button, filename/detail button, and file thumbnail
  remain excluded from window movement.
- Dragging the thumbnail continues to export the real file to Finder and never
  moves the Shelf or re-ingests the file.
- A small AppKit bridge provides a full-panel drag surface with interactive
  exclusions and reports hover/drag state to SwiftUI. SwiftUI remains the
  source of visual state.

## Handle Motion

- The top handle is hidden while the pointer is outside the Shelf.
- Hovering anywhere over the Shelf reveals a 20 × 4 pt handle.
- Moving the Shelf stretches the handle to 36 × 4 pt.
- Visibility and width use the existing reduced-motion policy; otherwise they
  transition with a short, damped spring.
- Releasing the Shelf returns the handle to 20 pt while still hovered, then
  fades it out when the pointer leaves.

## Filename Marquee

- Names that fit remain centered and stationary.
- Overflowing names display from the leading edge without middle truncation.
- After a 0.7 second pause, the text moves left at 24 pt/s, pauses
  at the trailing edge, then returns and repeats.
- The chevron stays fixed; only the filename text moves inside a clipped region.
- Reduce Motion disables continuous travel and falls back to middle truncation.

## Jelly Glass Entrance

- A Shelf created by shake activation starts as a small, translucent glass blob
  at the final Shelf center. The panel frame is already at its final size, so
  the animation does not visibly jump or move the center.
- The blob begins at 18% horizontal scale, 12% vertical scale, 0 opacity, and a
  44 pt corner radius. Its content remains hidden during the first expansion.
- The glass surface expands with separate axes: horizontal scale reaches its
  target slightly before vertical scale, vertical scale overshoots to 104%, and
  both settle at 100%. This reproduces the soft jelly stretch visible in the
  first supplied recording without distorting the file thumbnail.
- The surface animation takes 420 ms using a highly responsive, damped spring.
  Controls and item content fade and scale from 96% beginning
  90 ms after the surface starts, then settle without a second bounce.
- Newly created shelves use this entrance. Shelves restored when MDrop launches
  appear immediately so relaunching never produces a burst of animations.
- Reduce Motion replaces the jelly expansion with a 160 ms opacity transition.

## Compact-to-Detail Morph

- Pressing the bottom filename capsule changes the same Shelf from the
  198 × 207 pt compact card into a 430 × 180 pt horizontal detail card. The
  card remains centered on its previous center while the panel frame and clear
  glass mask animate together.
- The compact thumbnail, top controls, and filename capsule fade to 0 in the
  first 110 ms. The surface expands horizontally and contracts vertically with
  a 360 ms damped spring; no second window or rectangular backing may flash.
- Detail content fades in after 120 ms. It matches the second supplied
  recording: a circular back control and “1 Document”/size summary at top left,
  view/customize controls at top right, the file item below, and a
  “Reveal in Finder” action beside it.
- The back control performs the inverse morph and restores the compact layout,
  including the previous item stack and filename marquee state.
- File count, size summary, title pluralization, and item rendering are driven
  by the live Shelf model. There is no Pro badge, trial timer, or gated state.
- Reduce Motion changes the panel size without overshoot and crossfades the two
  layouts in 160 ms.

## Validation

- Unit-test marquee overflow distance, travel duration, and no-overflow behavior.
- Verify light and dark appearances on a real macOS 26 desktop.
- Compare hover and dragging handle widths against the reference frames.
- Drag a temporary file from the Shelf to a Finder folder and confirm the Shelf
  frame is unchanged and no duplicate item is added.
- Drag the Shelf from multiple blank regions and confirm buttons, filename, and
  thumbnail keep their original interactions.
- Trigger a new Shelf by shaking a dragged file and compare center anchoring,
  horizontal/vertical expansion order, overshoot, and content delay against the
  first supplied recording.
- Press the filename capsule and back control repeatedly and confirm the panel
  stays center-anchored, the compact and detail layouts never overlap at full
  opacity, and Finder drag-out still works in both layouts.
- Click the final Release Shelf and confirm no rectangular background appears.
