import XCTest
@testable import TaxCore

final class TaxCalculatorTests: XCTestCase {
    func testSourceWebsiteGoldenExample() {
        let tax = TaxCalculator.calculate(Vehicle(manufactureYear: 2019, horsepower: 243))
        XCTAssertEqual(tax.baseAmount, 72_900)
        XCTAssertEqual(tax.extraAmount, 93_000)
        XCTAssertEqual(tax.ageDiscountPercent, 50)
        XCTAssertEqual(tax.periodTotal, 82_950)
        XCTAssertEqual(tax.averagePerMonth, 6_912.5)
    }

    func testPassengerBoundariesFromOriginalWebsite() {
        let cases: [(Double, Double)] = [
            (120, 12_000), (121, 18_150), (150, 22_500),
            (151, 23_150), (200, 55_000), (243, 82_950),
            (250, 87_500), (251, 113_250), (272, 129_000), (300, 150_000)
        ]
        for (hp, expected) in cases {
            let result = TaxCalculator.calculate(Vehicle(manufactureYear: 2019, horsepower: hp))
            XCTAssertEqual(result.annualTotal, expected, "Mismatch at \(hp) hp")
        }
    }

    func testEarlyAgeDiscount() {
        for year in [2026, 2025, 2024] {
            XCTAssertEqual(TaxCalculator.calculate(Vehicle(manufactureYear: year), year: 2026).ageDiscountPercent, 0)
        }
        XCTAssertEqual(TaxCalculator.calculate(Vehicle(manufactureYear: 2023)).ageDiscountPercent, 10)
        XCTAssertEqual(TaxCalculator.calculate(Vehicle(manufactureYear: 2022)).ageDiscountPercent, 20)
        XCTAssertEqual(TaxCalculator.calculate(Vehicle(manufactureYear: 2021)).ageDiscountPercent, 30)
        XCTAssertEqual(TaxCalculator.calculate(Vehicle(manufactureYear: 2020)).ageDiscountPercent, 40)
        XCTAssertEqual(TaxCalculator.calculate(Vehicle(manufactureYear: 2019)).ageDiscountPercent, 50)
    }

    func testCargoExemptBeginningWith20thSubsequentYear() {
        XCTAssertGreaterThan(TaxCalculator.calculate(Vehicle(manufactureYear: 2007, category: .cargo)).periodTotal, 0)
        XCTAssertEqual(TaxCalculator.calculate(Vehicle(manufactureYear: 2006, category: .cargo)).periodTotal, 0)
    }

    func testOtherCategories() {
        XCTAssertEqual(TaxCalculator.calculate(Vehicle(manufactureYear: 2026, horsepower: 200, category: .bus)).annualTotal, 20_000)
        XCTAssertEqual(TaxCalculator.calculate(Vehicle(manufactureYear: 2026, horsepower: 201, category: .cargo)).annualTotal, 40_200)
        XCTAssertEqual(TaxCalculator.calculate(Vehicle(manufactureYear: 2010, horsepower: 100, category: .motorcycle)).annualTotal, 4_000)
        XCTAssertEqual(TaxCalculator.calculate(Vehicle(manufactureYear: 2010, horsepower: 100, category: .other)).annualTotal, 15_000)
    }

    func testMunicipalSurchargeAndPartialYear() {
        let vehicle = Vehicle(manufactureYear: 2019, horsepower: 243, taxableMonths: 6, communitySurchargePercent: 10)
        let result = TaxCalculator.calculate(vehicle)
        XCTAssertEqual(result.annualTotal, 91_245)
        XCTAssertEqual(result.periodTotal, 45_622.5)
    }

    func testPowerZero() {
        XCTAssertEqual(TaxCalculator.calculate(Vehicle(horsepower: 0)).annualTotal, 0)
    }

    func testForecastKeepsTaxConstantAfterMaxDiscount() {
        let car = Vehicle(manufactureYear: 2019, horsepower: 243)
        for year in 2026...2030 {
            XCTAssertEqual(TaxCalculator.calculate(car, year: year).annualTotal, 82_950)
        }
    }
}
