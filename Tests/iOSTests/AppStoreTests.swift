import XCTest
@testable import ArmeniaAutoTax

@MainActor
final class AppStoreTests: XCTestCase {
    private var temporaryDirectories: [URL] = []
    private var suites: [String] = []

    override func tearDown() {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        for suite in suites {
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        temporaryDirectories.removeAll()
        suites.removeAll()
        super.tearDown()
    }

    private func makeStore() throws -> (store: AppStore, url: URL, defaults: UserDefaults) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        let url = directory.appendingPathComponent("library.json")
        let suite = "AppStoreTests-\(UUID().uuidString)"
        suites.append(suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return (AppStore(storageURL: url, defaults: defaults, currentTaxYear: 2026), url, defaults)
    }

    func testDefaultDraftMatchesTheReferenceExample() throws {
        let (store, _, _) = try makeStore()
        XCTAssertEqual(store.draft.manufactureYear, 2019)
        XCTAssertEqual(store.draft.horsepower, 243)
        XCTAssertEqual(store.draft.category, .passenger)
        XCTAssertEqual(store.draft.taxableMonths, 12)
        XCTAssertEqual(store.draft.communitySurchargePercent, 0)
        XCTAssertEqual(store.calculation.periodTotal, 82_950)
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertEqual(store.language, .english)
        XCTAssertEqual(store.appearance, .system)
    }

    func testDraftValidationBoundaries() throws {
        let (store, _, _) = try makeStore()
        let valid: [(Int, Double)] = [(1900, 1), (2026, 10_000), (2019, 243)]
        for (year, horsepower) in valid {
            store.draft.manufactureYear = year
            store.draft.horsepower = horsepower
            XCTAssertTrue(store.validDraft, "\(year), \(horsepower)")
        }
        let invalid: [(Int, Double)] = [(1899, 243), (2027, 243), (2019, 0), (2019, 10_001)]
        for (year, horsepower) in invalid {
            store.draft.manufactureYear = year
            store.draft.horsepower = horsepower
            XCTAssertFalse(store.validDraft, "\(year), \(horsepower)")
        }
    }

    func testSaveVehicleUpsertsAndRemoves() throws {
        let (store, _, _) = try makeStore()
        store.draft.name = "Camry"
        store.saveVehicle()
        XCTAssertEqual(store.garage.count, 1)

        store.draft.name = "Camry updated"
        store.saveVehicle()
        XCTAssertEqual(store.garage.count, 1)
        XCTAssertEqual(store.garage.first?.name, "Camry updated")

        store.resetDraft()
        store.draft.name = "Second car"
        store.saveVehicle()
        XCTAssertEqual(store.garage.count, 2)

        let id = try XCTUnwrap(store.garage.first?.id)
        store.removeVehicle(id)
        XCTAssertEqual(store.garage.count, 1)
    }

    func testInvalidDraftIsNotSavedOrRecorded() throws {
        let (store, _, _) = try makeStore()
        store.draft.horsepower = 0
        store.saveVehicle()
        store.recordCalculation()
        XCTAssertTrue(store.garage.isEmpty)
        XCTAssertTrue(store.history.isEmpty)
    }

    func testHistoryCanBeAddedAndRemoved() throws {
        let (store, _, _) = try makeStore()
        store.recordCalculation()
        store.recordCalculation()
        XCTAssertEqual(store.history.count, 2)
        XCTAssertEqual(store.history.first?.tax.periodTotal, 82_950)
        let id = try XCTUnwrap(store.history.first?.id)
        store.removeHistory(id)
        XCTAssertEqual(store.history.count, 1)
    }

    func testHistoryIsCappedAtFiveHundred() throws {
        let (store, _, _) = try makeStore()
        for _ in 0..<505 { store.recordCalculation() }
        XCTAssertEqual(store.history.count, 500)
    }

    func testPersistenceRoundTrip() throws {
        let (store, url, defaults) = try makeStore()
        store.draft.name = "Persisted"
        store.draft.horsepower = 300
        store.saveVehicle()
        store.recordCalculation()
        store.appearance = .dark
        store.language = .armenian
        store.completeOnboarding()

        let restored = AppStore(storageURL: url, defaults: defaults)
        XCTAssertEqual(restored.draft.name, "Persisted")
        XCTAssertEqual(restored.draft.horsepower, 300)
        XCTAssertEqual(restored.garage.count, 1)
        XCTAssertEqual(restored.history.count, 1)
        XCTAssertEqual(restored.appearance, .dark)
        XCTAssertEqual(restored.language, .armenian)
        XCTAssertTrue(restored.hasCompletedOnboarding)
    }

    func testExportArchiveIsValidJSON() throws {
        let (store, _, _) = try makeStore()
        store.draft.name = "Exported"
        store.saveVehicle()
        store.recordCalculation()

        let url = try XCTUnwrap(store.exportArchive())
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(ExportArchive.self, from: data)
        XCTAssertEqual(archive.formatVersion, 1)
        XCTAssertEqual(archive.garage.count, 1)
        XCTAssertEqual(archive.garage.first?.name, "Exported")
        XCTAssertEqual(archive.history.count, 1)
    }

    func testExportWorksWithEmptyLibrary() throws {
        let (store, _, _) = try makeStore()
        let url = try XCTUnwrap(store.exportArchive())
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(ExportArchive.self, from: data)
        XCTAssertTrue(archive.garage.isEmpty)
        XCTAssertTrue(archive.history.isEmpty)
    }

    func testLoadVehicleAndResetDraft() throws {
        let (store, _, _) = try makeStore()
        let car = Vehicle(name: "Loaded", manufactureYear: 2021, horsepower: 150, category: .bus)
        store.loadVehicle(car)
        XCTAssertEqual(store.draft, car)
        store.resetDraft()
        XCTAssertEqual(store.draft.manufactureYear, 2019)
        XCTAssertEqual(store.draft.horsepower, 243)
        XCTAssertEqual(store.draft.category, .passenger)
        XCTAssertEqual(store.draft.taxableMonths, 12)
        XCTAssertEqual(store.draft.communitySurchargePercent, 0)
        XCTAssertTrue(store.draft.name.isEmpty)
    }

    func testOnboardingCanBeRestarted() throws {
        let (store, _, _) = try makeStore()
        store.completeOnboarding()
        XCTAssertTrue(store.hasCompletedOnboarding)
        store.restartOnboarding()
        XCTAssertFalse(store.hasCompletedOnboarding)
    }

    func testLocalizedDisplayNameUsesTheSelectedLanguage() {
        let car = Vehicle(horsepower: 243)
        XCTAssertEqual(car.localizedDisplayName(language: .english), "Passenger · 243 hp")
        XCTAssertEqual(car.localizedDisplayName(language: .russian), "Легковой · 243 л. с.")
        XCTAssertEqual(car.localizedDisplayName(language: .armenian), "Մարդատար · 243 ձ. ու.")
    }

    func testGarageKeepsNewestFirstAndDeletesOnlySelected() throws {
        let (store, _, _) = try makeStore()
        for name in ["A", "B", "C"] {
            store.draft = Vehicle(name: name)
            store.saveVehicle()
        }
        XCTAssertEqual(store.garage.map(\.name), ["C", "B", "A"])

        let b = try XCTUnwrap(store.garage.first { $0.name == "B" })
        store.removeVehicle(b.id)
        XCTAssertEqual(store.garage.map(\.name), ["C", "A"])
    }

    func testGarageUpsertKeepsPositionAndDoesNotDuplicate() throws {
        let (store, _, _) = try makeStore()
        store.draft = Vehicle(name: "A")
        store.saveVehicle()
        store.draft = Vehicle(name: "B")
        store.saveVehicle()

        let a = try XCTUnwrap(store.garage.first { $0.name == "A" })
        store.loadVehicle(a)
        store.draft.name = "A updated"
        store.saveVehicle()

        XCTAssertEqual(store.garage.count, 2)
        XCTAssertEqual(store.garage.map(\.name), ["B", "A updated"])
    }

    func testGaragePersistsAcrossStoreInstances() throws {
        let (store, url, defaults) = try makeStore()
        store.draft = Vehicle(name: "Persisted car", manufactureYear: 2021, horsepower: 150)
        store.saveVehicle()

        let restored = AppStore(storageURL: url, defaults: defaults)
        XCTAssertEqual(restored.garage.count, 1)
        XCTAssertEqual(restored.garage.first?.name, "Persisted car")
        XCTAssertEqual(restored.garage.first?.manufactureYear, 2021)
        XCTAssertEqual(restored.garage.first?.horsepower, 150)
    }

    func testExportIncludesEveryGarageCar() throws {
        let (store, _, _) = try makeStore()
        store.draft = Vehicle(name: "A")
        store.saveVehicle()
        store.draft = Vehicle(name: "B", category: .cargo)
        store.saveVehicle()

        let url = try XCTUnwrap(store.exportArchive())
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(ExportArchive.self, from: Data(contentsOf: url))
        XCTAssertEqual(archive.garage.count, 2)
        XCTAssertEqual(Set(archive.garage.map(\.name)), ["A", "B"])
    }

    func testDeletingGarageCarKeepsHistory() throws {
        let (store, _, _) = try makeStore()
        store.draft = Vehicle(name: "A")
        store.saveVehicle()
        store.recordCalculation()
        let id = try XCTUnwrap(store.garage.first?.id)

        store.removeVehicle(id)
        XCTAssertTrue(store.garage.isEmpty)
        XCTAssertEqual(store.history.count, 1)
    }

    func testRemovingUnknownVehicleIsANoOp() throws {
        let (store, _, _) = try makeStore()
        store.draft = Vehicle(name: "A")
        store.saveVehicle()

        store.removeVehicle(UUID())
        XCTAssertEqual(store.garage.count, 1)
        XCTAssertEqual(store.garage.first?.name, "A")
    }

    func testLoadingSavedCarReopensItsCalculation() throws {
        let (store, _, _) = try makeStore()
        store.draft = Vehicle(name: "Powerful", manufactureYear: 2019, horsepower: 300)
        store.saveVehicle()
        store.resetDraft()

        let saved = try XCTUnwrap(store.garage.first)
        store.loadVehicle(saved)
        XCTAssertEqual(store.draft.name, "Powerful")
        XCTAssertEqual(store.draft.horsepower, 300)
        XCTAssertEqual(store.calculation.periodTotal, 150_000)
    }

    func testInvalidDraftDoesNotReplaceSavedGarageCar() throws {
        let (store, _, _) = try makeStore()
        store.draft = Vehicle(name: "Valid")
        store.saveVehicle()
        let id = try XCTUnwrap(store.garage.first?.id)

        store.draft = Vehicle(id: id, name: "Invalid", horsepower: 0)
        store.saveVehicle()
        XCTAssertEqual(store.garage.count, 1)
        XCTAssertEqual(store.garage.first?.name, "Valid")
    }

    func testTaxYearDefaultsToTheInjectedCurrentYear() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStoreTaxYear-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        let suite = "AppStoreTaxYear-\(UUID().uuidString)"
        suites.append(suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = AppStore(
            storageURL: directory.appendingPathComponent("library.json"),
            defaults: defaults,
            currentTaxYear: 2027
        )
        XCTAssertEqual(store.taxYear, 2027)
        store.draft.manufactureYear = 2027
        XCTAssertTrue(store.validDraft)
    }

    func testTaxYearPersistsAcrossStoreInstances() throws {
        let (store, url, defaults) = try makeStore()
        store.taxYear = 2028
        store.draft.manufactureYear = 2028
        store.saveVehicle()

        let restored = AppStore(storageURL: url, defaults: defaults, currentTaxYear: 2026)
        XCTAssertEqual(restored.taxYear, 2028)
        XCTAssertEqual(restored.garage.first?.manufactureYear, 2028)
        XCTAssertTrue(restored.validDraft)
    }

    func testTaxYearControlsTheAgeDiscount() throws {
        let (store, _, _) = try makeStore()
        store.draft = Vehicle(manufactureYear: 2020, horsepower: 243)

        store.taxYear = 2026
        XCTAssertEqual(store.calculation.annualTotal, 99_540)

        store.taxYear = 2027
        XCTAssertEqual(store.calculation.annualTotal, 82_950)
        XCTAssertEqual(store.calculation.calculationYear, 2027)
        XCTAssertEqual(store.calculation.rateStatus, .projected)
    }

    func testDraftValidationUsesTheSelectedTaxYear() throws {
        let (store, _, _) = try makeStore()
        store.draft = Vehicle(manufactureYear: 2027, horsepower: 150)

        store.taxYear = 2026
        XCTAssertFalse(store.validDraft)

        store.taxYear = 2027
        XCTAssertTrue(store.validDraft)
    }

    func testRecordCalculationAcceptsAnExplicitBreakdown() throws {
        let (store, _, _) = try makeStore()
        let customSchedule = TaxRateSchedule.projected(year: 2026)
        let tax = TaxCalculator.calculate(store.draft, year: 2026, schedule: customSchedule)
        store.recordCalculation(tax)

        XCTAssertEqual(store.history.count, 1)
        XCTAssertEqual(store.history.first?.tax, tax)
    }

    func testOldVehicleJSONWithoutPowerSourceDecodesAsFuel() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "Legacy",
          "manufactureYear": 2019,
          "horsepower": 243,
          "category": "passenger",
          "taxableMonths": 12,
          "communitySurchargePercent": 0
        }
        """
        let vehicle = try JSONDecoder().decode(Vehicle.self, from: Data(json.utf8))
        XCTAssertEqual(vehicle.horsepower, 243)
        XCTAssertEqual(vehicle.powerSource, .fuel)
    }

    func testOldPersistentDocumentWithoutTaxYearDecodes() throws {
        let (store, url, defaults) = try makeStore()
        store.draft = Vehicle(name: "Legacy")
        store.saveVehicle()

        let data = try Data(contentsOf: url)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "taxYear")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        try legacyData.write(to: url)

        let restored = AppStore(storageURL: url, defaults: defaults, currentTaxYear: 2026)
        XCTAssertEqual(restored.taxYear, 2026)
        XCTAssertEqual(restored.garage.first?.name, "Legacy")
    }

    func testOldTaxBreakdownWithoutNewFieldsDecodes() throws {
        let json = """
        {
          "calculationYear": 2026,
          "age": 7,
          "baseRatePerHorsepower": 300,
          "baseAmount": 72900,
          "extraHorsepower": 93,
          "extraAmount": 93000,
          "subtotal": 165900,
          "ageDiscountPercent": 50,
          "ageDiscountAmount": 82950,
          "surchargePercent": 0,
          "surchargeAmount": 0,
          "annualTotal": 82950,
          "taxableMonths": 12,
          "periodTotal": 82950,
          "isExempt": false
        }
        """
        let tax = try JSONDecoder().decode(TaxBreakdown.self, from: Data(json.utf8))
        XCTAssertEqual(tax.periodTotal, 82_950)
        XCTAssertEqual(tax.extraHorsepower, 93)
        XCTAssertEqual(tax.rateStatus, .verified)
        XCTAssertEqual(tax.powerSource, .fuel)
        XCTAssertFalse(tax.isElectricAdjusted)
        XCTAssertNil(tax.extraRatePerHorsepower)
    }
}
