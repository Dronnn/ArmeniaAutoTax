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
        return (AppStore(storageURL: url, defaults: defaults), url, defaults)
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
        let valid: [(Int, Int)] = [(1900, 1), (2026, 10_000), (2019, 243)]
        for (year, horsepower) in valid {
            store.draft.manufactureYear = year
            store.draft.horsepower = horsepower
            XCTAssertTrue(store.validDraft, "\(year), \(horsepower)")
        }
        let invalid: [(Int, Int)] = [(1899, 243), (2027, 243), (2019, 0), (2019, 10_001)]
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
}
