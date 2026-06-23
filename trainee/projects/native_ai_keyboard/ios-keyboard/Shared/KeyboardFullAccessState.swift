import Foundation

/// Host-app view of Full Access as reported by the keyboard extension (never read from iOS Settings directly).
enum KeyboardFullAccessState: Equatable {
    case unknown
    case enabled
    case disabled

    static func resolve(from store: AppGroupStore = .shared) -> KeyboardFullAccessState {
        guard store.isSharedContainerAvailable else { return .unknown }
        guard store.keyboardHasBeenUsed else { return .unknown }
        return store.keyboardReportsFullAccess ? .enabled : .disabled
    }

    var isEnabled: Bool {
        if case .enabled = self { return true }
        return false
    }
}

enum KeyboardExtensionFullAccess {
    /// `UIInputViewController.hasFullAccess` can briefly read `false` after keyboard switch even when enabled.
    static func allowsNetwork(for controllerHasFullAccess: Bool, store: AppGroupStore = .shared) -> Bool {
        if controllerHasFullAccess { return true }
        guard let report = store.resolvedKeyboardAccessReport(), report.hasFullAccess else { return false }
        let age = Date().timeIntervalSince1970 - report.lastSeenAt
        return age < 300
    }
}
