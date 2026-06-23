import Foundation

/// Device vs typing locale — UI strings follow the **primary** system language.
enum KeyboardLocalePolicy {
    /// First language in Settings → General → Language & Region (device UI language).
    static func uiStringsLanguageCode(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        guard let first = preferredLanguages.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !first.isEmpty
        else { return "en" }
        let base = first.split(separator: "-").first.map(String.init)?.lowercased() ?? first.lowercased()
        switch base {
        case "tr": return "tr"
        case "de": return "de"
        case "fr": return "fr"
        case "es": return "es"
        default: return "en"
        }
    }
}
