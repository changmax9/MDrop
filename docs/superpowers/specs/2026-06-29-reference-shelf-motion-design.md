# Reference Shelf Motion Design

## Goal

Match the supplied 29 June screen recording for the shake-created empty Shelf,
then preserve the existing compact stacked-file presentation after a drop.
MDrop remains a permanently complete local app with no Pro tier, trial,
countdown, upgrade prompt, or feature gating.

## Measured Reference Geometry

The source recording is 4096×2702 Retina pixels. A stable empty Shelf occupies
approximately 725×758 pixels, or 362×379 points at 2× scale.

MDrop keeps its existing 10-point transparent perimeter for shadows, so the
empty panel becomes 382×400 points. The visible glass body is therefore
approximately 362×380 points. The empty glass corner radius becomes 36 points,
and the centered label uses a 15-point rounded medium font.

The populated compact panel remains 166×164 points because the earlier supplied
compact references already establish that size.

## Motion

### Shake appearance

The reference Shelf is absent at 1.303 seconds and fully visible at 1.322
seconds. Geometry must therefore be final on the first presented frame. MDrop
must not animate the panel from a tiny rectangle or use a slow utility-window
zoom.

The content may use a restrained 80-millisecond opacity and scale settle
(0.985→1) to avoid a harsh flash, but the panel frame is final immediately.
Reduce Motion removes the scale settle and keeps only an immediate appearance.

### Drop morph

Dropping the first item keeps the panel top edge fixed while changing from
382×400 to 166×164 points. The frame uses a 220-millisecond ease-out animation.
The empty label fades before the compact thumbnail stack and filename capsule
appear. Thumbnail cards use the existing three-card transforms and a
280-millisecond snappy animation.

### Hover chrome

During an active drag, the empty target matches the clean reference surface:
only “Drop files here” is visible. During ordinary pointer hover, the requested
close control and top drag handle fade and scale in over 140 milliseconds.
They fade out when the pointer leaves.

### Close

Closing a Shelf fades its content over 100 milliseconds before the panel is
removed. Reduce Motion removes the scale component.

## Window Behavior

- Keep the non-activating `NSPanel`, all-Spaces and full-screen auxiliary
  behavior.
- Position the empty Shelf below the pointer using the final 382×400 frame.
- Keep the current multi-screen visible-frame clamping.
- Keep top-edge anchoring for compact/detail transitions.
- Do not let show/close animations steal focus from Finder or the drag source.

## Liquid Glass

Use the existing single `GlassEffectContainer`, stable `glassEffectID`, native
glass controls, and dark blue-black tint. No additional opaque animation layer
may replace the system glass. The visible body uses a 36-point corner radius in
the empty state.

## Free Edition Policy

MDrop exposes the same complete action set to every user. The product contains
no:

- Pro or premium tier;
- trial state or trial expiration;
- countdown;
- upgrade action;
- paid-only feature check;
- account requirement.

Developer ID signing or notarization is a distribution trust requirement only
and must never be described as a paid MDrop feature.

## Verification

- Unit-test empty panel metrics and reference motion timings.
- Verify the empty label typography and hover-chrome state in the real app.
- Use a Finder drag and shake to confirm final geometry appears immediately.
- Drop an item and confirm top-edge anchored morph to 166×164.
- Add two more files and confirm the three-card stack remains correct.
- Search shipping sources/resources for monetization UI terms.
- Run SwiftPM tests, Xcode tests, Release build, x86_64 compatibility build,
  ad-hoc signing validation, and DMG checksum validation.
