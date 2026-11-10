import Foundation

/// A horsepower comparison point for the chart.
public struct HorsepowerTaxPoint: Identifiable, Equatable, Sendable {
    public let horsepower: Int
    public let annualTax: Double
    public var id: Int { horsepower }

    public init(horsepower: Int, annualTax: Double) {
        self.horsepower = horsepower
        self.annualTax = annualTax
    }
}

/// A forecast point for one tax year.
public struct YearTaxPoint: Identifiable, Equatable, Sendable {
    public let year: Int
    public let annualTax: Double
    public var id: Int { year }

    public init(year: Int, annualTax: Double) {
        self.year = year
        self.annualTax = annualTax
    }
}

/// The discrete horsepower values shown by the reference site, plus the
/// boundary that matters for the selected vehicle category.
public enum TaxChartData {
    public static let referenceYears = 2026...2030
    public static let passengerMilestones = [120, 121, 150, 151, 200, 243, 250, 251, 272, 300]
    public static let busOrCargoMilestones = [120, 150, 200, 201, 243, 250, 300]

    /// The category-specific rate jump highlighted below the chart.
    public static func thresholdPair(for category: VehicleCategory) -> (low: Int, high: Int)? {
        switch category {
        case .passenger: (250, 251)
        case .bus, .cargo: (200, 201)
        case .motorcycle, .other: nil
        }
    }

    public static func horsepowerPoints(for vehicle: Vehicle) -> [HorsepowerTaxPoint] {
        let milestones = vehicle.category == .passenger ? passengerMilestones : busOrCargoMilestones
        let values = Set(milestones + [max(0, vehicle.horsepower)]).sorted()
        return values.map { horsepower in
            var current = vehicle
            current.horsepower = horsepower
            current.taxableMonths = 12
            return HorsepowerTaxPoint(
                horsepower: horsepower,
                annualTax: TaxCalculator.calculate(current).annualTotal
            )
        }
    }

    public static func yearPoints(
        for vehicle: Vehicle,
        years: ClosedRange<Int> = referenceYears
    ) -> [YearTaxPoint] {
        years.map { year in
            var current = vehicle
            current.taxableMonths = 12
            return YearTaxPoint(
                year: year,
                annualTax: TaxCalculator.calculate(current, year: year).annualTotal
            )
        }
    }

    public static func thresholdDifference(for vehicle: Vehicle) -> Double? {
        guard let pair = thresholdPair(for: vehicle.category) else { return nil }
        var low = vehicle
        low.horsepower = pair.low
        low.taxableMonths = 12
        var high = vehicle
        high.horsepower = pair.high
        high.taxableMonths = 12
        return TaxCalculator.calculate(high).annualTotal - TaxCalculator.calculate(low).annualTotal
    }
}
