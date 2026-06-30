import AppKit
import MDropCore
import SwiftUI

struct ShelfMarqueeText: View {
    let text: String

    @AppStorage("reduceShelfMotion") private var reduceShelfMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    var body: some View {
        Group {
            if reduceMotion {
                Text(text)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                ZStack(alignment: alignment) {
                    Text(text)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: offset)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.width
                        } action: { width in
                            textWidth = width
                        }
                }
                .frame(maxWidth: .infinity)
                .clipped()
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { width in
                    viewportWidth = width
                }
                .task(id: animationID) {
                    await runMarquee()
                }
            }
        }
        .font(.system(size: 13, weight: .regular))
        .accessibilityLabel(text)
    }

    private var metrics: ShelfMarqueeMetrics {
        ShelfMarqueeMetrics.measure(
            textWidth: textWidth,
            viewportWidth: viewportWidth,
            pointsPerSecond:
                ShelfMotionProfile.reference.marqueePointsPerSecond
        )
    }

    private var alignment: Alignment {
        metrics.travelDistance > 0 ? .leading : .center
    }

    private var animationID: MarqueeAnimationID {
        MarqueeAnimationID(
            text: text,
            textWidth: textWidth,
            viewportWidth: viewportWidth,
            reduceMotion: reduceMotion
        )
    }

    @MainActor
    private func runMarquee() async {
        offset = 0
        let distance = CGFloat(metrics.travelDistance)
        let duration = metrics.travelDuration
        guard distance > 0, duration > 0 else { return }

        while !Task.isCancelled {
            guard await sleep(
                seconds:
                    ShelfMotionProfile.reference.marqueeInitialDelay
            ) else { return }
            withAnimation(.linear(duration: duration)) {
                offset = -distance
            }
            guard await sleep(
                seconds:
                    duration
                    + ShelfMotionProfile.reference.marqueeInitialDelay
            ) else { return }
            withAnimation(.linear(duration: duration)) {
                offset = 0
            }
            guard await sleep(seconds: duration) else { return }
        }
    }

    private func sleep(seconds: Double) async -> Bool {
        do {
            try await Task.sleep(
                for: .seconds(seconds)
            )
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    private var reduceMotion: Bool {
        reduceShelfMotion
            || systemReduceMotion
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

private struct MarqueeAnimationID: Equatable {
    let text: String
    let textWidth: CGFloat
    let viewportWidth: CGFloat
    let reduceMotion: Bool
}
