import Foundation

/// A horsepower comparison point for the chart.
public struct HorsepowerTaxPoint: Identifiable, Equatable, Sendable {
    /// Taxable horsepower, i.e. after the EV power adjustment when applicable.
    public let horsepower: Double
    public let rawHorsepower: Double
    public let annualTax: Double
    public var id: Double { horsepower }

    public init(horsepower: Double, rawHorsepower: Double, annualTax: Double) {
        self.horsepower = horsepower
        self.rawHorsepower = rawHorsepower
        self.annualTax = annualTax
    }
}

/// A forecast point for one tax year.
public struct YearTaxPoint: Identifiable, Equatable, Sendable {
    public let year: Int
    public let annualTax: Double
    public let status: TaxRateStatus
    public var id: Int { year }

    public init(year: Int, annualTax: Double, status: TaxRateStatus) {
        self.year = year
        self.annualTax = annualTax
        self.status = status
    }
}

/// The discrete horsepower values shown by the reference site, plus the
/// boundary that matters for the selected vehicle category.
public enum TaxChartData {
    public static let referenceYears = TaxScheduleStore.chartYears
    public static let passengerMilestones: [Double] = [120, 121, 150, 151, 200, 243, 250, 251, 272, 300]
    public static let busOrCargoMilestones: [Double] = [120, 150, 200, 201, 243, 250, 300]

    /// The category-specific rate jump highlighted below the chart. These are
    /// taxable horsepower values, not raw EV motor power.
    public static func thresholdPair(for category: VehicleCategory) -> (low: Double, high: Double)? {
        switch category {
        case .passenger: (250, 251)
        case .bus, .cargo: (200, 201)
        case .motorcycle, .other: nil
        }
    }

    public static func horsepowerPoints(
        for vehicle: Vehicle,
        year: Int = TaxCalculator.referenceYear,
        schedule: TaxRateSchedule? = nil
    ) -> [HorsepowerTaxPoint] {
        let effectiveSchedule = schedule ?? TaxScheduleStore.schedule(for: year)
        let milestones = vehicle.category == .passenger ? passengerMilestones : busOrCargoMilestones
        let currentTaxablePower = TaxCalculator.taxablePower(for: vehicle, schedule: effectiveSchedule)
        let values = Set(milestones + [currentTaxablePower]).sorted()

        return values.map { taxablePower in
            var current = vehicle
            current.horsepower = TaxCalculator.rawPower(
                forTaxable: taxablePower,
                vehicle: vehicle,
                schedule: effectiveSchedule
            )
            current.taxableMonths = 12
            let tax = TaxCalculator.calculate(current, year: year, schedule: effectiveSchedule)
            return HorsepowerTaxPoint(
                horsepower: tax.taxableHorsepower,
                rawHorsepower: tax.rawHorsepower,
                annualTax: tax.annualTotal
            )
        }
    }

    public static func yearPoints(
        for vehicle: Vehicle,
        years: ClosedRange<Int> = referenceYears,
        scheduleForYear: (Int) -> TaxRateSchedule = { TaxScheduleStore.schedule(for: $0) }
    ) -> [YearTaxPoint] {
        years.map { year in
            var current = vehicle
            current.taxableMonths = 12
            let schedule = scheduleForYear(year)
            let tax = TaxCalculator.calculate(current, year: year, schedule: schedule)
            return YearTaxPoint(year: year, annualTax: tax.annualTotal, status: schedule.status)
        }
    }

    public static func thresholdDifference(
        for vehicle: Vehicle,
        year: Int = TaxCalculator.referenceYear,
        schedule: TaxRateSchedule? = nil
    ) -> Double? {
        guard let pair = thresholdPair(for: vehicle.category) else { return nil }
        let effectiveSchedule = schedule ?? TaxScheduleStore.schedule(for: year)

        func annualTax(atTaxablePower taxablePower: Double) -> Double {
            var current = vehicle
            current.horsepower = TaxCalculator.rawPower(
                forTaxable: taxablePower,
                vehicle: vehicle,
                schedule: effectiveSchedule
            )
            current.taxableMonths = 12
            return TaxCalculator.calculate(current, year: year, schedule: effectiveSchedule).annualTotal
        }

        return annualTax(atTaxablePower: pair.high) - annualTax(atTaxablePower: pair.low)
    }
}
