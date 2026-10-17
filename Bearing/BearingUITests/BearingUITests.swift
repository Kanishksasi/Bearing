import XCTest

final class BearingUITests: XCTestCase {

    /// The intro shows on first launch. Tap through it if it is there.
    @MainActor
    private func launchPastIntro() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let start = app.buttons["Get started"]
        if start.waitForExistence(timeout: 5) { start.tap() }
        return app
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeShowsThreeRoutinesHistoryAndSettings() throws {
        let app = launchPastIntro()

        XCTAssertTrue(app.navigationBars["Bearing"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Arm raise"].exists)
        XCTAssertTrue(app.staticTexts["Sit to stand"].exists)
        XCTAssertTrue(app.staticTexts["One-leg balance"].exists)
        XCTAssertTrue(app.staticTexts["History and report"].exists)
        XCTAssertTrue(app.staticTexts["Settings"].exists)
    }

    @MainActor
    func testSettingsHasDeleteAllMyData() throws {
        let app = launchPastIntro()

        app.staticTexts["Settings"].tap()
        XCTAssertTrue(app.buttons["Delete all my data"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEmptyHistoryShowsMessage() throws {
        let app = launchPastIntro()

        app.staticTexts["History and report"].tap()
        XCTAssertTrue(app.staticTexts["No sessions yet. Pick a routine on the home screen."].waitForExistence(timeout: 5))
    }
}
