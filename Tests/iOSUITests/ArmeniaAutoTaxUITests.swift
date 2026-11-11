import XCTest

final class ArmeniaAutoTaxUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(
        skipOnboarding: Bool = true,
        resetOnboarding: Bool = false,
        resetState: Bool = true
    ) {
        app.launchArguments = ["-ui-testing", "-reset-language"]
        if resetState { app.launchArguments.append("-reset-state") }
        if skipOnboarding { app.launchArguments.append("-skip-onboarding") }
        if resetOnboarding { app.launchArguments.append("-reset-onboarding") }
        app.launch()
    }

    private func tab(_ title: String) -> XCUIElement {
        app.tabBars.buttons
            .containing(NSPredicate(format: "label CONTAINS %@", title))
            .firstMatch
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<6 where !element.isHittable {
            app.swipeUp()
        }
    }

    func testMainTabsAndDefaultCalculation() {
        launch()
        XCTAssertTrue(tab("Calculator").waitForExistence(timeout: 10))
        XCTAssertTrue(tab("Garage").exists)
        XCTAssertTrue(tab("How we calculate").exists)
        XCTAssertTrue(tab("Settings").exists)
        XCTAssertTrue(tab("Donations").exists)

        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Less uncertainty'")
        ).firstMatch.exists)

        let amount = app.staticTexts["calculator.result.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10))
        XCTAssertTrue(amount.label.contains("82,950"), "Unexpected amount: \(amount.label)")
    }

    func testChangingHorsepowerUpdatesResult() {
        launch()
        let field = app.textFields["calculator.horsepower"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        field.typeText("300")

        let amount = app.staticTexts["calculator.result.amount"]
        let predicate = NSPredicate(format: "label CONTAINS '150,000'")
        expectation(for: predicate, evaluatedWith: amount)
        waitForExpectations(timeout: 5)
    }

    func testSettingsChangesLanguageAndTheme() {
        launch()
        tab("Settings").tap()
        XCTAssertTrue(app.staticTexts["settings.language.ru"].exists || app.buttons["settings.language.ru"].exists)

        let russian = app.buttons["settings.language.ru"]
        scrollTo(russian)
        XCTAssertTrue(russian.waitForExistence(timeout: 5))
        russian.tap()
        XCTAssertTrue(tab("Калькулятор").waitForExistence(timeout: 5))

        let dark = app.segmentedControls.buttons["Тёмная"]
        scrollTo(dark)
        XCTAssertTrue(dark.waitForExistence(timeout: 5))
        dark.tap()
        XCTAssertTrue(dark.isSelected)
    }

    func testGarageRulesAndDonationsTabs() {
        launch()
        tab("Garage").tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Your garage starts here'")
        ).firstMatch.waitForExistence(timeout: 5))

        tab("How we calculate").tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Where the numbers come from'")
        ).firstMatch.waitForExistence(timeout: 5))

        tab("Donations").tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Keep Armenia Auto Tax independent'")
        ).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["donations.tier.small"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["donations.tier.medium"].exists)
        XCTAssertTrue(app.buttons["donations.tier.extraordinary"].exists)
        XCTAssertTrue(app.buttons["donations.donate"].exists)
    }

    private func saveCurrentVehicle() {
        let save = app.buttons["calculator.saveVehicle"]
        scrollTo(save)
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["OK"].tap()
    }

    func testGarageAddOpenAndDelete() {
        launch()
        saveCurrentVehicle()

        tab("Garage").tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Passenger · 243 hp'")
        ).firstMatch.waitForExistence(timeout: 5))

        let open = app.buttons["garage.open"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(tab("Calculator").isSelected)
        XCTAssertTrue(app.staticTexts["calculator.result.amount"].waitForExistence(timeout: 5))

        tab("Garage").tap()
        let delete = app.buttons["garage.delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssertTrue(app.staticTexts["garage.empty"].waitForExistence(timeout: 5))
    }

    func testGaragePersistsAcrossRelaunch() {
        launch()
        saveCurrentVehicle()

        app.terminate()
        app.launchArguments = ["-ui-testing", "-skip-onboarding"]
        app.launch()

        tab("Garage").tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Passenger · 243 hp'")
        ).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["garage.empty"].exists)
    }

    func testOnboardingLanguageSelection() {
        launch(skipOnboarding: false, resetOnboarding: true)
        XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 10))

        let russian = app.buttons["onboarding.language.ru"]
        scrollTo(russian)
        XCTAssertTrue(russian.waitForExistence(timeout: 5))
        russian.tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Добро пожаловать'")
        ).firstMatch.waitForExistence(timeout: 5))

        let continueButton = app.buttons["onboarding.continue"]
        scrollTo(continueButton)
        continueButton.tap()
        XCTAssertTrue(tab("Калькулятор").waitForExistence(timeout: 10))
    }

    private func replaceText(_ field: XCUIElement, with text: String, deleteCount: Int = 12) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: deleteCount))
        field.typeText(text)
    }

    private func dismissKeyboard() {
        let toolbarOK = app.toolbars.buttons["OK"].firstMatch
        if toolbarOK.waitForExistence(timeout: 1) {
            toolbarOK.tap()
            return
        }
        let ok = app.buttons["OK"].firstMatch
        if ok.exists { ok.tap() }
    }

    private func choose(_ picker: XCUIElement, option: String) {
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        dismissKeyboard()
        for _ in 0..<3 {
            picker.tap()
            let item = app.buttons[option].firstMatch
            if item.waitForExistence(timeout: 3) {
                item.tap()
                return
            }
        }
        XCTFail("Missing menu option \(option)")
    }

    func testOwnershipDatesSheetOpensAndApplies() {
        launch()

        let advanced = app.buttons["Additional parameters"]
        scrollTo(advanced)
        XCTAssertTrue(advanced.waitForExistence(timeout: 5))
        advanced.tap()

        let dates = app.buttons["calculator.monthsFromDates"]
        scrollTo(dates)
        XCTAssertTrue(dates.waitForExistence(timeout: 5))
        dates.tap()

        XCTAssertTrue(app.navigationBars["Ownership period"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Liability months: 12'")
        ).firstMatch.waitForExistence(timeout: 5))

        let apply = app.buttons["months.apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5))
        apply.tap()

        XCTAssertTrue(app.navigationBars["Ownership period"].waitForNonExistence(timeout: 5))
    }

    func testKilowattInputConvertsToHorsepower() {
        launch()
        let horsepower = app.textFields["calculator.horsepower"]
        XCTAssertTrue(horsepower.waitForExistence(timeout: 10))

        choose(app.buttons["calculator.powerUnit"], option: "kW")
        replaceText(horsepower, with: "100")

        let amount = app.staticTexts["calculator.result.amount"]
        expectation(for: NSPredicate(format: "label CONTAINS '20,400'"), evaluatedWith: amount)
        waitForExpectations(timeout: 5)
    }

    func testElectricVehicleRawPowerUsesThe2026Rule() {
        launch()
        let year = app.textFields["calculator.year"]
        XCTAssertTrue(year.waitForExistence(timeout: 10))
        replaceText(year, with: "2025")

        let horsepower = app.textFields["calculator.horsepower"]
        XCTAssertTrue(horsepower.waitForExistence(timeout: 10))
        replaceText(horsepower, with: "544")

        choose(app.buttons["calculator.powerSource"], option: "Electric · raw motor power")

        let amount = app.staticTexts["calculator.result.amount"]
        let predicate = NSPredicate(format: "label CONTAINS '276,400'")
        expectation(for: predicate, evaluatedWith: amount)
        waitForExpectations(timeout: 5)

        let taxable = app.staticTexts["calculator.result.taxablePower"]
        XCTAssertTrue(taxable.exists)
        XCTAssertTrue(taxable.label.contains("284"))

        choose(app.buttons["calculator.powerSource"], option: "Electric · e-passport power")
        replaceText(horsepower, with: "250")
        expectation(for: NSPredicate(format: "label CONTAINS '175,000'"), evaluatedWith: amount)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.staticTexts["calculator.result.taxablePower"].exists)
    }

    func testTaxYearAdvancesTheAgeDiscount() {
        launch()
        let year = app.textFields["calculator.year"]
        XCTAssertTrue(year.waitForExistence(timeout: 10))
        replaceText(year, with: "2020")

        let amount = app.staticTexts["calculator.result.amount"]
        expectation(for: NSPredicate(format: "label CONTAINS '99,540'"), evaluatedWith: amount)
        waitForExpectations(timeout: 5)

        choose(app.buttons["calculator.taxYear"], option: "2027")

        expectation(for: NSPredicate(format: "label CONTAINS '82,950'"), evaluatedWith: amount)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'projected'")
        ).firstMatch.exists)
    }

    func testRateEditorDisablesSaveForInvalidValues() {
        launch()
        tab("Settings").tap()

        let edit = app.buttons["Edit tax rates"]
        scrollTo(edit)
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()

        let rate = app.textFields["rates.passenger2Rate"]
        XCTAssertTrue(rate.waitForExistence(timeout: 5))
        rate.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        rate.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))

        XCTAssertFalse(app.buttons["rates.save"].isEnabled)
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Check the values'")
        ).firstMatch.exists)

        app.navigationBars.buttons["Cancel"].tap()
    }

    func testRateEditorKeepsEditsWhenYearChangeIsCancelled() {
        launch()
        tab("Settings").tap()

        let edit = app.buttons["Edit tax rates"]
        scrollTo(edit)
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()

        let rate = app.textFields["rates.passenger2Rate"]
        XCTAssertTrue(rate.waitForExistence(timeout: 5))
        replaceText(rate, with: "400")

        choose(app.buttons["rates.year"], option: "2027")

        let keep = app.alerts.buttons["Keep editing"].firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 5))
        keep.tap()

        XCTAssertEqual(rate.value as? String, "400")
        app.navigationBars.buttons["Cancel"].tap()
    }

    func testCustomRateChangeAndReset() {
        launch()
        tab("Settings").tap()

        let edit = app.buttons["Edit tax rates"]
        scrollTo(edit)
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()

        let rate = app.textFields["rates.passenger2Rate"]
        XCTAssertTrue(rate.waitForExistence(timeout: 5))
        replaceText(rate, with: "400")
        app.buttons["rates.save"].tap()

        tab("Calculator").tap()
        let amount = app.staticTexts["calculator.result.amount"]
        expectation(for: NSPredicate(format: "label CONTAINS '95,100'"), evaluatedWith: amount)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Custom tax rates are active'")
        ).firstMatch.exists)

        tab("Settings").tap()
        let reset = app.buttons["Reset all custom rates"]
        scrollTo(reset)
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        let confirm = app.alerts.buttons["Reset all custom rates"].firstMatch
        if confirm.waitForExistence(timeout: 3) {
            confirm.tap()
        }

        tab("Calculator").tap()
        expectation(for: NSPredicate(format: "label CONTAINS '82,950'"), evaluatedWith: amount)
        waitForExpectations(timeout: 5)
    }
}
