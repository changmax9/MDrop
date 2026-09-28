import MDropCore
import SwiftUI

struct ShelfDropFeedbackView: View {
    @Bindable var store: ShelfStore
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(AppPreferences.reduceMotionKey) private var reduceShelfMotion = false

    private var isActive: Bool { store.isReceivingDrop || store.isImporting }
    private var reduceMotion: Bool { systemReduceMotion || reduceShelfMotion }

    var body: some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: max(8, cornerRadius - 6), style: .continuous)
                    .fill(Color.accentColor.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: max(8, cornerRadius - 6), style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.58), style: StrokeStyle(lineWidth: 1.5, dash: store.isImporting ? [] : [6, 4]))
                    }
                    .padding(6)

                VStack(spacing: 7) {
                    if store.isImporting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 23, weight: .medium))
                            .foregroundStyle(.tint)
                            .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : store.isReceivingDrop)
                    }
                    Text(store.isImporting ? AppLocalization.string("Adding items…") : AppLocalization.string("Release to add"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                    if !store.isImporting, store.targetedItemCount > 1 {
                        Text(AppLocalization.format("%lld Items", Int64(store.targetedItemCount)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)))
            } else if let receipt = store.dropReceipt {
                VStack {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(AppLocalization.format("Added %lld", Int64(receipt.count)))
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .modifier(ShelfGlassSurface(shape: Capsule()))
                    .padding(.horizontal, 8)
                    .padding(.top, store.shelf.presentationState == .detail ? 44 : 8)
                    Spacer(minLength: 0)
                }
                .id(receipt.id)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.3, dampingFraction: 0.84), value: isActive)
        .animation(.easeOut(duration: 0.18), value: store.dropReceipt)
        .accessibilityElement(children: .combine)
    }
}
