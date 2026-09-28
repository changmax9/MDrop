import Observation
import ServiceManagement

@MainActor
protocol LoginItemService: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

@MainActor
@Observable
final class LaunchAtLoginSettings {
    @ObservationIgnored
    private let service: any LoginItemService

    private(set) var isEnabled: Bool
    var errorMessage: String?

    init(
        service: any LoginItemService = SMAppService.mainApp
    ) {
        self.service = service
        isEnabled = service.status == .enabled
    }

    func refresh() {
        isEnabled = service.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }
}
