import Foundation

/// Where the entered horsepower comes from. The distinction matters for
/// electric vehicles under the 2026 government decision: raw motor power is
/// adjusted before the regular Article 244 rates are applied, while power
/// already recorded in an EAEU electronic passport is used as is.
public enum VehiclePowerSource: String, CaseIterable, Codable, Identifiable, Sendable {
    case fuel
    case electricPassport
    case electricRaw

    public var id: String { rawValue }

    public var isElectric: Bool { self != .fuel }

    /// Only raw electric motor power needs the 1.5 / 2.5 adjustment.
    public var appliesEVRule: Bool { self == .electricRaw }
}

/// Input unit for the power field. The Tax Code applies coefficient 1.36
/// when the tax base is expressed in kilowatts.
public enum PowerUnit: String, CaseIterable, Identifiable, Sendable {
    case horsepower
    case kilowatt

    public var id: String { rawValue }

    public func horsepower(from value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return self == .horsepower ? max(0, value) : max(0, value) * 1.36
    }

    public func value(fromHorsepower horsepower: Double) -> Double {
        guard horsepower.isFinite else { return 0 }
        return self == .horsepower ? max(0, horsepower) : max(0, horsepower) / 1.36
    }
}

/// Article 246/248 estimate for a partial ownership year.
///
/// Liability starts on the first day of the month after acquisition and ends
/// after the disposal month. The disposal month is therefore counted in full.
/// An acquisition in December produces 0 liability months in that tax year;
/// an acquisition in November produces one month, although Article 246(3)(3)
/// may shift the payment to the following year.
public enum LiabilityMonths {
    public static func months(
        in taxYear: Int,
        acquired: Date?,
        disposed: Date?,
        calendar: Calendar = .current
    ) -> Int {
        guard
            let yearStart = calendar.date(from: DateComponents(year: taxYear, month: 1, day: 1)),
            let yearEnd = calendar.date(from: DateComponents(year: taxYear, month: 12, day: 31))
        else { return 0 }

        if let acquired, acquired > yearEnd { return 0 }
        if let disposed, disposed < yearStart { return 0 }

        let firstMonth: Int
        if let acquired, acquired >= yearStart {
            firstMonth = calendar.component(.month, from: acquired) + 1
        } else {
            firstMonth = 1
        }

        let lastMonth: Int
        if let disposed, disposed <= yearEnd {
            lastMonth = calendar.component(.month, from: disposed)
        } else {
            lastMonth = 12
        }

        return min(12, max(0, lastMonth - firstMonth + 1))
    }
}

public enum TaxRateStatus: String, Codable, Equatable, Sendable {
    /// Checked against the Tax Code for that year.
    case verified
    /// Carried forward from the last verified schedule. Useful but not a legal prediction.
    case projected
    /// Entered or saved by the user.
    case custom
}

public struct TaxRateBand: Codable, Equatable, Sendable {
    /// `nil` means the final, open-ended band.
    public var upperBound: Double?
    public var ratePerHorsepower: Int
    /// The horsepower threshold above which the extra rate applies.
    public var extraAbove: Double?
    public var extraPerHorsepower: Int?

    public init(
        upperBound: Double?,
        ratePerHorsepower: Int,
        extraAbove: Double? = nil,
        extraPerHorsepower: Int? = nil
    ) {
        self.upperBound = upperBound
        self.ratePerHorsepower = ratePerHorsepower
        self.extraAbove = extraAbove
        self.extraPerHorsepower = extraPerHorsepower
    }

    public func contains(_ horsepower: Double) -> Bool {
        horsepower <= (upperBound ?? .infinity)
    }
}

public struct EVPowerRule: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var threshold: Double
    public var divisor: Double
    public var excessDivisor: Double

    public init(isEnabled: Bool, threshold: Double, divisor: Double, excessDivisor: Double) {
        self.isEnabled = isEnabled
        self.threshold = threshold
        self.divisor = divisor
        self.excessDivisor = excessDivisor
    }

    public static let v2026 = EVPowerRule(
        isEnabled: true,
        threshold: 250,
        divisor: 1.5,
        excessDivisor: 2.5
    )

    /// Raw motor power -> taxable power. Up to 250 hp is divided by 1.5;
    /// above 250 hp the first 250 is divided by 1.5 and the remainder by 2.5.
    public func taxablePower(from raw: Double) -> Double {
        let safeRaw = raw.isFinite ? max(0, raw) : 0
        guard isEnabled, safeRaw > 0, divisor > 0, excessDivisor > 0 else { return safeRaw }
        if safeRaw <= threshold { return safeRaw / divisor }
        return threshold / divisor + (safeRaw - threshold) / excessDivisor
    }

    /// Inverse of `taxablePower(from:)`, used by the chart to keep the
    /// statutory horsepower thresholds on the x-axis.
    public func rawPower(forTaxable taxable: Double) -> Double {
        let safeTaxable = taxable.isFinite ? max(0, taxable) : 0
        guard isEnabled, safeTaxable > 0, divisor > 0, excessDivisor > 0 else { return safeTaxable }
        let taxableThreshold = threshold / divisor
        if safeTaxable <= taxableThreshold { return safeTaxable * divisor }
        return threshold + (safeTaxable - taxableThreshold) * excessDivisor
    }
}

public enum TaxRateValidationIssue: String, CaseIterable, Codable, Sendable {
    case invalidNumber
    case invalidYear
    case emptyBands
    case invalidPassengerBands
    case invalidBusCargoBands
    case negativeRate
    case invalidFullTaxYears
    case invalidDiscountStep
    case invalidMaxDiscount
    case invalidCargoExemptionAge
    case invalidCommunityMax
    case invalidEVRule
}

/// One complete rate schedule for one tax year. The calculator has no
/// hard-coded rates; everything comes from this value.
public struct TaxRateSchedule: Codable, Equatable, Sendable {
    public var year: Int
    public var status: TaxRateStatus
    public var verifiedOn: String?
    public var source: String?
    public var passengerBands: [TaxRateBand]
    public var busCargoBands: [TaxRateBand]
    public var motorcycleRate: Int
    public var otherRate: Int
    /// The release year and the two following tax years are taxed in full.
    public var fullTaxYears: Int
    public var discountStep: Int
    public var maxDiscount: Int
    public var cargoExemptionAge: Int
    public var communityMaxPercent: Int
    public var evPowerRule: EVPowerRule

    public init(
        year: Int,
        status: TaxRateStatus = .verified,
        verifiedOn: String? = nil,
        source: String? = nil,
        passengerBands: [TaxRateBand],
        busCargoBands: [TaxRateBand],
        motorcycleRate: Int,
        otherRate: Int,
        fullTaxYears: Int = 3,
        discountStep: Int = 10,
        maxDiscount: Int = 50,
        cargoExemptionAge: Int = 20,
        communityMaxPercent: Int = 10,
        evPowerRule: EVPowerRule = .v2026
    ) {
        self.year = year
        self.status = status
        self.verifiedOn = verifiedOn
        self.source = source
        self.passengerBands = passengerBands
        self.busCargoBands = busCargoBands
        self.motorcycleRate = motorcycleRate
        self.otherRate = otherRate
        self.fullTaxYears = fullTaxYears
        self.discountStep = discountStep
        self.maxDiscount = maxDiscount
        self.cargoExemptionAge = cargoExemptionAge
        self.communityMaxPercent = communityMaxPercent
        self.evPowerRule = evPowerRule
    }

    /// Articles 242-248, checked on 10 November 2026.
    public static let v2026 = TaxRateSchedule(
        year: 2026,
        status: .verified,
        verifiedOn: "2026-11-10",
        source: "Tax Code of the Republic of Armenia, Articles 242-248",
        passengerBands: [
            TaxRateBand(upperBound: 120, ratePerHorsepower: 200),
            TaxRateBand(
                upperBound: 250,
                ratePerHorsepower: 300,
                extraAbove: 150,
                extraPerHorsepower: 1_000
            ),
            TaxRateBand(
                upperBound: nil,
                ratePerHorsepower: 500,
                extraAbove: 150,
                extraPerHorsepower: 1_000
            )
        ],
        busCargoBands: [
            TaxRateBand(upperBound: 200, ratePerHorsepower: 100),
            TaxRateBand(upperBound: nil, ratePerHorsepower: 200)
        ],
        motorcycleRate: 40,
        otherRate: 150
    )

    public static func projected(year: Int) -> TaxRateSchedule {
        var schedule = v2026
        schedule.year = year
        schedule.status = .projected
        schedule.verifiedOn = nil
        schedule.source = "Projected from the verified 2026 schedule"
        return schedule
    }

    public func band(for horsepower: Double, category: VehicleCategory) -> TaxRateBand {
        switch category {
        case .passenger:
            return Self.band(in: passengerBands, for: horsepower)
        case .bus, .cargo:
            return Self.band(in: busCargoBands, for: horsepower)
        case .motorcycle:
            return TaxRateBand(upperBound: nil, ratePerHorsepower: motorcycleRate)
        case .other:
            return TaxRateBand(upperBound: nil, ratePerHorsepower: otherRate)
        }
    }

    public func validationIssues() -> [TaxRateValidationIssue] {
        var issues: [TaxRateValidationIssue] = []
        if year <= 0 { issues.append(.invalidYear) }
        if passengerBands.isEmpty || busCargoBands.isEmpty { issues.append(.emptyBands) }
        if !Self.bandsAreValid(passengerBands) { issues.append(.invalidPassengerBands) }
        if !Self.bandsAreValid(busCargoBands) { issues.append(.invalidBusCargoBands) }
        if motorcycleRate < 0 || otherRate < 0 { issues.append(.negativeRate) }
        if fullTaxYears < 1 { issues.append(.invalidFullTaxYears) }
        if discountStep < 0 { issues.append(.invalidDiscountStep) }
        if maxDiscount < 0 || maxDiscount > 100 { issues.append(.invalidMaxDiscount) }
        if cargoExemptionAge < 1 { issues.append(.invalidCargoExemptionAge) }
        if communityMaxPercent < 0 || communityMaxPercent > 100 { issues.append(.invalidCommunityMax) }
        if evPowerRule.isEnabled,
           !evPowerRule.threshold.isFinite || !evPowerRule.divisor.isFinite || !evPowerRule.excessDivisor.isFinite
            || evPowerRule.threshold <= 0 || evPowerRule.divisor <= 0 || evPowerRule.excessDivisor <= 0 {
            issues.append(.invalidEVRule)
        }
        return issues
    }

    public var isValid: Bool { validationIssues().isEmpty }

    private static func band(in bands: [TaxRateBand], for horsepower: Double) -> TaxRateBand {
        bands.first { $0.contains(horsepower) }
            ?? bands.last
            ?? TaxRateBand(upperBound: nil, ratePerHorsepower: 0)
    }

    private static func bandsAreValid(_ bands: [TaxRateBand]) -> Bool {
        guard !bands.isEmpty else { return false }
        guard bands.last?.upperBound == nil else { return false }

        var previousUpper: Double = 0
        for (index, band) in bands.enumerated() {
            if band.ratePerHorsepower < 0 { return false }
            if let extra = band.extraPerHorsepower, extra < 0 { return false }
            if let extraAbove = band.extraAbove, !extraAbove.isFinite || extraAbove < 0 { return false }

            if let upper = band.upperBound {
                if !upper.isFinite || upper <= previousUpper { return false }
                if index == bands.count - 1 { return false }
                previousUpper = upper
            } else if index != bands.count - 1 {
                return false
            }
        }
        return true
    }
}

public enum TaxScheduleStore {
    public static let referenceYear = 2026
    public static let firstAvailableYear = 2026
    public static let chartYears = 2026...2030
    /// Beyond this year the app shows the last projected schedule and warns.
    public static let maxProjectedYear = 2035

    /// Returns a schedule for any year. 2026 is verified; later years are
    /// projected until the app ships a verified schedule for them.
    public static func schedule(for year: Int) -> TaxRateSchedule {
        if year == referenceYear {
            return .v2026
        }
        if year > maxProjectedYear {
            return .projected(year: maxProjectedYear)
        }
        if year < firstAvailableYear {
            var schedule = TaxRateSchedule.v2026
            schedule.year = year
            schedule.status = .projected
            schedule.verifiedOn = nil
            schedule.source = "2026 schedule applied to an earlier year"
            return schedule
        }
        return .projected(year: year)
    }

    public static func currentTaxYear(now: Date = .now, calendar: Calendar = .current) -> Int {
        let year = calendar.component(.year, from: now)
        return min(maxProjectedYear, max(firstAvailableYear, year))
    }

    public static func availableYears(now: Date = .now, calendar: Calendar = .current) -> [Int] {
        let current = currentTaxYear(now: now, calendar: calendar)
        let end = min(maxProjectedYear, max(chartYears.upperBound, current))
        return Array(firstAvailableYear...end)
    }

    public static func clampedYear(_ year: Int, now: Date = .now, calendar: Calendar = .current) -> Int {
        let end = availableYears(now: now, calendar: calendar).last ?? firstAvailableYear
        return min(end, max(firstAvailableYear, year))
    }

    /// The persisted year is older than the current calendar year. The UI can
    /// offer an explicit switch instead of silently changing the user's choice.
    public static func suggestsCurrentYear(
        persisted: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        persisted < currentTaxYear(now: now, calendar: calendar)
    }
}
