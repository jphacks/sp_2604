import XCTest

final class RootScreenTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test起動するとプロフィール一覧が表示される() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = "default"
        app.launch()

        XCTAssertTrue(app.staticTexts["profileList.emptyLabel"].waitForExistence(timeout: 5))
    }
}
