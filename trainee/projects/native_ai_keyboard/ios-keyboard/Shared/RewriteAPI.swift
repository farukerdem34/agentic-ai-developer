import Foundation
import UIKit

enum RewriteMode: String, Encodable {
    case proofread
    case rewrite
    case shorten
    case expand
}

enum RewriteAPIError: Error {
    case noToken
    case badStatus(Int, String?)
}

extension RewriteAPIError: LocalizedError {
    var errorDescription: String? { localizedMessage }
}

enum RewriteAPI {
    private struct ErrorEnvelope: Decodable {
        struct Err: Decodable {
            let code: String?
            let message: String?
        }

        let error: Err?
    }

    private static func userFacingServerMessage(status: Int, data: Data) -> String {
        if let env = try? JSONDecoder().decode(ErrorEnvelope.self, from: data), let e = env.error {
            switch e.code {
            case "gemini_not_configured":
                return KeyboardExtensionL10n.string("keyboard.error.gemini_not_configured")
            case "gemini_auth":
                return KeyboardExtensionL10n.string("keyboard.error.gemini_auth")
            case "gemini_rate_limited":
                return KeyboardExtensionL10n.string("keyboard.error.gemini_rate_limited")
            case "gemini_quota":
                return KeyboardExtensionL10n.string("keyboard.error.gemini_quota")
            case "gemini_model":
                return KeyboardExtensionL10n.string("keyboard.error.gemini_model")
            case "gemini_bad_request", "gemini_upstream", "gemini_connection":
                if let m = e.message, !m.isEmpty {
                    return String(format: KeyboardExtensionL10n.string("keyboard.error.gemini_detail"), m)
                }
                return KeyboardExtensionL10n.string("keyboard.error.gemini_failed")
            case "UNAUTHORIZED", "invalid_token":
                return KeyboardExtensionL10n.string("keyboard.error.unauthorized")
            case "payment_required":
                return KeyboardExtensionL10n.string("keyboard.error.payment_required")
            default:
                if let m = e.message, !m.isEmpty {
                    return String(format: KeyboardExtensionL10n.string("keyboard.error.server_with_message"), status, m)
                }
            }
        }
        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            return String(format: KeyboardExtensionL10n.string("keyboard.error.server_with_message"), status, raw)
        }
        return String(format: KeyboardExtensionL10n.string("keyboard.error.server_status"), status)
    }

    private static func apiMode(for style: ConversationStyle) -> String {
        switch style {
        case .formal, .work: return "work"
        case .friends: return "friends"
        case .family: return "family"
        case .flirt: return "flirt"
        }
    }

    private static func mapAction(_ mode: RewriteMode) -> String? {
        switch mode {
        case .proofread: return "correct"
        case .rewrite: return "rewrite"
        case .shorten: return "shorten"
        case .expand: return "expand"
        }
    }

    private static func supabaseTransform(
        text: String,
        mode: RewriteMode,
        style: ConversationStyle,
    ) async throws -> String {
        try await SupabaseDeviceAPI.registerIfNeeded()
        guard let url = AppConfig.supabaseTransformURL() else {
            throw RewriteAPIError.badStatus(-1, KeyboardExtensionL10n.string("keyboard.error.supabase_url_missing"))
        }
        guard let bearer = AppGroupStore.shared.deviceTransformToken, !bearer.isEmpty else {
            throw RewriteAPIError.noToken
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 180

        AIWritingLocale.syncFromDevice()
        let keyboardLocale = AIWritingLocale.preferredIdentifier()
        let deviceLocales = AIWritingLocale.deviceLocalesHint()
        let themeRaw = AppGroupStore.shared.keyboardAppearancePreference.rawValue

        struct Body: Encodable {
            let text: String
            let mode: String
            let action: String
            let locale: String
            let theme: String
            let style: String
            let deviceLocales: String
        }

        guard let action = mapAction(mode) else {
            throw RewriteAPIError.badStatus(-1, KeyboardExtensionL10n.string("keyboard.error.unsupported_mode"))
        }

        let body = Body(
            text: text,
            mode: apiMode(for: style),
            action: action,
            locale: keyboardLocale,
            theme: themeRaw,
            style: style.rawValue,
            deviceLocales: deviceLocales,
        )
        req.httpBody = try JSONEncoder().encode(body)

        KeyboardExtensionDiagnostics.logSync("rewrite POST host=\(url.host ?? "?") locale=\(keyboardLocale)")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw RewriteAPIError.badStatus(-1, nil) }
        guard (200 ... 299).contains(http.statusCode) else {
            let msg = Self.userFacingServerMessage(status: http.statusCode, data: data)
            throw RewriteAPIError.badStatus(http.statusCode, msg)
        }
        struct Out: Decodable {
            let result: String
        }
        let out = try JSONDecoder().decode(Out.self, from: data)
        return out.result
    }

    private static func legacyNodeRewrite(
        text: String,
        mode: RewriteMode,
        style: ConversationStyle,
    ) async throws -> String {
        let token = AppGroupStore.shared.sessionToken ?? ""
        if !AppConfig.devSessionBypass && token.isEmpty {
            throw RewriteAPIError.noToken
        }
        let rewriteURL = AppConfig.apiOriginURL.appendingPathComponent("v1").appendingPathComponent("rewrite")
        var req = URLRequest(url: rewriteURL)
        req.httpMethod = "POST"
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if AppConfig.devSessionBypass {
            req.setValue(DeviceId.idfv, forHTTPHeaderField: "X-Device-Id")
        }
        let langs = AIWritingLocale.deviceLocalesHint()
        if !langs.isEmpty {
            req.setValue(langs, forHTTPHeaderField: "Accept-Language")
        }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 180

        struct Body: Encodable {
            let text: String
            let mode: String
            let style: String
        }
        let body = Body(text: text, mode: mode.rawValue, style: style.rawValue)
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw RewriteAPIError.badStatus(-1, nil) }
        guard (200 ... 299).contains(http.statusCode) else {
            let msg = Self.userFacingServerMessage(status: http.statusCode, data: data)
            throw RewriteAPIError.badStatus(http.statusCode, msg)
        }
        struct Out: Decodable {
            let text: String
        }
        let out = try JSONDecoder().decode(Out.self, from: data)
        return out.text
    }

    private static func mapConnectionError(_ error: Error) -> Error {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain || error is URLError {
            let code = URLError.Code(rawValue: ns.code)
            let host = AppConfig.supabaseTransformURL()?.host ?? AppConfig.normalizedSupabaseProjectURLString() ?? "?"
            if code == .cannotFindHost || code == .dnsLookupFailed {
                return RewriteAPIError.badStatus(
                    -1,
                    String(format: KeyboardExtensionL10n.string("keyboard.error.host_not_found_named"), host)
                )
            }
            if AppConfig.normalizedSupabaseProjectURLString() == nil {
                return RewriteAPIError.badStatus(-1, KeyboardExtensionL10n.string("keyboard.error.supabase_url_missing"))
            }
            if AppConfig.usesSupabaseTransform {
                return RewriteAPIError.badStatus(
                    -1,
                    String(format: KeyboardExtensionL10n.string("keyboard.error.network_named"), host)
                )
            }
            return RewriteAPIError.badStatus(-1, KeyboardExtensionL10n.string("keyboard.error.network_legacy"))
        }
        return error
    }

    static func rewrite(text: String, mode: RewriteMode, style: ConversationStyle) async throws -> String {
        do {
            if AppConfig.usesSupabaseTransform {
                return try await supabaseTransform(text: text, mode: mode, style: style)
            }
            return try await legacyNodeRewrite(text: text, mode: mode, style: style)
        } catch let rewrite as RewriteAPIError {
            NonFatalLog.record(rewrite, category: "rewrite_api")
            throw rewrite
        } catch {
            NonFatalLog.record(error, category: "rewrite_api")
            throw mapConnectionError(error)
        }
    }
}
