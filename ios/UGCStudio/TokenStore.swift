import Foundation

/// UserDefaults-backed runtime token storage. Preferred source for API keys
/// because Rork's build pipeline regenerates Config.swift and would wipe any
/// custom getters/setters added there.
enum TokenStore {
    private static let apifyKey = "ugc.config.apifyToken"
    private static let openAIKey = "ugc.config.openAIToken"

    static var apifyToken: String {
        UserDefaults.standard.string(forKey: apifyKey) ?? ""
    }

    static var openAIToken: String {
        UserDefaults.standard.string(forKey: openAIKey) ?? ""
    }

    static func setApifyToken(_ value: String) {
        UserDefaults.standard.set(
            value.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: apifyKey
        )
    }

    static func setOpenAIToken(_ value: String) {
        UserDefaults.standard.set(
            value.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: openAIKey
        )
    }

    /// Apify token: prefer user-set value in Settings, fall back to a
    /// build-time injected `Config.EXPO_PUBLIC_APIFY_TOKEN` if present.
    static var resolvedApifyToken: String {
        let stored = apifyToken
        if !stored.isEmpty { return stored }
        return Config.EXPO_PUBLIC_APIFY_TOKEN
    }

    /// OpenAI token: prefer user-set value in Settings, fall back to a
    /// build-time injected `Config.EXPO_PUBLIC_OPENAI_API_KEY` if present.
    static var resolvedOpenAIToken: String {
        let stored = openAIToken
        if !stored.isEmpty { return stored }
        return Config.EXPO_PUBLIC_OPENAI_API_KEY
    }
}
