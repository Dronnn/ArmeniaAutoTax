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
}
