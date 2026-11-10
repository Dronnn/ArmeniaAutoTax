import XCTest
@testable import ArmeniaAutoTax

final class FormattingTests: XCTestCase {
    private let english = Locale(identifier: "en_US")
    private let russian = Locale(identifier: "ru_RU")

    func testMoneyNumberUsesTheRequestedLocale() {
        XCTAssertEqual(MoneyText.number(82_950, digits: 0, locale: english), "82,950")
        let russianText = MoneyText.number(82_950, digits: 0, locale: russian)
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\u{202f}", with: " ")
        XCTAssertEqual(russianText, "82 950")
    }

    func testMoneyAmountIncludesTheCurrencySymbol() {
        let text = MoneyText.amount(82_950, currency: .amd, digits: 0, locale: english)
        XCTAssertTrue(text.contains("82,950"))
        XCTAssertTrue(text.contains("֏"))
    }

    func testEditableTextHasNoGrouping() {
        XCTAssertEqual(MoneyText.editable(82_950.5, locale: english), "82950.5")
        XCTAssertEqual(MoneyText.editable(82_950.5, locale: russian), "82950,5")
    }

    func testDecimalInputParsing() {
        XCTAssertEqual(DecimalInput.parse("82,950.5", locale: english), 82_950.5)
        XCTAssertEqual(DecimalInput.parse("82,950", locale: english), 82_950)
        XCTAssertEqual(DecimalInput.parse("82 950,5", locale: russian), 82_950.5)
        XCTAssertEqual(DecimalInput.parse("82,95", locale: russian), 82.95)
        XCTAssertEqual(DecimalInput.parse("1,234.56", locale: english), 1_234.56)
        XCTAssertEqual(DecimalInput.parse("1 234,56", locale: russian), 1_234.56)
        XCTAssertEqual(DecimalInput.parse("82950.5", locale: english), 82_950.5)
        XCTAssertNil(DecimalInput.parse("", locale: english))
        XCTAssertNil(DecimalInput.parse("not a number", locale: english))
    }

    func testPluralYears() {
        XCTAssertEqual(L10n.years(1, language: .english), "1 year")
        XCTAssertEqual(L10n.years(2, language: .english), "2 years")
        XCTAssertEqual(L10n.years(1, language: .russian), "1 год")
        XCTAssertEqual(L10n.years(2, language: .russian), "2 года")
        XCTAssertEqual(L10n.years(5, language: .russian), "5 лет")
        XCTAssertEqual(L10n.years(11, language: .russian), "11 лет")
        XCTAssertEqual(L10n.years(21, language: .russian), "21 год")
        XCTAssertEqual(L10n.years(1, language: .armenian), "1 տարի")
        XCTAssertEqual(L10n.years(5, language: .armenian), "5 տարի")
    }
}
