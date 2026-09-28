import CoreGraphics
import Foundation

public enum ShelfResizeAxisAnchor: Equatable, Sendable {
    case minimum
    case center
    case maximum
}

public struct ShelfResizeAnchor: Equatable, Sendable {
    public let horizontal: ShelfResizeAxisAnchor
    public let vertical: ShelfResizeAxisAnchor

    public init(
        horizontal: ShelfResizeAxisAnchor,
        vertical: ShelfResizeAxisAnchor
    ) {
        self.horizontal = horizontal
        self.vertical = vertical
    }
}

public enum ShelfPanelGeometry {
    public static func draggedOrigin(
        from startingWindowOrigin: CGPoint,
        pointerStart: CGPoint,
        pointerCurrent: CGPoint
    ) -> CGPoint {
        CGPoint(
            x: startingWindowOrigin.x
                + pointerCurrent.x
                - pointerStart.x,
            y: startingWindowOrigin.y
                + pointerCurrent.y
                - pointerStart.y
        )
    }

    public static func centeredFrame(
        from currentFrame: CGRect,
        to size: CGSize,
        constrainedTo visibleFrame: CGRect? = nil
    ) -> CGRect {
        var result = CGRect(
            x: currentFrame.midX - size.width / 2,
            y: currentFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )

        guard let visibleFrame else { return result }
        result.origin.x = constrainedOrigin(
            proposed: result.minX,
            size: result.width,
            minimum: visibleFrame.minX,
            maximum: visibleFrame.maxX
        )
        result.origin.y = constrainedOrigin(
            proposed: result.minY,
            size: result.height,
            minimum: visibleFrame.minY,
            maximum: visibleFrame.maxY
        )
        return result
    }

    public static func dockedFrame(
        from currentFrame: CGRect,
        to size: CGSize,
        edge: DockedEdge,
        constrainedTo visibleFrame: CGRect
    ) -> CGRect {
        let proposedX = edge == .left
            ? visibleFrame.minX
            : visibleFrame.maxX - size.width
        return CGRect(
            x: constrainedOrigin(
                proposed: proposedX,
                size: size.width,
                minimum: visibleFrame.minX,
                maximum: visibleFrame.maxX
            ),
            y: constrainedOrigin(
                proposed: currentFrame.minY,
                size: size.height,
                minimum: visibleFrame.minY,
                maximum: visibleFrame.maxY
            ),
            width: size.width,
            height: size.height
        )
    }

    public static func resizeAnchor(
        from sourceFrame: CGRect,
        to targetFrame: CGRect,
        centerTolerance: CGFloat = 5
    ) -> ShelfResizeAnchor {
        ShelfResizeAnchor(
            horizontal: axisAnchor(
                sourceCenter: sourceFrame.midX,
                targetCenter: targetFrame.midX,
                tolerance: centerTolerance
            ),
            vertical: axisAnchor(
                sourceCenter: sourceFrame.midY,
                targetCenter: targetFrame.midY,
                tolerance: centerTolerance
            )
        )
    }

    private static func axisAnchor(
        sourceCenter: CGFloat,
        targetCenter: CGFloat,
        tolerance: CGFloat
    ) -> ShelfResizeAxisAnchor {
        let delta = targetCenter - sourceCenter
        if abs(delta) <= max(0, tolerance) {
            return .center
        }
        return delta < 0 ? .minimum : .maximum
    }

    private static func constrainedOrigin(
        proposed: CGFloat,
        size: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        guard size <= maximum - minimum else { return minimum }
        return min(max(proposed, minimum), maximum - size)
    }
}
