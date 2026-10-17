import XCTest

final class BearingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeShowsThreeRoutinesHistoryAndSettings() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Bearing"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Arm raise"].exists)
        XCTAssertTrue(app.staticTexts["Sit to stand"].exists)
        XCTAssertTrue(app.staticTexts["One-leg balance"].exists)
        XCTAssertTrue(app.staticTexts["History and report"].exists)
        XCTAssertTrue(app.staticTexts["Settings"].exists)
    }

    @MainActor
    func testSettingsHasDeleteAllMyData() throws {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Settings"].tap()
        XCTAssertTrue(app.buttons["Delete all my data"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEmptyHistoryShowsMessage() throws {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["History and report"].tap()
        XCTAssertTrue(app.staticTexts["No sessions yet. Pick a routine on the home screen."].waitForExistence(timeout: 5))
    }
}
