import Foundation

public struct ShakeDetector: Sendable {
    public struct Configuration: Sendable {
        public var timeWindow: TimeInterval
        public var minimumSegmentDistance: Double
        public var requiredReversals: Int
        public var cooldown: TimeInterval

        public init(
            timeWindow: TimeInterval = 0.6,
            minimumSegmentDistance: Double = 18,
            requiredReversals: Int = 3,
            cooldown: TimeInterval = 1.2
        ) {
            self.timeWindow = timeWindow
            self.minimumSegmentDistance = minimumSegmentDistance
            self.requiredReversals = requiredReversals
            self.cooldown = cooldown
        }
    }

    private let configuration: Configuration
    private var lastX: Double?
    private var lastDirection: Int?
    private var reversalTimes: [TimeInterval] = []
    private var lastTriggerTime: TimeInterval?

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    public mutating func record(x: Double, at time: TimeInterval) -> Bool {
        defer { lastX = x }
        guard let lastX else { return false }

        let delta = x - lastX
        guard abs(delta) >= configuration.minimumSegmentDistance else {
            return false
        }

        let direction = delta > 0 ? 1 : -1
        if let lastDirection, direction != lastDirection {
            reversalTimes.append(time)
        }
        lastDirection = direction
        reversalTimes.removeAll { time - $0 > configuration.timeWindow }

        guard reversalTimes.count >= configuration.requiredReversals else {
            return false
        }
        guard lastTriggerTime.map({ time - $0 >= configuration.cooldown }) ?? true else {
            return false
        }

        lastTriggerTime = time
        reversalTimes.removeAll()
        lastDirection = nil
        return true
    }

    public mutating func reset() {
        lastX = nil
        lastDirection = nil
        reversalTimes.removeAll()
        lastTriggerTime = nil
    }
}
