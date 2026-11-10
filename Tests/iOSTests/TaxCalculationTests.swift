import XCTest
@testable import ArmeniaAutoTax

final class AppTaxCalculationTests: XCTestCase {
    func testOriginalWebsiteExample() {
        let vehicle = Vehicle(manufactureYear: 2019, horsepower: 243)
        let result = TaxCalculator.calculate(vehicle)
        XCTAssertEqual(result.periodTotal, 82_950)
        XCTAssertEqual(result.ageDiscountPercent, 50)
    }

    func testCriticalThresholds() {
        let expected: [(Int, Double)] = [
            (120, 12_000), (121, 18_150), (150, 22_500),
            (151, 23_150), (250, 87_500), (251, 113_250), (272, 129_000)
        ]
        for (horsepower, tax) in expected {
            XCTAssertEqual(TaxCalculator.calculate(Vehicle(horsepower: horsepower)).annualTotal, tax)
        }
    }

    func testRateConversionRoundTrip() {
        let rates = ExchangeRates.initial
        let dollars = rates.convert(82_950, from: .amd, to: .usd)
        XCTAssertEqual(rates.convert(dollars, from: .usd, to: .amd), 82_950, accuracy: 0.00001)
    }
}
