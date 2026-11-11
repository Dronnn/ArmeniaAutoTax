import Foundation

/// The five vehicle classes supported by the source website.
public enum VehicleCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case passenger = "passenger"
    case bus = "bus"
    case cargo = "cargo"
    case motorcycle = "motorcycle"
    case other = "other"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .passenger: "Легковой · менее 10 мест"
        case .bus: "Пассажирский · 10 и более мест"
        case .cargo: "Грузовой / грузопассажирский"
        case .motorcycle: "Мотоцикл"
        case .other: "Квадроцикл / снегоход / водный"
        }
    }

    public var shortTitle: String {
        switch self {
        case .passenger: "Легковой"
        case .bus: "Автобус"
        case .cargo: "Грузовой"
        case .motorcycle: "Мотоцикл"
        case .other: "Прочий"
        }
    }

    public var symbol: String {
        switch self {
        case .passenger: "car.side.fill"
        case .bus: "bus.fill"
        case .cargo: "truck.box.fill"
        case .motorcycle: "bicycle"
        case .other: "sailboat.fill"
        }
    }

    /// Article 244(4)-(6) applies to motor vehicles, not motorcycles or other vehicles.
    public var isRoadMotorVehicle: Bool {
        switch self {
        case .passenger, .bus, .cargo: true
        case .motorcycle, .other: false
        }
    }
}

public struct Vehicle: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var manufactureYear: Int
    /// Fractional values are allowed for electric vehicles and kW-based documents.
    public var horsepower: Double
    public var category: VehicleCategory
    public var taxableMonths: Int
    public var communitySurchargePercent: Int
    public var powerSource: VehiclePowerSource

    public init(
        id: UUID = UUID(),
        name: String = "",
        manufactureYear: Int = 2019,
        horsepower: Double = 243,
        category: VehicleCategory = .passenger,
        taxableMonths: Int = 12,
        communitySurchargePercent: Int = 0,
        powerSource: VehiclePowerSource = .fuel
    ) {
        self.id = id
        self.name = name
        self.manufactureYear = manufactureYear
        self.horsepower = horsepower
        self.category = category
        self.taxableMonths = taxableMonths
        self.communitySurchargePercent = communitySurchargePercent
        self.powerSource = powerSource
    }

    public var displayName: String {
        let power = horsepower.formatted(.number.precision(.fractionLength(0...2)))
        return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(category.shortTitle) · \(power) л. с."
            : name
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, manufactureYear, horsepower, category
        case taxableMonths, communitySurchargePercent, powerSource
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        manufactureYear = try container.decodeIfPresent(Int.self, forKey: .manufactureYear) ?? 2019
        if let value = try? container.decodeIfPresent(Double.self, forKey: .horsepower) {
            horsepower = value
        } else if let value = try? container.decodeIfPresent(Int.self, forKey: .horsepower) {
            horsepower = Double(value)
        } else {
            horsepower = 0
        }
        category = try container.decodeIfPresent(VehicleCategory.self, forKey: .category) ?? .passenger
        taxableMonths = try container.decodeIfPresent(Int.self, forKey: .taxableMonths) ?? 12
        communitySurchargePercent = try container.decodeIfPresent(Int.self, forKey: .communitySurchargePercent) ?? 0
        powerSource = try container.decodeIfPresent(VehiclePowerSource.self, forKey: .powerSource) ?? .fuel
    }
}

public struct TaxBreakdown: Codable, Equatable, Sendable {
    public let calculationYear: Int
    public let age: Int
    public let rawHorsepower: Double
    public let taxableHorsepower: Double
    public let isElectricAdjusted: Bool
    public let powerSource: VehiclePowerSource
    public let baseRatePerHorsepower: Int
    public let baseAmount: Double
    public let extraAboveHorsepower: Double?
    public let extraRatePerHorsepower: Int?
    public let extraHorsepower: Double
    public let extraAmount: Double
    public let subtotal: Double
    public let ageDiscountPercent: Int
    public let ageDiscountAmount: Double
    public let surchargePercent: Int
    public let surchargeAmount: Double
    public let annualTotal: Double
    public let taxableMonths: Int
    public let periodTotal: Double
    public let isExempt: Bool
    public let rateStatus: TaxRateStatus

    public var averagePerMonth: Double {
        taxableMonths > 0 ? periodTotal / Double(taxableMonths) : 0
    }

    public init(
        calculationYear: Int,
        age: Int,
        rawHorsepower: Double,
        taxableHorsepower: Double,
        isElectricAdjusted: Bool,
        powerSource: VehiclePowerSource,
        baseRatePerHorsepower: Int,
        baseAmount: Double,
        extraAboveHorsepower: Double?,
        extraRatePerHorsepower: Int?,
        extraHorsepower: Double,
        extraAmount: Double,
        subtotal: Double,
        ageDiscountPercent: Int,
        ageDiscountAmount: Double,
        surchargePercent: Int,
        surchargeAmount: Double,
        annualTotal: Double,
        taxableMonths: Int,
        periodTotal: Double,
        isExempt: Bool,
        rateStatus: TaxRateStatus
    ) {
        self.calculationYear = calculationYear
        self.age = age
        self.rawHorsepower = rawHorsepower
        self.taxableHorsepower = taxableHorsepower
        self.isElectricAdjusted = isElectricAdjusted
        self.powerSource = powerSource
        self.baseRatePerHorsepower = baseRatePerHorsepower
        self.baseAmount = baseAmount
        self.extraAboveHorsepower = extraAboveHorsepower
        self.extraRatePerHorsepower = extraRatePerHorsepower
        self.extraHorsepower = extraHorsepower
        self.extraAmount = extraAmount
        self.subtotal = subtotal
        self.ageDiscountPercent = ageDiscountPercent
        self.ageDiscountAmount = ageDiscountAmount
        self.surchargePercent = surchargePercent
        self.surchargeAmount = surchargeAmount
        self.annualTotal = annualTotal
        self.taxableMonths = taxableMonths
        self.periodTotal = periodTotal
        self.isExempt = isExempt
        self.rateStatus = rateStatus
    }

    private enum CodingKeys: String, CodingKey {
        case calculationYear, age, rawHorsepower, taxableHorsepower, isElectricAdjusted
        case powerSource, baseRatePerHorsepower, baseAmount, extraAboveHorsepower
        case extraRatePerHorsepower, extraHorsepower, extraAmount, subtotal, ageDiscountPercent
        case ageDiscountAmount, surchargePercent, surchargeAmount, annualTotal
        case taxableMonths, periodTotal, isExempt, rateStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calculationYear = try container.decode(Int.self, forKey: .calculationYear)
        age = try container.decode(Int.self, forKey: .age)
        baseRatePerHorsepower = try container.decode(Int.self, forKey: .baseRatePerHorsepower)
        baseAmount = try container.decode(Double.self, forKey: .baseAmount)
        extraHorsepower = Self.decodeDouble(container, forKey: .extraHorsepower) ?? 0
        extraAmount = try container.decode(Double.self, forKey: .extraAmount)
        subtotal = try container.decode(Double.self, forKey: .subtotal)
        ageDiscountPercent = try container.decode(Int.self, forKey: .ageDiscountPercent)
        ageDiscountAmount = try container.decode(Double.self, forKey: .ageDiscountAmount)
        surchargePercent = try container.decode(Int.self, forKey: .surchargePercent)
        surchargeAmount = try container.decode(Double.self, forKey: .surchargeAmount)
        annualTotal = try container.decode(Double.self, forKey: .annualTotal)
        taxableMonths = try container.decode(Int.self, forKey: .taxableMonths)
        periodTotal = try container.decode(Double.self, forKey: .periodTotal)
        isExempt = try container.decodeIfPresent(Bool.self, forKey: .isExempt) ?? false
        rateStatus = try container.decodeIfPresent(TaxRateStatus.self, forKey: .rateStatus) ?? .verified
        rawHorsepower = Self.decodeDouble(container, forKey: .rawHorsepower) ?? 0
        taxableHorsepower = Self.decodeDouble(container, forKey: .taxableHorsepower) ?? 0
        isElectricAdjusted = try container.decodeIfPresent(Bool.self, forKey: .isElectricAdjusted) ?? false
        extraAboveHorsepower = Self.decodeDouble(container, forKey: .extraAboveHorsepower)
        extraRatePerHorsepower = try container.decodeIfPresent(Int.self, forKey: .extraRatePerHorsepower)
        powerSource = try container.decodeIfPresent(VehiclePowerSource.self, forKey: .powerSource) ?? .fuel
    }

    private static func decodeDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        return nil
    }
}
