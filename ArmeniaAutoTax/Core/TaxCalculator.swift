import Foundation

/// Republic of Armenia vehicle property tax, Tax Code Articles 242–248.
///
/// The reference site uses the 2026 rules. Forecasts for later years hold the
/// same rates constant, changing only the age-related reduction.
public enum TaxCalculator {
    public static let referenceYear = 2026

    public static func calculate(_ vehicle: Vehicle, year: Int = referenceYear) -> TaxBreakdown {
        let power = max(0, vehicle.horsepower)
        let age = max(0, year - vehicle.manufactureYear)
        let months = min(12, max(1, vehicle.taxableMonths))
        let communityPercent = min(10, max(0, vehicle.communitySurchargePercent))
        let rate: Int
        let extraHorsepower: Int

        switch vehicle.category {
        case .passenger:
            rate = power <= 120 ? 200 : (power <= 250 ? 300 : 500)
            extraHorsepower = max(0, power - 150)
        case .bus, .cargo:
            rate = power <= 200 ? 100 : 200
            extraHorsepower = 0
        case .motorcycle:
            rate = 40
            extraHorsepower = 0
        case .other:
            rate = 150
            extraHorsepower = 0
        }

        let base = Double(power * rate)
        let extra = Double(extraHorsepower * 1_000)
        let subtotal = base + extra
        let discount = vehicle.category.isRoadMotorVehicle
            ? min(50, max(0, (age - 2) * 10)) : 0
        let exempt = vehicle.category == .cargo && age >= 20
        let discountAmount = exempt ? 0 : subtotal * Double(discount) / 100
        let discounted = exempt ? 0 : subtotal - discountAmount
        // Rate increases authorized by the municipality are applied to the
        // amount after the age reduction, preserving the same effective rate.
        let surcharge = discounted * Double(communityPercent) / 100
        let annual = discounted + surcharge
        let period = annual * Double(months) / 12

        return TaxBreakdown(
            calculationYear: year,
            age: age,
            baseRatePerHorsepower: rate,
            baseAmount: base,
            extraHorsepower: extraHorsepower,
            extraAmount: extra,
            subtotal: subtotal,
            ageDiscountPercent: discount,
            ageDiscountAmount: discountAmount,
            surchargePercent: communityPercent,
            surchargeAmount: surcharge,
            annualTotal: annual,
            taxableMonths: months,
            periodTotal: period,
            isExempt: exempt
        )
    }
}
