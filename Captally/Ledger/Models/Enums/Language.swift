import Foundation

enum Language: String, CaseIterable, Codable {
    case en = "en"
    case zhHans = "zh-Hans"

    var displayName: String {
        switch self {
        case .en: return "English"
        case .zhHans: return "简体中文"
        }
    }

    var nativeDisplayName: String {
        switch self {
        case .en: return "English"
        case .zhHans: return "简体中文"
        }
    }

    static var current: Language {
        let saved = UserDefaults.standard.string(forKey: "app.language")
        return Language(rawValue: saved ?? "") ?? .zhHans
    }
}
