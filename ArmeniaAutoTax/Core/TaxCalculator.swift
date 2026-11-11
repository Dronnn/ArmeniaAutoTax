import Foundation

/// Republic of Armenia vehicle property tax, Tax Code Articles 242-248.
///
/// All rates, bands, age rules and the EV power rule come from a
/// `TaxRateSchedule`. The 2026 schedule is verified; later years are
/// projected until a future version ships a verified schedule.
public enum TaxCalculator {
    public static let referenceYear = TaxScheduleStore.referenceYear

    public static func calculate(_ vehicle: Vehicle, year: Int = referenceYear) -> TaxBreakdown {
        calculate(vehicle, year: year, schedule: TaxScheduleStore.schedule(for: year))
    }

    public static func calculate(
        _ vehicle: Vehicle,
        year: Int,
        schedule: TaxRateSchedule
    ) -> TaxBreakdown {
        let rawPower = sanitized(vehicle.horsepower)
        let taxablePower = taxablePower(for: vehicle, schedule: schedule)
        let band = schedule.band(for: taxablePower, category: vehicle.category)
        let rate = band.ratePerHorsepower
        let base = taxablePower * Double(rate)

        let extraAbove = band.extraAbove
        let extraRate = band.extraPerHorsepower ?? 0
        let extraHorsepower: Double
        if let extraAbove, extraRate > 0 {
            extraHorsepower = max(0, taxablePower - extraAbove)
        } else {
            extraHorsepower = 0
        }
        let extra = extraHorsepower * Double(extraRate)
        let subtotal = base + extra

        let age = max(0, year - vehicle.manufactureYear)
        let discount: Int
        if vehicle.category.isRoadMotorVehicle {
            let steps = max(0, age - schedule.fullTaxYears + 1)
            let maximumDiscount = max(0, min(100, schedule.maxDiscount))
            discount = max(0, min(maximumDiscount, steps * schedule.discountStep))
        } else {
            discount = 0
        }

        let exempt = vehicle.category == .cargo && age >= schedule.cargoExemptionAge
        let discountAmount = exempt ? 0 : subtotal * Double(discount) / 100
        let discounted = exempt ? 0 : subtotal - discountAmount

        let maximumCommunityPercent = max(0, min(100, schedule.communityMaxPercent))
        let communityPercent = max(0, min(maximumCommunityPercent, vehicle.communitySurchargePercent))
        let surcharge = discounted * Double(communityPercent) / 100
        let annualTotal = discounted + surcharge
        let months = min(12, max(0, vehicle.taxableMonths))
        let periodTotal = annualTotal * Double(months) / 12

        let adjusted = vehicle.powerSource.appliesEVRule
            && schedule.evPowerRule.isEnabled
            && rawPower > 0
            && abs(taxablePower - rawPower) > 0.000_000_1

        return TaxBreakdown(
            calculationYear: year,
            age: age,
            rawHorsepower: rawPower,
            taxableHorsepower: taxablePower,
            isElectricAdjusted: adjusted,
            powerSource: vehicle.powerSource,
            baseRatePerHorsepower: rate,
            baseAmount: base,
            extraAboveHorsepower: extraAbove,
            extraRatePerHorsepower: band.extraPerHorsepower,
            extraHorsepower: extraHorsepower,
            extraAmount: extra,
            subtotal: subtotal,
            ageDiscountPercent: discount,
            ageDiscountAmount: discountAmount,
            surchargePercent: communityPercent,
            surchargeAmount: surcharge,
            annualTotal: annualTotal,
            taxableMonths: months,
            periodTotal: periodTotal,
            isExempt: exempt,
            rateStatus: schedule.status
        )
    }

    /// Power actually used for the Article 244 bands.
    public static func taxablePower(for vehicle: Vehicle, schedule: TaxRateSchedule) -> Double {
        let rawPower = sanitized(vehicle.horsepower)
        guard vehicle.powerSource.appliesEVRule else { return rawPower }
        return sanitized(schedule.evPowerRule.taxablePower(from: rawPower))
    }

    /// Inverse of `taxablePower(for:)`, used by charts to keep the statutory
    /// thresholds on the taxable-power axis.
    public static func rawPower(
        forTaxable taxablePower: Double,
        vehicle: Vehicle,
        schedule: TaxRateSchedule
    ) -> Double {
        guard vehicle.powerSource.appliesEVRule else { return sanitized(taxablePower) }
        return sanitized(schedule.evPowerRule.rawPower(forTaxable: taxablePower))
    }

    private static func sanitized(_ value: Double) -> Double {
        value.isFinite ? max(0, value) : 0
    }
}
