import AppKit
import Testing
@testable import MDropApp

@MainActor
@Suite("Menu bar drop gate")
struct StatusDropReceiverViewTests {
    @Test("Disabled menu bar drops advertise no operation and skip pasteboard reads")
    func disabledDropGate() {
        let policy = StatusDropReceiverView.dropGatePolicy(isEnabled: false)

        #expect(policy.advertisedOperation.isEmpty)
        #expect(!policy.shouldReadPasteboard)
    }

    @Test("Enabled menu bar drops retain the copy operation and pasteboard handling")
    func enabledDropGate() {
        let policy = StatusDropReceiverView.dropGatePolicy(isEnabled: true)

        #expect(policy.advertisedOperation == .copy)
        #expect(policy.shouldReadPasteboard)
    }
}
