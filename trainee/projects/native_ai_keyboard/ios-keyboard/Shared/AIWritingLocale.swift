import Foundation

/// Device language for AI transform requests (keyboard + host stay aligned with iOS Language & Region).
enum AIWritingLocale {
    /// Short code sent to Edge `transform` (`tr`, `en`, …).
    static func preferredLanguageCode(store: AppGroupStore = .shared) -> String {
        if let custom = store.aiWritingLocaleIfSet, !custom.isEmpty { return custom }
        return KeyboardLocalePolicy.uiStringsLanguageCode()
    }

    /// BCP-47 tag for prompts (`tr-TR`, `en-US`, …).
    static func preferredIdentifier(store: AppGroupStore = .shared) -> String {
        if let first = Locale.preferredLanguages.first, !first.isEmpty { return first }
        let code = preferredLanguageCode(store: store)
        return Locale(identifier: code).identifier
    }

    static func deviceLocalesHint() -> String {
        Locale.preferredLanguages.prefix(4).joined(separator: ", ")
    }

    /// Host + keyboard call on launch / foreground so AI locale tracks the device.
    static func syncFromDevice(store: AppGroupStore = .shared) {
        store.updateAIWritingLocaleFromDevice()
    }
}
