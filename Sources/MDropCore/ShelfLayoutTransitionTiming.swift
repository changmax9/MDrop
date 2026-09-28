import Foundation

public struct ShelfLayoutTransitionTiming: Equatable, Sendable {
    public let frameDuration: TimeInterval
    public let contentFadeDuration: TimeInterval
    public let contentSwapDelay: TimeInterval
    public let completionDelay: TimeInterval

    public init(
        frameDuration: TimeInterval,
        contentFadeDuration: TimeInterval,
        contentSwapDelay: TimeInterval,
        completionDelay: TimeInterval
    ) {
        self.frameDuration = frameDuration
        self.contentFadeDuration = contentFadeDuration
        self.contentSwapDelay = contentSwapDelay
        self.completionDelay = completionDelay
    }

    public static func resolve(
        profile: ShelfMotionProfile,
        reduceMotion: Bool,
        frameDuration: TimeInterval? = nil
    ) -> Self {
        guard reduceMotion else {
            let resolvedFrameDuration = frameDuration
                ?? profile.frameMorphDuration
            return Self(
                frameDuration: resolvedFrameDuration,
                contentFadeDuration: profile.layoutFadeDuration,
                contentSwapDelay: profile.layoutFadeDuration,
                completionDelay: resolvedFrameDuration
            )
        }

        let halfCrossfade = profile.reducedMotionDuration / 2
        return Self(
            frameDuration: 0,
            contentFadeDuration: halfCrossfade,
            contentSwapDelay: halfCrossfade,
            completionDelay: profile.reducedMotionDuration
        )
    }

    public func delayingContentSwapUntilFrameSettles() -> Self {
        Self(
            frameDuration: frameDuration,
            contentFadeDuration: contentFadeDuration,
            contentSwapDelay: max(
                contentSwapDelay,
                completionDelay - contentFadeDuration
            ),
            completionDelay: completionDelay
        )
    }
}
