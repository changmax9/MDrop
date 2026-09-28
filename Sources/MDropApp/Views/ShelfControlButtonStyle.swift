import SwiftUI

/// Native button actions with Nexora's small, interruptible hover/press spring.
/// The layout and hit area stay still while only the visible label moves.
struct ShelfControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ShelfControlButtonBody(label: configuration.label, isPressed: configuration.isPressed)
    }
}

private struct ShelfControlButtonBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(AppPreferences.reduceMotionKey) private var reduceShelfMotion = false

    private var reduceMotion: Bool { systemReduceMotion || reduceShelfMotion }

    var body: some View {
        label
            .scaleEffect(reduceMotion || !isEnabled ? 1 : isPressed ? 0.955 : isHovered ? 1.025 : 1)
            .offset(y: isHovered && !isPressed && !reduceMotion && isEnabled ? -0.75 : 0)
            .brightness(isHovered && isEnabled ? 0.025 : 0)
            .opacity(isEnabled ? (isPressed ? 0.86 : 1) : 0.45)
            .animation(reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.26, dampingFraction: 0.78), value: isPressed)
            .animation(reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.28, dampingFraction: 0.84), value: isHovered)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

/// One native glass layer per control, with an opaque accessibility fallback.
struct ShelfGlassSurface<S: Shape>: ViewModifier {
    let shape: S
    var interactive = false
    var clear = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @AppStorage(AppPreferences.reduceMotionKey) private var reduceShelfMotion = false

    func body(content: Content) -> some View {
        Group {
            if reduceTransparency {
                content.background(Color(nsColor: .windowBackgroundColor), in: shape)
            } else {
                content.glassEffect(
                    (clear ? Glass.clear : Glass.regular).interactive(interactive && !systemReduceMotion && !reduceShelfMotion),
                    in: shape
                )
            }
        }
        .overlay {
            if contrast == .increased || reduceTransparency {
                shape.stroke(Color.primary.opacity(0.35), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }
}

