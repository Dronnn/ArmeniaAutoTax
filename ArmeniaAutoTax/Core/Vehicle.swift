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
    public var horsepower: Int
    public var category: VehicleCategory
    public var taxableMonths: Int
    public var communitySurchargePercent: Int

    public init(
        id: UUID = UUID(),
        name: String = "",
        manufactureYear: Int = 2019,
        horsepower: Int = 243,
        category: VehicleCategory = .passenger,
        taxableMonths: Int = 12,
        communitySurchargePercent: Int = 0
    ) {
        self.id = id
        self.name = name
        self.manufactureYear = manufactureYear
        self.horsepower = horsepower
        self.category = category
        self.taxableMonths = taxableMonths
        self.communitySurchargePercent = communitySurchargePercent
    }

    public var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(category.shortTitle) · \(horsepower) л. с."
            : name
    }
}

public struct TaxBreakdown: Codable, Equatable, Sendable {
    public let calculationYear: Int
    public let age: Int
    public let baseRatePerHorsepower: Int
    public let baseAmount: Double
    public let extraHorsepower: Int
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

    public var averagePerMonth: Double { annualTotal / 12 }
}
