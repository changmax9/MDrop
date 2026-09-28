import Foundation

@MainActor
enum AppServices {
    static var coordinator: ShelfCoordinator?
    static var openSettings: (() -> Void)?
}
