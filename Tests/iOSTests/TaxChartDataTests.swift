import XCTest
@testable import ArmeniaAutoTax

final class TaxChartDataTests: XCTestCase {
    func testPassengerHorsepowerPointsAreSortedUniqueAndIncludeSelectedValue() {
        let vehicle = Vehicle(manufactureYear: 2019, horsepower: 137)
        let points = TaxChartData.horsepowerPoints(for: vehicle)
        XCTAssertEqual(points.map(\.horsepower), points.map(\.horsepower).sorted())
        XCTAssertEqual(Set(points.map(\.horsepower)).count, points.count)
        XCTAssertTrue(points.contains { $0.horsepower == 137 })
        XCTAssertTrue(points.contains { $0.horsepower == 120 })
        XCTAssertTrue(points.contains { $0.horsepower == 251 })
    }

    func testHorsepowerPointValuesComeFromTheTaxEngine() {
        let vehicle = Vehicle(manufactureYear: 2019, horsepower: 243)
        for point in TaxChartData.horsepowerPoints(for: vehicle) {
            var expectedVehicle = vehicle
            expectedVehicle.horsepower = point.horsepower
            expectedVehicle.taxableMonths = 12
            XCTAssertEqual(point.annualTax, TaxCalculator.calculate(expectedVehicle).annualTotal)
        }
    }

    func testPassengerThresholdDifference() {
        let vehicle = Vehicle(manufactureYear: 2019, horsepower: 243)
        XCTAssertEqual(TaxChartData.thresholdPair(for: .passenger)?.low, 250)
        XCTAssertEqual(TaxChartData.thresholdPair(for: .passenger)?.high, 251)
        XCTAssertEqual(TaxChartData.thresholdDifference(for: vehicle), 25_750)
    }

    func testBusAndCargoThresholdDifference() {
        for category in [VehicleCategory.bus, .cargo] {
            let vehicle = Vehicle(manufactureYear: 2026, horsepower: 200, category: category)
            XCTAssertEqual(TaxChartData.thresholdPair(for: category)?.low, 200)
            XCTAssertEqual(TaxChartData.thresholdPair(for: category)?.high, 201)
            XCTAssertEqual(TaxChartData.thresholdDifference(for: vehicle), 20_200)
        }
    }

    func testMotorcycleAndOtherHaveNoJump() {
        for category in [VehicleCategory.motorcycle, .other] {
            XCTAssertNil(TaxChartData.thresholdPair(for: category))
            XCTAssertNil(TaxChartData.thresholdDifference(
                for: Vehicle(manufactureYear: 2026, horsepower: 100, category: category)
            ))
        }
    }

    func testYearPointsCoverReferenceYears() {
        let vehicle = Vehicle(manufactureYear: 2020, horsepower: 120)
        let points = TaxChartData.yearPoints(for: vehicle)
        XCTAssertEqual(points.map(\.year), [2026, 2027, 2028, 2029, 2030])
        XCTAssertEqual(points.map(\.annualTax), [14_400, 12_000, 12_000, 12_000, 12_000])
    }

    func testChartsAlwaysUseFullYear() {
        let vehicle = Vehicle(manufactureYear: 2019, horsepower: 243, taxableMonths: 3)
        for point in TaxChartData.horsepowerPoints(for: vehicle) {
            var fullYear = vehicle
            fullYear.horsepower = point.horsepower
            fullYear.taxableMonths = 12
            XCTAssertEqual(point.annualTax, TaxCalculator.calculate(fullYear).annualTotal)
        }
        for point in TaxChartData.yearPoints(for: vehicle) {
            var fullYear = vehicle
            fullYear.taxableMonths = 12
            XCTAssertEqual(point.annualTax, TaxCalculator.calculate(fullYear, year: point.year).annualTotal)
        }
    }

    func testZeroPowerDoesNotCrash() {
        let points = TaxChartData.horsepowerPoints(for: Vehicle(manufactureYear: 2026, horsepower: 0))
        XCTAssertTrue(points.contains { $0.horsepower == 0 && $0.annualTax == 0 })
    }
}
