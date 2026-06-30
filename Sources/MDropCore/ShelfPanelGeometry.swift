import CoreGraphics
import Foundation

public enum ShelfPanelGeometry {
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
