import XCTest
@testable import ArmeniaAutoTax

@MainActor
final class TaxRatesStoreTests: XCTestCase {
    private var suites: [String] = []

    override func tearDown() {
        for suite in suites {
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        suites.removeAll()
        super.tearDown()
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "TaxRatesStoreTests-\(UUID().uuidString)"
        suites.append(suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeStore() throws -> (TaxRatesStore, UserDefaults) {
        let defaults = try makeDefaults()
        return (TaxRatesStore(defaults: defaults), defaults)
    }

    func testDefaultsAreTheBuiltInSchedule() {
        let store = TaxRatesStore(defaults: try! makeDefaults())
        XCTAssertFalse(store.hasCustomRates)
        XCTAssertEqual(store.schedule(for: 2026), .v2026)
        XCTAssertEqual(store.schedule(for: 2027).status, .projected)
        XCTAssertEqual(store.status(for: 2026), .verified)
        XCTAssertEqual(store.status(for: 2027), .projected)
    }

    func testSaveOverridePersistsAndSurvivesReload() throws {
        let (store, defaults) = try makeStore()
        var custom = TaxRateSchedule.v2026
        custom.passengerBands[2].ratePerHorsepower = 600
        store.save(custom)

        XCTAssertTrue(store.hasCustomRates)
        XCTAssertEqual(store.customYears, [2026])
        XCTAssertEqual(store.schedule(for: 2026).status, .custom)
        XCTAssertEqual(store.schedule(for: 2026).passengerBands[2].ratePerHorsepower, 600)
        XCTAssertNil(store.schedule(for: 2026).verifiedOn)

        let reloaded = TaxRatesStore(defaults: defaults)
        XCTAssertEqual(reloaded.schedule(for: 2026).status, .custom)
        XCTAssertEqual(reloaded.schedule(for: 2026).passengerBands[2].ratePerHorsepower, 600)
    }

    func testResetYearRestoresTheBuiltInSchedule() throws {
        let (store, defaults) = try makeStore()
        var custom = TaxRateSchedule.v2026
        custom.passengerBands[0].ratePerHorsepower = 250
        store.save(custom)
        store.reset(2026)

        XCTAssertFalse(store.hasCustomRates)
        XCTAssertEqual(store.schedule(for: 2026), .v2026)
        XCTAssertEqual(TaxRatesStore(defaults: defaults).schedule(for: 2026), .v2026)
    }

    func testResetAllClearsEveryYear() throws {
        let (store, defaults) = try makeStore()
        store.save(TaxRateSchedule.projected(year: 2027))
        store.save(TaxRateSchedule.projected(year: 2028))
        XCTAssertEqual(store.customYears, [2027, 2028])

        store.resetAll()
        XCTAssertFalse(store.hasCustomRates)
        XCTAssertEqual(store.schedule(for: 2027).status, .projected)
        XCTAssertEqual(TaxRatesStore(defaults: defaults).customYears, [])
    }

    func testInvalidStoredOverrideIsIgnored() throws {
        let defaults = try makeDefaults()
        var invalid = TaxRateSchedule.v2026
        invalid.passengerBands[1].upperBound = 100
        let data = try JSONEncoder().encode([invalid])
        defaults.set(data, forKey: TaxRatesStore.storageKey)

        let store = TaxRatesStore(defaults: defaults)
        XCTAssertFalse(store.hasCustomRates)
        XCTAssertEqual(store.schedule(for: 2026), .v2026)
    }

    func testCorruptStorageIsIgnored() throws {
        let defaults = try makeDefaults()
        defaults.set(Data("not json".utf8), forKey: TaxRatesStore.storageKey)
        let store = TaxRatesStore(defaults: defaults)
        XCTAssertFalse(store.hasCustomRates)
    }

    func testDraftRoundTripsTheDefaultSchedule() throws {
        let draft = TaxRateEditorDraft(schedule: .v2026)
        let schedule = try XCTUnwrap(draft.makeSchedule(year: 2026))
        XCTAssertTrue(draft.isValid)
        XCTAssertEqual(schedule.passengerBands, TaxRateSchedule.v2026.passengerBands)
        XCTAssertEqual(schedule.busCargoBands, TaxRateSchedule.v2026.busCargoBands)
        XCTAssertEqual(schedule.motorcycleRate, 40)
        XCTAssertEqual(schedule.otherRate, 150)
        XCTAssertEqual(schedule.fullTaxYears, 3)
        XCTAssertEqual(schedule.discountStep, 10)
        XCTAssertEqual(schedule.maxDiscount, 50)
        XCTAssertEqual(schedule.cargoExemptionAge, 20)
        XCTAssertEqual(schedule.communityMaxPercent, 10)
        XCTAssertEqual(schedule.evPowerRule, .v2026)
    }

    func testDraftPreviewUsesTheGoldenExample() {
        let draft = TaxRateEditorDraft(schedule: .v2026)
        XCTAssertEqual(draft.previewAnnualTax, 82_950)
    }

    func testDraftAcceptsCommaDecimalSeparator() throws {
        var draft = TaxRateEditorDraft(schedule: .v2026)
        draft.evDivisor = "1,5"
        draft.passenger1Max = "120,5"
        XCTAssertTrue(draft.isValid)
        let schedule = try XCTUnwrap(draft.makeSchedule(year: 2026))
        XCTAssertEqual(schedule.evPowerRule.divisor, 1.5)
        XCTAssertEqual(schedule.passengerBands[0].upperBound, 120.5)
    }

    func testDraftRejectsUnparseableValues() {
        var draft = TaxRateEditorDraft(schedule: .v2026)
        draft.passenger1Rate = ""
        XCTAssertEqual(draft.validationIssues, [.invalidNumber])
        XCTAssertFalse(draft.isValid)
        XCTAssertNil(draft.makeSchedule(year: 2026))
    }

    func testDraftRejectsNonIncreasingBands() {
        var draft = TaxRateEditorDraft(schedule: .v2026)
        draft.passenger2Max = "100"
        XCTAssertTrue(draft.validationIssues.contains(.invalidPassengerBands))
        XCTAssertFalse(draft.isValid)
    }

    func testDraftRejectsNegativeRate() {
        var draft = TaxRateEditorDraft(schedule: .v2026)
        draft.passenger1Rate = "-1"
        XCTAssertTrue(draft.validationIssues.contains(.invalidPassengerBands))
    }

    func testDraftRejectsInvalidAgeRules() {
        var draft = TaxRateEditorDraft(schedule: .v2026)
        draft.fullTaxYears = "0"
        XCTAssertTrue(draft.validationIssues.contains(.invalidFullTaxYears))

        draft = TaxRateEditorDraft(schedule: .v2026)
        draft.discountStep = "-1"
        XCTAssertTrue(draft.validationIssues.contains(.invalidDiscountStep))

        draft = TaxRateEditorDraft(schedule: .v2026)
        draft.maxDiscount = "101"
        XCTAssertTrue(draft.validationIssues.contains(.invalidMaxDiscount))

        draft = TaxRateEditorDraft(schedule: .v2026)
        draft.cargoExemptionAge = "0"
        XCTAssertTrue(draft.validationIssues.contains(.invalidCargoExemptionAge))

        draft = TaxRateEditorDraft(schedule: .v2026)
        draft.communityMax = "101"
        XCTAssertTrue(draft.validationIssues.contains(.invalidCommunityMax))
    }

    func testDraftRejectsInvalidBusCargoBands() {
        var draft = TaxRateEditorDraft(schedule: .v2026)
        draft.busCargo1Max = "0"
        XCTAssertTrue(draft.validationIssues.contains(.invalidBusCargoBands))
    }

    func testDraftRoundTripsAdvancedRules() throws {
        var draft = TaxRateEditorDraft(schedule: .v2026)
        draft.fullTaxYears = "2"
        draft.discountStep = "5"
        draft.maxDiscount = "40"
        draft.cargoExemptionAge = "15"
        draft.communityMax = "7"
        draft.evThreshold = "200"
        draft.evDivisor = "1.4"
        draft.evExcessDivisor = "2.4"

        let schedule = try XCTUnwrap(draft.makeSchedule(year: 2027))
        XCTAssertEqual(schedule.fullTaxYears, 2)
        XCTAssertEqual(schedule.discountStep, 5)
        XCTAssertEqual(schedule.maxDiscount, 40)
        XCTAssertEqual(schedule.cargoExemptionAge, 15)
        XCTAssertEqual(schedule.communityMaxPercent, 7)
        XCTAssertEqual(schedule.evPowerRule.threshold, 200)
        XCTAssertEqual(schedule.evPowerRule.divisor, 1.4)
        XCTAssertEqual(schedule.evPowerRule.excessDivisor, 2.4)
        XCTAssertTrue(schedule.isValid)
    }

    func testDraftRejectsInvalidEVRule() {
        var draft = TaxRateEditorDraft(schedule: .v2026)
        draft.evDivisor = "0"
        XCTAssertTrue(draft.validationIssues.contains(.invalidEVRule))

        draft = TaxRateEditorDraft(schedule: .v2026)
        draft.evThreshold = "0"
        XCTAssertTrue(draft.validationIssues.contains(.invalidEVRule))

        draft = TaxRateEditorDraft(schedule: .v2026)
        draft.evExcessDivisor = "0"
        XCTAssertTrue(draft.validationIssues.contains(.invalidEVRule))
    }

    func testDraftCanDisableEVRule() throws {
        var draft = TaxRateEditorDraft(schedule: .v2026)
        draft.evEnabled = false
        let schedule = try XCTUnwrap(draft.makeSchedule(year: 2026))
        XCTAssertFalse(schedule.evPowerRule.isEnabled)
        XCTAssertTrue(schedule.isValid)
    }

    func testCustomScheduleChangesTheCalculatedAmount() {
        let (store, _) = try! makeStore()
        var custom = TaxRateSchedule.v2026
        custom.passengerBands[2].ratePerHorsepower = 600
        custom.passengerBands[2].extraPerHorsepower = 0
        store.save(custom)

        let car = Vehicle(manufactureYear: 2019, horsepower: 251)
        let tax = TaxCalculator.calculate(car, year: 2026, schedule: store.schedule(for: 2026))
        XCTAssertEqual(tax.annualTotal, 75_300)
        XCTAssertEqual(tax.rateStatus, .custom)
    }

    func testSaveRejectsAnInvalidSchedule() throws {
        let (store, _) = try makeStore()
        var invalid = TaxRateSchedule.v2026
        invalid.passengerBands = []
        store.save(invalid)
        XCTAssertFalse(store.hasCustomRates)
    }

    func testSaveNormalizesTheStatusAndSource() throws {
        let (store, _) = try makeStore()
        var schedule = TaxRateSchedule.projected(year: 2027)
        schedule.status = .verified
        schedule.verifiedOn = "2099-01-01"
        store.save(schedule)

        let saved = store.schedule(for: 2027)
        XCTAssertEqual(saved.status, .custom)
        XCTAssertNil(saved.verifiedOn)
        XCTAssertEqual(saved.source, "Manual override")
    }
}
