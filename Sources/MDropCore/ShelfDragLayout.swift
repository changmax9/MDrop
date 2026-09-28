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
                x: 14,
                y: panelSize.height - 46,
                width: 32,
                height: 32
            ),
            CGRect(
                x: panelSize.width - 46,
                y: panelSize.height - 46,
                width: 32,
                height: 32
            ),
            CGRect(x: 48, y: 45, width: 102, height: 118),
            CGRect(x: panelSize.width / 2 - 54, y: 10, width: 108, height: 37)
        ])
    }

    public static func empty(panelSize: CGSize) -> Self {
        Self(interactiveRegions: [
            CGRect(
                x: 14,
                y: panelSize.height - 46,
                width: 32,
                height: 32
            )
        ])
    }

    public static func detail(panelSize: CGSize) -> Self {
        Self(interactiveRegions: [
            CGRect(
                x: 8,
                y: panelSize.height - 54,
                width: 48,
                height: 40
            ),
            CGRect(
                x: panelSize.width - 120,
                y: panelSize.height - 54,
                width: 112,
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
