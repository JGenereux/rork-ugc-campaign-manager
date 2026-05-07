import Foundation

enum Config {
    private static let apifyKey = "ugc.config.apifyToken"
    private static let openAIKey = "ugc.config.openAIToken"

    static var apifyToken: String {
        UserDefaults.standard.string(forKey: apifyKey) ?? ""
    }

    static var openAIToken: String {
        UserDefaults.standard.string(forKey: openAIKey) ?? ""
    }

    static var EXPO_PUBLIC_APIFY_TOKEN: String { apifyToken }

    static func setApifyToken(_ value: String) {
        UserDefaults.standard.set(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: apifyKey)
    }

    static func setOpenAIToken(_ value: String) {
        UserDefaults.standard.set(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: openAIKey)
    }
}
