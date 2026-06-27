import Foundation

public struct InstantActionConfiguration: Codable, Equatable, Sendable {
    public static let maximumActionCount = 6
    public static let `default` = Self(actions: [
        .systemShare,
        .createArchive,
        .resizeImages,
        .extractText,
        .copyTo,
        .moveTo
    ])

    public var actions: [BuiltinActionID]

    public init(actions: [BuiltinActionID]) {
        var seen = Set<BuiltinActionID>()
        self.actions = Array(
            actions
                .filter { seen.insert($0).inserted }
                .prefix(Self.maximumActionCount)
        )
    }

    public func availableActions(
        for items: [ShelfItemRecord]
    ) -> [BuiltinActionID] {
        let available = BuiltinActionCatalog.availableActions(for: items)
        return actions.filter(available.contains)
    }
}
