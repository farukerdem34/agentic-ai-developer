import Foundation

/// Host-app view of keyboard + Full Access readiness (extension writes, host reads).
struct KeyboardSetupStatus: Equatable {
    let appGroupAvailable: Bool
    let keyboardDetected: Bool
    let fullAccessState: KeyboardFullAccessState

    var fullAccessOn: Bool { fullAccessState.isEnabled }

    var isReady: Bool {
        appGroupAvailable && keyboardDetected && fullAccessOn
    }

    /// Host should block until Full Access is confirmed once the keyboard has been used at least once.
    var needsFullAccessGate: Bool {
        appGroupAvailable && keyboardDetected && fullAccessState != .enabled
    }

    static func resolve(from store: AppGroupStore = .shared) -> KeyboardSetupStatus {
        KeyboardSetupStatus(
            appGroupAvailable: store.isSharedContainerAvailable,
            keyboardDetected: store.keyboardHasBeenUsed,
            fullAccessState: KeyboardFullAccessState.resolve(from: store)
        )
    }
}
