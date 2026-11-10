import Foundation

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: L10n.string("settings.theme.system")
        case .light: L10n.string("settings.theme.light")
        case .dark: L10n.string("settings.theme.dark")
        }
    }
}

struct TaxHistoryEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var timestamp: Date = .now
    var vehicle: Vehicle
    var tax: TaxBreakdown
}

struct ExportArchive: Codable {
    let formatVersion: Int
    let exportedAt: Date
    let garage: [Vehicle]
    let history: [TaxHistoryEntry]
}

@MainActor
final class AppStore: ObservableObject {
    static let appearanceKey = "carTax.appearance"
    static let onboardingKey = "app.onboarding.completed"

    @Published var draft: Vehicle { didSet { persist() } }
    @Published private(set) var garage: [Vehicle]
    @Published private(set) var history: [TaxHistoryEntry]
    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: AppLanguage.storageKey) }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Self.onboardingKey) }
    }

    private let storageURL: URL
    private let defaults: UserDefaults

    init(storageURL: URL? = nil, defaults: UserDefaults = .standard) {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("-ui-testing")
        let testDefaults = isUITesting
            ? UserDefaults(suiteName: "ArmeniaAutoTaxUITests") ?? defaults
            : defaults
        self.defaults = testDefaults
        self.storageURL = storageURL ?? Self.defaultStorageURL(isUITesting: isUITesting)

        if arguments.contains("-reset-state") {
            try? FileManager.default.removeItem(at: self.storageURL)
            Self.clearAppKeys(in: testDefaults)
        }
        if arguments.contains("-reset-language") {
            testDefaults.set(AppLanguage.english.rawValue, forKey: AppLanguage.storageKey)
        }
        if arguments.contains("-reset-onboarding") {
            testDefaults.set(false, forKey: Self.onboardingKey)
        }
        if arguments.contains("-skip-onboarding") {
            testDefaults.set(true, forKey: Self.onboardingKey)
        }

        let persisted = try? Data(contentsOf: self.storageURL)
        let document = persisted.flatMap { try? JSONDecoder().decode(PersistentDocument.self, from: $0) }
        draft = document?.draft ?? Vehicle()
        garage = document?.garage ?? []
        history = document?.history ?? []
        appearance = AppAppearance(rawValue: testDefaults.string(forKey: Self.appearanceKey) ?? "system") ?? .system
        language = AppLanguage(rawValue: testDefaults.string(forKey: AppLanguage.storageKey) ?? "") ?? .english
        hasCompletedOnboarding = testDefaults.bool(forKey: Self.onboardingKey)
    }

    var calculation: TaxBreakdown { TaxCalculator.calculate(draft) }

    func saveVehicle() {
        guard validDraft else { return }
        if let index = garage.firstIndex(where: { $0.id == draft.id }) {
            garage[index] = draft
        } else {
            garage.insert(draft, at: 0)
        }
        persist()
    }

    func removeVehicle(_ id: UUID) {
        garage.removeAll { $0.id == id }
        persist()
    }

    func loadVehicle(_ car: Vehicle) { draft = car }
    func resetDraft() { draft = Vehicle() }

    var validDraft: Bool {
        draft.horsepower > 0 && draft.horsepower <= 10_000 &&
        (1900...TaxCalculator.referenceYear).contains(draft.manufactureYear)
    }

    func recordCalculation() {
        guard validDraft else { return }
        history.insert(TaxHistoryEntry(vehicle: draft, tax: calculation), at: 0)
        // Keep storage bounded while preserving a useful local history.
        if history.count > 500 { history = Array(history.prefix(500)) }
        persist()
    }

    func removeHistory(_ id: UUID) {
        history.removeAll { $0.id == id }
        persist()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func restartOnboarding() {
        hasCompletedOnboarding = false
    }

    /// Produces a UTF-8 JSON backup ready for the native iOS share sheet.
    func exportArchive() -> URL? {
        let archive = ExportArchive(formatVersion: 1, exportedAt: .now, garage: garage, history: history)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(archive) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ArmeniaAutoTax-Backup.json")
        do { try data.write(to: url, options: .atomic); return url }
        catch { return nil }
    }

    private func persist() {
        let doc = PersistentDocument(draft: draft, garage: garage, history: history)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(doc) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private static func defaultStorageURL(isUITesting: Bool) -> URL {
        if isUITesting {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("ArmeniaAutoTaxUITests", isDirectory: true)
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            return root.appendingPathComponent("library.json")
        }
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ArmeniaAutoTax", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("library.json")
    }

    private static func clearAppKeys(in defaults: UserDefaults) {
        defaults.removeObject(forKey: AppLanguage.storageKey)
        defaults.removeObject(forKey: Self.onboardingKey)
        defaults.removeObject(forKey: Self.appearanceKey)
        defaults.removeObject(forKey: "armenianCarTax.exchangeRates.v1")
    }
}

private struct PersistentDocument: Codable {
    var draft: Vehicle
    var garage: [Vehicle]
    var history: [TaxHistoryEntry]
}
