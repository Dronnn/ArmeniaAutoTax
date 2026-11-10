import Foundation

/// The three languages supported by the app. English is the default.
enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case english = "en"
    case russian = "ru"
    case armenian = "hy"

    var id: String { rawValue }

    nonisolated static let storageKey = "app.language"

    /// UI tests use their own defaults suite so repeated runs stay isolated.
    nonisolated static var defaults: UserDefaults {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            return UserDefaults(suiteName: "ArmeniaAutoTaxUITests") ?? .standard
        }
        return .standard
    }

    nonisolated static var selected: AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: storageKey) ?? "") ?? .english
    }

    nonisolated var locale: Locale {
        Locale(identifier: rawValue)
    }

    /// The language name written in that language; never translated.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .russian: "Русский"
        case .armenian: "Հայերեն"
        }
    }
}

/// Localizes strings through the language-specific `.lproj` bundle so the
/// in-app language switch works without restarting the app.
enum L10n {
    nonisolated(unsafe) private static let bundleCache = NSCache<NSString, Bundle>()

    nonisolated static var language: AppLanguage { AppLanguage.selected }
    nonisolated static var locale: Locale { language.locale }

    nonisolated static func string(_ key: String) -> String {
        string(key, language: language)
    }

    nonisolated static func string(_ key: String, language: AppLanguage) -> String {
        let cacheKey = language.rawValue as NSString
        let bundle: Bundle
        if let cached = bundleCache.object(forKey: cacheKey) {
            bundle = cached
        } else if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
                  let loaded = Bundle(path: path) {
            bundleCache.setObject(loaded, forKey: cacheKey)
            bundle = loaded
        } else {
            return key
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    nonisolated static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    nonisolated static func format(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        String(format: string(key, language: language), locale: language.locale, arguments: arguments)
    }

    /// Proper plural forms for the supported languages.
    nonisolated static func years(_ count: Int, language selectedLanguage: AppLanguage? = nil) -> String {
        let activeLanguage = selectedLanguage ?? language
        switch activeLanguage {
        case .english:
            return format(count == 1 ? "common.years.one" : "common.years.many",
                          language: activeLanguage, count)
        case .russian:
            let mod10 = count % 10
            let mod100 = count % 100
            if mod10 == 1 && mod100 != 11 {
                return format("common.years.one", language: activeLanguage, count)
            }
            if (2...4).contains(mod10) && !(12...14).contains(mod100) {
                return format("common.years.few", language: activeLanguage, count)
            }
            return format("common.years.many", language: activeLanguage, count)
        case .armenian:
            return format("common.years.many", language: activeLanguage, count)
        }
    }
}

extension VehicleCategory {
    func localizedTitle(language: AppLanguage = .selected) -> String {
        switch self {
        case .passenger: L10n.string("category.passenger", language: language)
        case .bus: L10n.string("category.bus", language: language)
        case .cargo: L10n.string("category.cargo", language: language)
        case .motorcycle: L10n.string("category.motorcycle", language: language)
        case .other: L10n.string("category.other", language: language)
        }
    }

    func localizedShortTitle(language: AppLanguage = .selected) -> String {
        switch self {
        case .passenger: L10n.string("category.passenger.short", language: language)
        case .bus: L10n.string("category.bus.short", language: language)
        case .cargo: L10n.string("category.cargo.short", language: language)
        case .motorcycle: L10n.string("category.motorcycle.short", language: language)
        case .other: L10n.string("category.other.short", language: language)
        }
    }
}

extension Vehicle {
    func localizedDisplayName(language: AppLanguage = .selected) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return trimmed }
        return "\(category.localizedShortTitle(language: language)) · \(horsepower) \(L10n.string("common.hp", language: language))"
    }
}
