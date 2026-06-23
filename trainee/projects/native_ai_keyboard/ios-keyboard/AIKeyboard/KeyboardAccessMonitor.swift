import SwiftUI
import UIKit

/// Single source of truth for keyboard + Full Access readiness in the host app.
@MainActor @Observable
final class KeyboardAccessMonitor {
    static let shared = KeyboardAccessMonitor()

    private(set) var status: KeyboardSetupStatus = .resolve()
    private var settingsObserver: AppGroupSettingsObserverToken?
    private var started = false

    var needsFullAccessGate: Bool { status.needsFullAccessGate }

    private init() {}

    func startIfNeeded() {
        guard !started else {
            refresh()
            return
        }
        started = true
        refresh()
        settingsObserver = AppGroupSettingsNotifier.observe { [weak self] in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh() {
        _ = AppGroupStore.shared.resolvedKeyboardAccessReport()
        status = KeyboardSetupStatus.resolve()
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    var fullAccessStatusKey: String {
        switch status.fullAccessState {
        case .unknown:
            return "settings.keyboard_setup.full_access_unknown"
        case .enabled:
            return "settings.keyboard_setup.full_access_on"
        case .disabled:
            return "settings.keyboard_setup.full_access_off"
        }
    }
}
