import XCTest
@testable import ArmeniaAutoTax

final class LocalizationTests: XCTestCase {
    private func compiledStrings(for language: AppLanguage) throws -> [String: String] {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
            "Missing \(language.rawValue).lproj in the app bundle"
        )
        let stringsPath = (path as NSString).appendingPathComponent("Localizable.strings")
        let dictionary = try XCTUnwrap(
            NSDictionary(contentsOfFile: stringsPath) as? [String: String],
            "Missing compiled Localizable.strings for \(language.rawValue)"
        )
        return dictionary
    }

    func testCompiledCatalogHasAllThreeLanguagesForEveryKey() throws {
        let english = try compiledStrings(for: .english)
        let russian = try compiledStrings(for: .russian)
        let armenian = try compiledStrings(for: .armenian)

        XCTAssertGreaterThan(english.count, 150)
        XCTAssertEqual(Set(english.keys), Set(russian.keys))
        XCTAssertEqual(Set(english.keys), Set(armenian.keys))

        for (key, value) in english {
            XCTAssertFalse(value.isEmpty, "Empty English value for \(key)")
            XCTAssertFalse(russian[key, default: ""].isEmpty, "Missing Russian value for \(key)")
            XCTAssertFalse(armenian[key, default: ""].isEmpty, "Missing Armenian value for \(key)")
        }
    }

    func testEveryKeyResolvesInEveryLanguage() throws {
        let keys = try compiledStrings(for: .english).keys
        for language in AppLanguage.allCases {
            for key in keys {
                let value = L10n.string(key, language: language)
                XCTAssertNotEqual(value, key, "Missing compiled \(language.rawValue) for \(key)")
            }
        }
    }

    func testRepresentativeTranslations() {
        XCTAssertEqual(L10n.string("tab.settings", language: .english), "Settings")
        XCTAssertEqual(L10n.string("tab.settings", language: .russian), "Настройки")
        XCTAssertEqual(L10n.string("tab.settings", language: .armenian), "Կարգավորումներ")
        XCTAssertEqual(L10n.string("calculator.hero", language: .english),
                       "Less uncertainty.\nMore roads.")
    }

    func testNativeLanguageNamesAreStable() {
        XCTAssertEqual(AppLanguage.english.nativeName, "English")
        XCTAssertEqual(AppLanguage.russian.nativeName, "Русский")
        XCTAssertEqual(AppLanguage.armenian.nativeName, "Հայերեն")
    }
}
