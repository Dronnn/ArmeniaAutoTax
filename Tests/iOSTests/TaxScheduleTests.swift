import XCTest
@testable import ArmeniaAutoTax

final class TaxScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int = 6, _ day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Built-in schedule

    func testVerified2026ScheduleMatchesTheTaxCode() {
        let schedule = TaxRateSchedule.v2026
        XCTAssertEqual(schedule.year, 2026)
        XCTAssertEqual(schedule.status, .verified)
        XCTAssertEqual(schedule.verifiedOn, "2026-11-10")
        XCTAssertTrue(schedule.isValid)
        XCTAssertEqual(schedule.passengerBands.map(\.upperBound), [120, 250, nil])
        XCTAssertEqual(schedule.passengerBands.map(\.ratePerHorsepower), [200, 300, 500])
        XCTAssertEqual(schedule.passengerBands[1].extraAbove, 150)
        XCTAssertEqual(schedule.passengerBands[1].extraPerHorsepower, 1_000)
        XCTAssertEqual(schedule.busCargoBands.map(\.upperBound), [200, nil])
        XCTAssertEqual(schedule.busCargoBands.map(\.ratePerHorsepower), [100, 200])
        XCTAssertEqual(schedule.motorcycleRate, 40)
        XCTAssertEqual(schedule.otherRate, 150)
        XCTAssertEqual(schedule.fullTaxYears, 3)
        XCTAssertEqual(schedule.discountStep, 10)
        XCTAssertEqual(schedule.maxDiscount, 50)
        XCTAssertEqual(schedule.cargoExemptionAge, 20)
        XCTAssertEqual(schedule.communityMaxPercent, 10)
        XCTAssertEqual(schedule.evPowerRule, .v2026)
    }

    func testBandSelectionAtEveryPassengerBoundary() {
        let schedule = TaxRateSchedule.v2026
        let cases: [(Double, Int)] = [
            (0, 200), (1, 200), (120, 200),
            (120.000_1, 300), (121, 300), (150, 300), (250, 300),
            (250.000_1, 500), (251, 500), (10_000, 500)
        ]
        for (horsepower, rate) in cases {
            XCTAssertEqual(
                schedule.band(for: horsepower, category: .passenger).ratePerHorsepower,
                rate,
                "Passenger rate at \(horsepower)"
            )
        }
    }

    func testBandSelectionAtBusAndCargoBoundary() {
        let schedule = TaxRateSchedule.v2026
        for category in [VehicleCategory.bus, .cargo] {
            XCTAssertEqual(schedule.band(for: 0, category: category).ratePerHorsepower, 100)
            XCTAssertEqual(schedule.band(for: 200, category: category).ratePerHorsepower, 100)
            XCTAssertEqual(schedule.band(for: 200.000_1, category: category).ratePerHorsepower, 200)
            XCTAssertEqual(schedule.band(for: 201, category: category).ratePerHorsepower, 200)
        }
    }

    func testBandSelectionForMotorcycleAndOther() {
        let schedule = TaxRateSchedule.v2026
        XCTAssertEqual(schedule.band(for: 100, category: .motorcycle).ratePerHorsepower, 40)
        XCTAssertEqual(schedule.band(for: 100, category: .other).ratePerHorsepower, 150)
    }

    func testProjectedScheduleKeepsThe2026Rules() {
        let projected = TaxRateSchedule.projected(year: 2030)
        XCTAssertEqual(projected.year, 2030)
        XCTAssertEqual(projected.status, .projected)
        XCTAssertNil(projected.verifiedOn)
        XCTAssertEqual(projected.passengerBands, TaxRateSchedule.v2026.passengerBands)
        XCTAssertEqual(projected.busCargoBands, TaxRateSchedule.v2026.busCargoBands)
        XCTAssertTrue(projected.isValid)
    }

    // MARK: - Liability months

    private func day(_ year: Int, _ month: Int, _ day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testLiabilityMonthsFullYear() {
        XCTAssertEqual(LiabilityMonths.months(in: 2026, acquired: nil, disposed: nil, calendar: calendar), 12)
        XCTAssertEqual(
            LiabilityMonths.months(in: 2026, acquired: day(2020, 1, 1), disposed: day(2030, 1, 1), calendar: calendar),
            12
        )
    }

    func testLiabilityMonthsAcquisitionMonthIsNotCounted() {
        XCTAssertEqual(
            LiabilityMonths.months(in: 2026, acquired: day(2026, 1, 15), disposed: nil, calendar: calendar),
            11
        )
        XCTAssertEqual(
            LiabilityMonths.months(in: 2026, acquired: day(2026, 3, 10), disposed: nil, calendar: calendar),
            9
        )
        XCTAssertEqual(
            LiabilityMonths.months(in: 2026, acquired: day(2026, 11, 10), disposed: nil, calendar: calendar),
            1
        )
        XCTAssertEqual(
            LiabilityMonths.months(in: 2026, acquired: day(2026, 12, 10), disposed: nil, calendar: calendar),
            0
        )
    }

    func testLiabilityMonthsDisposalMonthIsCounted() {
        XCTAssertEqual(
            LiabilityMonths.months(in: 2026, acquired: nil, disposed: day(2026, 1, 10), calendar: calendar),
            1
        )
        XCTAssertEqual(
            LiabilityMonths.months(in: 2026, acquired: nil, disposed: day(2026, 6, 10), calendar: calendar),
            6
        )
        XCTAssertEqual(
            LiabilityMonths.months(in: 2026, acquired: nil, disposed: day(2026, 12, 31), calendar: calendar),
            12
        )
    }

    func testLiabilityMonthsAcquisitionAndDisposal() {
        XCTAssertEqual(
            LiabilityMonths.months(
                in: 2026,
                acquired: day(2026, 3, 10),
                disposed: day(2026, 6, 10),
                calendar: calendar
            ),
            3
        )
        XCTAssertEqual(
            LiabilityMonths.months(
                in: 2026,
                acquired: day(2025, 3, 10),
                disposed: day(2026, 6, 10),
                calendar: calendar
            ),
            6
        )
        XCTAssertEqual(
            LiabilityMonths.months(
                in: 2026,
                acquired: day(2027, 3, 10),
                disposed: day(2027, 6, 10),
                calendar: calendar
            ),
            0
        )
        XCTAssertEqual(
            LiabilityMonths.months(
                in: 2026,
                acquired: day(2025, 3, 10),
                disposed: day(2025, 6, 10),
                calendar: calendar
            ),
            0
        )
        XCTAssertEqual(
            LiabilityMonths.months(
                in: 2026,
                acquired: day(2026, 6, 10),
                disposed: day(2026, 3, 10),
                calendar: calendar
            ),
            0
        )
        XCTAssertEqual(
            LiabilityMonths.months(
                in: 2026,
                acquired: day(2026, 3, 10),
                disposed: day(2026, 3, 20),
                calendar: calendar
            ),
            0
        )
    }

    func testLiabilityMonthsAcrossYearBoundary() {
        let acquiredInDecember2026 = day(2026, 12, 15)
        XCTAssertEqual(
            LiabilityMonths.months(in: 2026, acquired: acquiredInDecember2026, disposed: nil, calendar: calendar),
            0
        )
        XCTAssertEqual(
            LiabilityMonths.months(in: 2027, acquired: acquiredInDecember2026, disposed: nil, calendar: calendar),
            12
        )
    }

    // MARK: - Power units

    func testPowerUnitConversion() {
        XCTAssertEqual(PowerUnit.horsepower.horsepower(from: 136), 136)
        XCTAssertEqual(PowerUnit.kilowatt.horsepower(from: 100), 136, accuracy: 0.000_001)
        XCTAssertEqual(PowerUnit.kilowatt.value(fromHorsepower: 136), 100, accuracy: 0.000_001)
        XCTAssertEqual(PowerUnit.horsepower.value(fromHorsepower: 136), 136)
        XCTAssertEqual(PowerUnit.kilowatt.horsepower(from: 0), 0)
        XCTAssertEqual(PowerUnit.kilowatt.horsepower(from: -10), 0)
        XCTAssertEqual(PowerUnit.kilowatt.horsepower(from: .nan), 0)
        XCTAssertEqual(PowerUnit.kilowatt.value(fromHorsepower: .infinity), 0)
    }

    // MARK: - Validation

    func testValidationRejectsInvalidSchedules() {
        var schedule = TaxRateSchedule.v2026
        schedule.year = 0
        XCTAssertTrue(schedule.validationIssues().contains(.invalidYear))

        schedule = .v2026
        schedule.passengerBands = []
        XCTAssertTrue(schedule.validationIssues().contains(.emptyBands))

        schedule = .v2026
        schedule.passengerBands = [
            TaxRateBand(upperBound: 120, ratePerHorsepower: 200),
            TaxRateBand(upperBound: 120, ratePerHorsepower: 300),
            TaxRateBand(upperBound: nil, ratePerHorsepower: 500)
        ]
        XCTAssertTrue(schedule.validationIssues().contains(.invalidPassengerBands))

        schedule = .v2026
        schedule.passengerBands = [
            TaxRateBand(upperBound: 120, ratePerHorsepower: -1),
            TaxRateBand(upperBound: 250, ratePerHorsepower: 300),
            TaxRateBand(upperBound: nil, ratePerHorsepower: 500)
        ]
        XCTAssertTrue(schedule.validationIssues().contains(.invalidPassengerBands))

        schedule = .v2026
        schedule.busCargoBands = [TaxRateBand(upperBound: 200, ratePerHorsepower: 100)]
        XCTAssertTrue(schedule.validationIssues().contains(.invalidBusCargoBands))

        schedule = .v2026
        schedule.motorcycleRate = -1
        XCTAssertTrue(schedule.validationIssues().contains(.negativeRate))

        schedule = .v2026
        schedule.fullTaxYears = 0
        XCTAssertTrue(schedule.validationIssues().contains(.invalidFullTaxYears))

        schedule = .v2026
        schedule.discountStep = -1
        XCTAssertTrue(schedule.validationIssues().contains(.invalidDiscountStep))

        schedule = .v2026
        schedule.maxDiscount = 101
        XCTAssertTrue(schedule.validationIssues().contains(.invalidMaxDiscount))

        schedule = .v2026
        schedule.cargoExemptionAge = 0
        XCTAssertTrue(schedule.validationIssues().contains(.invalidCargoExemptionAge))

        schedule = .v2026
        schedule.communityMaxPercent = 101
        XCTAssertTrue(schedule.validationIssues().contains(.invalidCommunityMax))

        schedule = .v2026
        schedule.evPowerRule.divisor = 0
        XCTAssertTrue(schedule.validationIssues().contains(.invalidEVRule))

        schedule = .v2026
        schedule.passengerBands[0].upperBound = .nan
        XCTAssertTrue(schedule.validationIssues().contains(.invalidPassengerBands))

        schedule = .v2026
        schedule.busCargoBands[0].extraAbove = .infinity
        XCTAssertTrue(schedule.validationIssues().contains(.invalidBusCargoBands))

        schedule = .v2026
        schedule.evPowerRule.divisor = .nan
        XCTAssertTrue(schedule.validationIssues().contains(.invalidEVRule))
    }

    func testValidationAcceptsBoundaryValues() {
        var schedule = TaxRateSchedule.v2026
        schedule.fullTaxYears = 1
        schedule.discountStep = 0
        schedule.maxDiscount = 0
        schedule.cargoExemptionAge = 1
        schedule.communityMaxPercent = 0
        schedule.motorcycleRate = 0
        schedule.otherRate = 0
        schedule.evPowerRule.isEnabled = false
        XCTAssertTrue(schedule.isValid)

        schedule.communityMaxPercent = 100
        schedule.maxDiscount = 100
        XCTAssertTrue(schedule.isValid)
    }

    // MARK: - EV rule

    func testEVPowerRuleForwardAndInverse() {
        let rule = EVPowerRule.v2026
        XCTAssertEqual(rule.taxablePower(from: 0), 0)
        XCTAssertEqual(rule.taxablePower(from: 1), 1.0 / 1.5, accuracy: 0.000_001)
        XCTAssertEqual(rule.taxablePower(from: 250), 250.0 / 1.5, accuracy: 0.000_001)
        XCTAssertEqual(rule.taxablePower(from: 544), 250.0 / 1.5 + 294.0 / 2.5, accuracy: 0.000_001)
        XCTAssertEqual(rule.rawPower(forTaxable: 250), 458.333_333, accuracy: 0.000_001)
        XCTAssertEqual(rule.rawPower(forTaxable: 251), 460.833_333, accuracy: 0.000_001)
        XCTAssertEqual(rule.rawPower(forTaxable: rule.taxablePower(from: 544)),
                       544, accuracy: 0.000_001)
    }

    func testDisabledEVRuleUsesRawPower() {
        var rule = EVPowerRule.v2026
        rule.isEnabled = false
        XCTAssertEqual(rule.taxablePower(from: 544), 544)
        XCTAssertEqual(rule.rawPower(forTaxable: 284.266_667), 284.266_667, accuracy: 0.000_001)
    }

    func testEVRuleHandlesInvalidNumbers() {
        let rule = EVPowerRule.v2026
        XCTAssertEqual(rule.taxablePower(from: -10), 0)
        XCTAssertEqual(rule.taxablePower(from: .nan), 0)
        XCTAssertEqual(rule.taxablePower(from: .infinity), 0)
        XCTAssertEqual(rule.rawPower(forTaxable: -10), 0)
        XCTAssertEqual(rule.rawPower(forTaxable: .nan), 0)
    }

    // MARK: - Current year

    func testCurrentTaxYearClampsToSupportedRange() {
        XCTAssertEqual(TaxScheduleStore.currentTaxYear(now: date(2025), calendar: calendar), 2026)
        XCTAssertEqual(TaxScheduleStore.currentTaxYear(now: date(2026), calendar: calendar), 2026)
        XCTAssertEqual(TaxScheduleStore.currentTaxYear(now: date(2027), calendar: calendar), 2027)
        XCTAssertEqual(TaxScheduleStore.currentTaxYear(now: date(2031), calendar: calendar), 2031)
        XCTAssertEqual(TaxScheduleStore.currentTaxYear(now: date(2040), calendar: calendar), 2035)
    }

    func testAvailableYears() {
        XCTAssertEqual(TaxScheduleStore.availableYears(now: date(2026), calendar: calendar),
                       Array(2026...2030))
        XCTAssertEqual(TaxScheduleStore.availableYears(now: date(2027), calendar: calendar),
                       Array(2026...2030))
        XCTAssertEqual(TaxScheduleStore.availableYears(now: date(2031), calendar: calendar),
                       Array(2026...2031))
        XCTAssertEqual(TaxScheduleStore.availableYears(now: date(2040), calendar: calendar),
                       Array(2026...2035))
    }

    func testClampedYear() {
        XCTAssertEqual(TaxScheduleStore.clampedYear(1900, now: date(2026), calendar: calendar), 2026)
        XCTAssertEqual(TaxScheduleStore.clampedYear(2028, now: date(2026), calendar: calendar), 2028)
        XCTAssertEqual(TaxScheduleStore.clampedYear(2040, now: date(2040), calendar: calendar), 2035)
    }

    func testSuggestsCurrentYear() {
        XCTAssertFalse(TaxScheduleStore.suggestsCurrentYear(persisted: 2026, now: date(2026), calendar: calendar))
        XCTAssertTrue(TaxScheduleStore.suggestsCurrentYear(persisted: 2026, now: date(2027), calendar: calendar))
        XCTAssertFalse(TaxScheduleStore.suggestsCurrentYear(persisted: 2027, now: date(2027), calendar: calendar))
        XCTAssertFalse(TaxScheduleStore.suggestsCurrentYear(persisted: 2028, now: date(2027), calendar: calendar))
    }

    // MARK: - Calculator with EV and years

    func testElectricVehicle544In2026() {
        let vehicle = Vehicle(manufactureYear: 2025, horsepower: 544, powerSource: .electricRaw)
        let result = TaxCalculator.calculate(vehicle, year: 2026)
        XCTAssertEqual(result.taxableHorsepower, 250.0 / 1.5 + 294.0 / 2.5, accuracy: 0.000_001)
        XCTAssertEqual(result.annualTotal, 276_400, accuracy: 0.01)
        XCTAssertTrue(result.isElectricAdjusted)
        XCTAssertEqual(result.rateStatus, .verified)
    }

    func testElectricVehicle218In2026() {
        let vehicle = Vehicle(manufactureYear: 2025, horsepower: 218, powerSource: .electricRaw)
        let result = TaxCalculator.calculate(vehicle, year: 2026)
        XCTAssertEqual(result.taxableHorsepower, 218.0 / 1.5, accuracy: 0.000_001)
        XCTAssertEqual(result.annualTotal, 43_600, accuracy: 0.01)
    }

    func testElectricPassportPowerIsUsedAsIs() {
        let vehicle = Vehicle(manufactureYear: 2025, horsepower: 284.266_667, powerSource: .electricPassport)
        let result = TaxCalculator.calculate(vehicle, year: 2026)
        XCTAssertEqual(result.taxableHorsepower, 284.266_667, accuracy: 0.000_001)
        XCTAssertEqual(result.annualTotal, 276_400, accuracy: 0.01)
        XCTAssertFalse(result.isElectricAdjusted)
    }

    func testFuelVehicleUsesRawPower() {
        let vehicle = Vehicle(manufactureYear: 2025, horsepower: 544, powerSource: .fuel)
        let result = TaxCalculator.calculate(vehicle, year: 2026)
        XCTAssertEqual(result.taxableHorsepower, 544)
        XCTAssertEqual(result.annualTotal, 666_000)
        XCTAssertFalse(result.isElectricAdjusted)
    }

    func testEVZeroPower() {
        let vehicle = Vehicle(manufactureYear: 2025, horsepower: 0, powerSource: .electricRaw)
        let result = TaxCalculator.calculate(vehicle, year: 2026)
        XCTAssertEqual(result.taxableHorsepower, 0)
        XCTAssertEqual(result.annualTotal, 0)
        XCTAssertFalse(result.isElectricAdjusted)
    }

    func testZeroLiabilityMonthsHasZeroPeriodAndAverage() {
        let vehicle = Vehicle(manufactureYear: 2019, horsepower: 243, taxableMonths: 0)
        let result = TaxCalculator.calculate(vehicle, year: 2026)
        XCTAssertEqual(result.taxableMonths, 0)
        XCTAssertEqual(result.periodTotal, 0)
        XCTAssertEqual(result.averagePerMonth, 0)
        XCTAssertGreaterThan(result.annualTotal, 0)
    }

    func testInvalidPowerIsSanitized() {
        for power in [Double.nan, .infinity, -100] {
            let vehicle = Vehicle(manufactureYear: 2019, horsepower: power)
            let result = TaxCalculator.calculate(vehicle, year: 2026)
            XCTAssertEqual(result.rawHorsepower, 0)
            XCTAssertEqual(result.annualTotal, 0)
        }
    }

    func testAgeAdvancesWithTaxYear() {
        let car = Vehicle(manufactureYear: 2020, horsepower: 243)
        XCTAssertEqual(TaxCalculator.calculate(car, year: 2026).annualTotal, 99_540)
        XCTAssertEqual(TaxCalculator.calculate(car, year: 2027).annualTotal, 82_950)
        XCTAssertEqual(TaxCalculator.calculate(car, year: 2027).ageDiscountPercent, 50)
        XCTAssertEqual(TaxCalculator.calculate(car, year: 2027).rateStatus, .projected)
    }

    func testVehicleManufacturedInTaxYearHasNoDiscount() {
        let car = Vehicle(manufactureYear: 2028, horsepower: 120)
        let result = TaxCalculator.calculate(car, year: 2028)
        XCTAssertEqual(result.age, 0)
        XCTAssertEqual(result.ageDiscountPercent, 0)
    }

    // MARK: - Custom schedule

    func testCustomScheduleChangesRates() {
        var schedule = TaxRateSchedule.v2026
        schedule.passengerBands[2].ratePerHorsepower = 600
        schedule.passengerBands[2].extraPerHorsepower = 0
        let car = Vehicle(manufactureYear: 2019, horsepower: 251)
        let result = TaxCalculator.calculate(car, year: 2026, schedule: schedule)
        XCTAssertEqual(result.baseRatePerHorsepower, 600)
        XCTAssertEqual(result.annualTotal, 75_300)
        XCTAssertEqual(result.rateStatus, .verified)
    }

    func testCustomAgeRules() {
        var schedule = TaxRateSchedule.v2026
        schedule.fullTaxYears = 1
        schedule.discountStep = 5
        schedule.maxDiscount = 30
        let car = Vehicle(manufactureYear: 2019, horsepower: 100)
        let result = TaxCalculator.calculate(car, year: 2026, schedule: schedule)
        XCTAssertEqual(result.ageDiscountPercent, 30)
    }

    func testCustomCargoExemptionAge() {
        var schedule = TaxRateSchedule.v2026
        schedule.cargoExemptionAge = 10
        let vehicle = Vehicle(manufactureYear: 2016, horsepower: 200, category: .cargo)
        let result = TaxCalculator.calculate(vehicle, year: 2026, schedule: schedule)
        XCTAssertTrue(result.isExempt)
        XCTAssertEqual(result.annualTotal, 0)
    }

    func testCustomCommunityMaximumClampsSurcharge() {
        var schedule = TaxRateSchedule.v2026
        schedule.communityMaxPercent = 5
        let vehicle = Vehicle(
            manufactureYear: 2019,
            horsepower: 243,
            communitySurchargePercent: 10
        )
        let result = TaxCalculator.calculate(vehicle, year: 2026, schedule: schedule)
        XCTAssertEqual(result.surchargePercent, 5)
        XCTAssertEqual(result.annualTotal, 87_097.5)
    }

    func testCustomEVDisable() {
        var schedule = TaxRateSchedule.v2026
        schedule.evPowerRule.isEnabled = false
        let vehicle = Vehicle(manufactureYear: 2025, horsepower: 544, powerSource: .electricRaw)
        let result = TaxCalculator.calculate(vehicle, year: 2026, schedule: schedule)
        XCTAssertEqual(result.taxableHorsepower, 544)
        XCTAssertFalse(result.isElectricAdjusted)
    }

    func testInvalidScheduleValuesAreClampedByTheCalculator() {
        var schedule = TaxRateSchedule.v2026
        schedule.maxDiscount = 200
        schedule.discountStep = 100
        schedule.fullTaxYears = 1
        schedule.communityMaxPercent = 200
        let vehicle = Vehicle(
            manufactureYear: 2019,
            horsepower: 243,
            communitySurchargePercent: 200
        )
        let result = TaxCalculator.calculate(vehicle, year: 2026, schedule: schedule)
        XCTAssertEqual(result.ageDiscountPercent, 100)
        XCTAssertEqual(result.surchargePercent, 100)
        XCTAssertEqual(result.annualTotal, 0)
    }

    // MARK: - Charts

    func testChartUsesTaxablePowerForEV() {
        let vehicle = Vehicle(manufactureYear: 2025, horsepower: 544, powerSource: .electricRaw)
        let points = TaxChartData.horsepowerPoints(for: vehicle, year: 2026)
        XCTAssertTrue(points.contains { abs($0.horsepower - (250.0 / 1.5 + 294.0 / 2.5)) < 0.000_1 })
        XCTAssertTrue(points.contains { $0.horsepower == 250 })
        XCTAssertTrue(points.contains { $0.horsepower == 251 })
        for point in points {
            XCTAssertEqual(point.annualTax, TaxCalculator.calculate(
                {
                    var current = vehicle
                    current.horsepower = point.rawHorsepower
                    current.taxableMonths = 12
                    return current
                }(),
                year: 2026
            ).annualTotal)
        }
    }

    func testChartThresholdDifferenceForEV() throws {
        let vehicle = Vehicle(manufactureYear: 2025, horsepower: 544, powerSource: .electricRaw)
        let difference = try XCTUnwrap(TaxChartData.thresholdDifference(for: vehicle, year: 2026))
        XCTAssertEqual(difference, 51_500, accuracy: 0.01)
    }

    func testChartYearStatuses() {
        let points = TaxChartData.yearPoints(for: Vehicle(manufactureYear: 2020, horsepower: 120))
        XCTAssertEqual(points.first?.status, .verified)
        XCTAssertEqual(Array(points.dropFirst().map(\.status)), Array(repeating: .projected, count: 4))
    }

    func testChartCustomScheduleStatus() {
        var custom = TaxRateSchedule.projected(year: 2027)
        custom.status = .custom
        let points = TaxChartData.yearPoints(for: Vehicle(manufactureYear: 2020, horsepower: 120)) { year in
            year == 2027 ? custom : TaxScheduleStore.schedule(for: year)
        }
        XCTAssertEqual(points.first { $0.year == 2027 }?.status, .custom)
    }
}
