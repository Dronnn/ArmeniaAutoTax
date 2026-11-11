import Foundation

/// Per-year custom rate overrides. Built-in schedules are never modified;
/// a reset simply removes the override and falls back to the official value.
@MainActor
final class TaxRatesStore: ObservableObject {
    static let storageKey = "carTax.rateOverrides.v1"

    @Published private(set) var overrides: [Int: TaxRateSchedule] = [:]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppLanguage.defaults) {
        self.defaults = defaults
        load()
    }

    var hasCustomRates: Bool { !overrides.isEmpty }

    var customYears: [Int] { overrides.keys.sorted() }

    func schedule(for year: Int) -> TaxRateSchedule {
        if var custom = overrides[year] {
            custom.year = year
            return custom
        }
        return TaxScheduleStore.schedule(for: year)
    }

    func defaultSchedule(for year: Int) -> TaxRateSchedule {
        TaxScheduleStore.schedule(for: year)
    }

    func isCustomized(_ year: Int) -> Bool {
        overrides[year] != nil
    }

    func status(for year: Int) -> TaxRateStatus {
        schedule(for: year).status
    }

    func save(_ schedule: TaxRateSchedule) {
        guard schedule.isValid else { return }
        var custom = schedule
        custom.status = .custom
        custom.verifiedOn = nil
        custom.source = "Manual override"
        overrides[custom.year] = custom
        persist()
    }

    func reset(_ year: Int) {
        guard overrides.removeValue(forKey: year) != nil else { return }
        persist()
    }

    func resetAll() {
        guard !overrides.isEmpty else { return }
        overrides.removeAll()
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let schedules = try? JSONDecoder().decode([TaxRateSchedule].self, from: data)
        else { return }

        var loaded: [Int: TaxRateSchedule] = [:]
        for schedule in schedules where schedule.year > 0 && schedule.isValid {
            loaded[schedule.year] = schedule
        }
        overrides = loaded
    }

    private func persist() {
        let schedules = overrides.values.sorted { $0.year < $1.year }
        guard let data = try? JSONEncoder().encode(schedules) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

/// String-backed draft used by the manual rate editor. It supports the
/// standard three passenger bands and two bus/cargo bands; all other rules
/// are scalar values.
struct TaxRateEditorDraft: Equatable {
    var passenger1Max: String
    var passenger1Rate: String
    var passenger2Max: String
    var passenger2Rate: String
    var passenger3Rate: String
    var extraAbove: String
    var extraRate: String
    var busCargo1Max: String
    var busCargo1Rate: String
    var busCargo2Rate: String
    var motorcycleRate: String
    var otherRate: String
    var fullTaxYears: String
    var discountStep: String
    var maxDiscount: String
    var cargoExemptionAge: String
    var communityMax: String
    var evEnabled: Bool
    var evThreshold: String
    var evDivisor: String
    var evExcessDivisor: String

    init(schedule: TaxRateSchedule) {
        let passenger = Self.normalizedPassengerBands(schedule.passengerBands)
        let busCargo = Self.normalizedBusCargoBands(schedule.busCargoBands)
        let extraBand = passenger[1]

        passenger1Max = Self.text(passenger[0].upperBound ?? 120)
        passenger1Rate = String(passenger[0].ratePerHorsepower)
        passenger2Max = Self.text(passenger[1].upperBound ?? 250)
        passenger2Rate = String(passenger[1].ratePerHorsepower)
        passenger3Rate = String(passenger[2].ratePerHorsepower)
        extraAbove = Self.text(extraBand.extraAbove ?? 150)
        extraRate = String(extraBand.extraPerHorsepower ?? 1_000)
        busCargo1Max = Self.text(busCargo[0].upperBound ?? 200)
        busCargo1Rate = String(busCargo[0].ratePerHorsepower)
        busCargo2Rate = String(busCargo[1].ratePerHorsepower)
        motorcycleRate = String(schedule.motorcycleRate)
        otherRate = String(schedule.otherRate)
        fullTaxYears = String(schedule.fullTaxYears)
        discountStep = String(schedule.discountStep)
        maxDiscount = String(schedule.maxDiscount)
        cargoExemptionAge = String(schedule.cargoExemptionAge)
        communityMax = String(schedule.communityMaxPercent)
        evEnabled = schedule.evPowerRule.isEnabled
        evThreshold = Self.text(schedule.evPowerRule.threshold)
        evDivisor = Self.text(schedule.evPowerRule.divisor)
        evExcessDivisor = Self.text(schedule.evPowerRule.excessDivisor)
    }

    func makeSchedule(
        year: Int,
        status: TaxRateStatus = .custom,
        verifiedOn: String? = nil,
        source: String? = nil
    ) -> TaxRateSchedule? {
        guard
            let passenger1Max = Self.double(passenger1Max),
            let passenger1Rate = Self.int(passenger1Rate),
            let passenger2Max = Self.double(passenger2Max),
            let passenger2Rate = Self.int(passenger2Rate),
            let passenger3Rate = Self.int(passenger3Rate),
            let extraAbove = Self.double(extraAbove),
            let extraRate = Self.int(extraRate),
            let busCargo1Max = Self.double(busCargo1Max),
            let busCargo1Rate = Self.int(busCargo1Rate),
            let busCargo2Rate = Self.int(busCargo2Rate),
            let motorcycleRate = Self.int(motorcycleRate),
            let otherRate = Self.int(otherRate),
            let fullTaxYears = Self.int(fullTaxYears),
            let discountStep = Self.int(discountStep),
            let maxDiscount = Self.int(maxDiscount),
            let cargoExemptionAge = Self.int(cargoExemptionAge),
            let communityMax = Self.int(communityMax),
            let evThreshold = Self.double(evThreshold),
            let evDivisor = Self.double(evDivisor),
            let evExcessDivisor = Self.double(evExcessDivisor)
        else { return nil }

        return TaxRateSchedule(
            year: year,
            status: status,
            verifiedOn: verifiedOn,
            source: source,
            passengerBands: [
                TaxRateBand(upperBound: passenger1Max, ratePerHorsepower: passenger1Rate),
                TaxRateBand(
                    upperBound: passenger2Max,
                    ratePerHorsepower: passenger2Rate,
                    extraAbove: extraAbove,
                    extraPerHorsepower: extraRate
                ),
                TaxRateBand(
                    upperBound: nil,
                    ratePerHorsepower: passenger3Rate,
                    extraAbove: extraAbove,
                    extraPerHorsepower: extraRate
                )
            ],
            busCargoBands: [
                TaxRateBand(upperBound: busCargo1Max, ratePerHorsepower: busCargo1Rate),
                TaxRateBand(upperBound: nil, ratePerHorsepower: busCargo2Rate)
            ],
            motorcycleRate: motorcycleRate,
            otherRate: otherRate,
            fullTaxYears: fullTaxYears,
            discountStep: discountStep,
            maxDiscount: maxDiscount,
            cargoExemptionAge: cargoExemptionAge,
            communityMaxPercent: communityMax,
            evPowerRule: EVPowerRule(
                isEnabled: evEnabled,
                threshold: evThreshold,
                divisor: evDivisor,
                excessDivisor: evExcessDivisor
            )
        )
    }

    var validationIssues: [TaxRateValidationIssue] {
        guard let schedule = makeSchedule(year: TaxScheduleStore.referenceYear) else {
            return [.invalidNumber]
        }
        return schedule.validationIssues()
    }

    var isValid: Bool { validationIssues.isEmpty }

    var previewAnnualTax: Double? {
        guard let schedule = makeSchedule(year: TaxScheduleStore.referenceYear) else { return nil }
        let sample = Vehicle(manufactureYear: 2019, horsepower: 243)
        return TaxCalculator.calculate(sample, year: schedule.year, schedule: schedule).annualTotal
    }

    private static func normalizedPassengerBands(_ bands: [TaxRateBand]) -> [TaxRateBand] {
        var result = bands
        while result.count < 3 {
            result.append(TaxRateBand(upperBound: nil, ratePerHorsepower: result.last?.ratePerHorsepower ?? 0))
        }
        while result.count > 3 {
            result.removeLast()
        }
        result[2].upperBound = nil
        return result
    }

    private static func normalizedBusCargoBands(_ bands: [TaxRateBand]) -> [TaxRateBand] {
        var result = bands
        while result.count < 2 {
            result.append(TaxRateBand(upperBound: nil, ratePerHorsepower: result.last?.ratePerHorsepower ?? 0))
        }
        while result.count > 2 {
            result.removeLast()
        }
        result[1].upperBound = nil
        return result
    }

    private static func text(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func double(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    private static func int(_ text: String) -> Int? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        if let value = Int(normalized) { return value }
        if let value = Double(normalized), value.isFinite, value.rounded() == value {
            return Int(value)
        }
        return nil
    }
}
