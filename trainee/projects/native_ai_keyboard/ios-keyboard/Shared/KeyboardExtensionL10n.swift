import Foundation

/// Localized strings for the keyboard extension + shared API errors (follows device language).
enum KeyboardExtensionL10n {
    private final class BundleAnchor {}

    static func string(_ key: String) -> String {
        let code = AppGroupStore.shared.keyboardChromeStringsLanguageCode
        let main = Bundle(for: BundleAnchor.self)
        if let path = main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path)
        {
            let value = NSLocalizedString(key, tableName: nil, bundle: bundle, value: "\u{1}", comment: "")
            if value != "\u{1}" { return value }
        }
        if let path = main.path(forResource: "en", ofType: "lproj"), let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        }
        return key
    }

    static func userFacingError(_ error: Error) -> String {
        if let rewrite = error as? RewriteAPIError {
            return rewrite.localizedMessage
        }
        if let reg = error as? SupabaseDeviceAPI.RegisterError {
            return reg.localizedMessage
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain || error is URLError {
            return string("keyboard.error.network")
        }
        let desc = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if desc.isEmpty { return string("keyboard.error.generic") }
        return desc
    }
}

extension RewriteAPIError {
    var localizedMessage: String {
        switch self {
        case .noToken:
            if AppConfig.usesSupabaseTransform {
                return KeyboardExtensionL10n.string("keyboard.error.no_device_token")
            }
            return KeyboardExtensionL10n.string("keyboard.error.no_session")
        case let .badStatus(code, body):
            if code == 404 {
                return KeyboardExtensionL10n.string("keyboard.error.api_not_found")
            }
            if code == -1, let body, !body.isEmpty { return body }
            if let body, !body.isEmpty { return body }
            return String(format: KeyboardExtensionL10n.string("keyboard.error.server_status"), code)
        }
    }
}

extension SupabaseDeviceAPI.RegisterError {
    var localizedMessage: String {
        switch self {
        case .missingSupabaseURL:
            return KeyboardExtensionL10n.string("keyboard.error.supabase_url_missing")
        case let .badResponse(code, body):
            if code == -1 {
                return KeyboardExtensionL10n.string("keyboard.error.network")
            }
            if let body, !body.isEmpty { return body }
            return String(format: KeyboardExtensionL10n.string("keyboard.error.register_failed"), code)
        }
    }
}
