import XCTest
@testable import TaxCore

final class TaxCalculatorEdgeTests: XCTestCase {
    func testPassengerRateBandsUseWholePower() {
        let cases: [(Int, Int, Double)] = [
            (1, 200, 200),
            (120, 200, 24_000),
            (121, 300, 36_300),
            (150, 300, 45_000),
            (151, 300, 46_300),
            (200, 300, 110_000),
            (250, 300, 175_000),
            (251, 500, 226_500),
            (300, 500, 300_000)
        ]
        for (hp, rate, subtotal) in cases {
            let result = TaxCalculator.calculate(Vehicle(manufactureYear: 2026, horsepower: hp))
            XCTAssertEqual(result.baseRatePerHorsepower, rate, "Rate at \(hp) hp")
            XCTAssertEqual(result.subtotal, subtotal, "Subtotal at \(hp) hp")
        }
    }

    func testBusAndCargoRateBands() {
        for category in [VehicleCategory.bus, .cargo] {
            let low = TaxCalculator.calculate(Vehicle(manufactureYear: 2026, horsepower: 200, category: category))
            XCTAssertEqual(low.baseRatePerHorsepower, 100)
            XCTAssertEqual(low.subtotal, 20_000)
            let high = TaxCalculator.calculate(Vehicle(manufactureYear: 2026, horsepower: 201, category: category))
            XCTAssertEqual(high.baseRatePerHorsepower, 200)
            XCTAssertEqual(high.subtotal, 40_200)
        }
    }

    func testMotorcycleAndOtherRates() {
        let motorcycle = TaxCalculator.calculate(Vehicle(manufactureYear: 2026, horsepower: 100, category: .motorcycle))
        XCTAssertEqual(motorcycle.baseRatePerHorsepower, 40)
        XCTAssertEqual(motorcycle.subtotal, 4_000)
        let other = TaxCalculator.calculate(Vehicle(manufactureYear: 2026, horsepower: 100, category: .other))
        XCTAssertEqual(other.baseRatePerHorsepower, 150)
        XCTAssertEqual(other.subtotal, 15_000)
    }

    func testAgeDiscountScheduleAndCap() {
        let expected: [(Int, Int)] = [
            (2026, 0), (2025, 0), (2024, 0),
            (2023, 10), (2022, 20), (2021, 30), (2020, 40),
            (2019, 50), (2018, 50), (2000, 50)
        ]
        for (manufactureYear, discount) in expected {
            let result = TaxCalculator.calculate(Vehicle(manufactureYear: manufactureYear, horsepower: 100))
            XCTAssertEqual(result.age, 2026 - manufactureYear)
            XCTAssertEqual(result.ageDiscountPercent, discount, "Year \(manufactureYear)")
        }
    }

    func testAgeDiscountDoesNotApplyToMotorcycleOrOther() {
        for category in [VehicleCategory.motorcycle, .other] {
            let result = TaxCalculator.calculate(Vehicle(manufactureYear: 2000, horsepower: 100, category: category))
            XCTAssertEqual(result.ageDiscountPercent, 0)
            XCTAssertEqual(result.ageDiscountAmount, 0)
            XCTAssertEqual(result.annualTotal, result.subtotal)
        }
    }

    func testCargoExemptionBoundary() {
        let before = TaxCalculator.calculate(Vehicle(manufactureYear: 2007, horsepower: 200, category: .cargo))
        XCTAssertFalse(before.isExempt)
        XCTAssertGreaterThan(before.annualTotal, 0)

        let atBoundary = TaxCalculator.calculate(Vehicle(manufactureYear: 2006, horsepower: 200, category: .cargo))
        XCTAssertTrue(atBoundary.isExempt)
        XCTAssertEqual(atBoundary.annualTotal, 0)
        XCTAssertEqual(atBoundary.periodTotal, 0)

        let old = TaxCalculator.calculate(Vehicle(manufactureYear: 1990, horsepower: 200, category: .cargo))
        XCTAssertTrue(old.isExempt)
    }

    func testBusIsNotExemptAtTwentyYears() {
        let result = TaxCalculator.calculate(Vehicle(manufactureYear: 2006, horsepower: 200, category: .bus))
        XCTAssertFalse(result.isExempt)
        XCTAssertGreaterThan(result.annualTotal, 0)
    }

    func testMunicipalSurchargeAndMonthsAreClamped() {
        let result = TaxCalculator.calculate(Vehicle(
            manufactureYear: 2019,
            horsepower: 243,
            taxableMonths: 99,
            communitySurchargePercent: 99
        ))
        XCTAssertEqual(result.taxableMonths, 12)
        XCTAssertEqual(result.surchargePercent, 10)
        XCTAssertEqual(result.annualTotal, 91_245)
        XCTAssertEqual(result.periodTotal, 91_245)

        let low = TaxCalculator.calculate(Vehicle(
            manufactureYear: 2019,
            horsepower: 243,
            taxableMonths: -5,
            communitySurchargePercent: -5
        ))
        XCTAssertEqual(low.taxableMonths, 1)
        XCTAssertEqual(low.surchargePercent, 0)
        XCTAssertEqual(low.periodTotal, 6_912.5)
    }

    func testNegativeAndZeroPower() {
        for power in [-100, 0] {
            let result = TaxCalculator.calculate(Vehicle(manufactureYear: 2019, horsepower: power))
            XCTAssertEqual(result.baseAmount, 0)
            XCTAssertEqual(result.subtotal, 0)
            XCTAssertEqual(result.annualTotal, 0)
            XCTAssertEqual(result.periodTotal, 0)
        }
    }

    func testBreakdownComponentsAreConsistent() {
        let vehicle = Vehicle(
            manufactureYear: 2020,
            horsepower: 272,
            taxableMonths: 6,
            communitySurchargePercent: 5
        )
        let result = TaxCalculator.calculate(vehicle)
        XCTAssertEqual(result.subtotal, result.baseAmount + result.extraAmount)
        XCTAssertEqual(result.ageDiscountAmount, result.subtotal * Double(result.ageDiscountPercent) / 100)
        XCTAssertEqual(result.surchargeAmount, (result.subtotal - result.ageDiscountAmount) * Double(result.surchargePercent) / 100)
        XCTAssertEqual(result.annualTotal, result.subtotal - result.ageDiscountAmount + result.surchargeAmount)
        XCTAssertEqual(result.periodTotal, result.annualTotal * Double(result.taxableMonths) / 12)
        XCTAssertEqual(result.averagePerMonth, result.annualTotal / 12)
    }

    func testForecastUsesTheSameRatesAndEvolvingAge() {
        let car = Vehicle(manufactureYear: 2023, horsepower: 243)
        let values = (2026...2030).map {
            TaxCalculator.calculate(car, year: $0).annualTotal
        }
        XCTAssertEqual(values, [149_310, 132_720, 116_130, 99_540, 82_950])

        let younger = Vehicle(manufactureYear: 2024, horsepower: 120)
        XCTAssertEqual(TaxCalculator.calculate(younger, year: 2026).annualTotal, 24_000)
        XCTAssertEqual(TaxCalculator.calculate(younger, year: 2027).annualTotal, 21_600)
        XCTAssertEqual(TaxCalculator.calculate(younger, year: 2028).annualTotal, 19_200)
        XCTAssertEqual(TaxCalculator.calculate(younger, year: 2029).annualTotal, 16_800)
        XCTAssertEqual(TaxCalculator.calculate(younger, year: 2030).annualTotal, 14_400)
    }

    func testExemptCargoHasNoSurchargeOrPeriodAmount() {
        let result = TaxCalculator.calculate(Vehicle(
            manufactureYear: 2000,
            horsepower: 300,
            category: .cargo,
            taxableMonths: 6,
            communitySurchargePercent: 10
        ))
        XCTAssertTrue(result.isExempt)
        XCTAssertEqual(result.annualTotal, 0)
        XCTAssertEqual(result.periodTotal, 0)
        XCTAssertEqual(result.surchargeAmount, 0)
    }
}
