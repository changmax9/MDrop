import CoreGraphics
import Foundation

public struct ShelfDragLayout: Equatable, Sendable {
    public let interactiveRegions: [CGRect]

    public init(interactiveRegions: [CGRect]) {
        self.interactiveRegions = interactiveRegions
    }

    public func isInteractive(_ point: CGPoint) -> Bool {
        interactiveRegions.contains { $0.contains(point) }
    }

    public static func compact(panelSize: CGSize) -> Self {
        Self(interactiveRegions: [
            CGRect(
                x: 7,
                y: panelSize.height - 39,
                width: 32,
                height: 32
            ),
            CGRect(
                x: panelSize.width - 39,
                y: panelSize.height - 39,
                width: 32,
                height: 32
            ),
            CGRect(x: 48, y: 45, width: 102, height: 118),
            CGRect(x: 32, y: 5, width: 134, height: 34)
        ])
    }

    public static func empty(panelSize: CGSize) -> Self {
        Self(interactiveRegions: [
            CGRect(
                x: 7,
                y: panelSize.height - 39,
                width: 32,
                height: 32
            )
        ])
    }

    public static func detail(panelSize: CGSize) -> Self {
        Self(interactiveRegions: [
            CGRect(
                x: 8,
                y: panelSize.height - 48,
                width: 48,
                height: 40
            ),
            CGRect(
                x: panelSize.width - 80,
                y: panelSize.height - 48,
                width: 72,
                height: 40
            ),
            CGRect(
                x: 8,
                y: 8,
                width: panelSize.width - 16,
                height: panelSize.height - 56
            )
        ])
    }

    public static func docked(panelSize: CGSize) -> Self {
        Self(interactiveRegions: [
            CGRect(
                x: 8,
                y: panelSize.height - 42,
                width: panelSize.width - 16,
                height: 34
            ),
            CGRect(
                x: 8,
                y: 8,
                width: panelSize.width - 16,
                height: panelSize.height - 58
            )
        ])
    }
}
