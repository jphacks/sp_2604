import XCTest

final class ProfileListScreenTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchProfileList(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()

        return app
    }

    @MainActor
    func test未登録のときは空の案内が表示される() {
        let app = launchProfileList(scenario: "default")

        XCTAssertTrue(app.staticTexts["profileList.emptyLabel"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test保存済みプロフィールが一覧に表示される() {
        let app = launchProfileList(scenario: "profiles")

        XCTAssertTrue(app.buttons["profileList.row.山田 太郎"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profileList.row.佐藤 花子"].exists)
        XCTAssertTrue(app.buttons["profileList.row.鈴木 一郎"].exists)
        XCTAssertFalse(app.staticTexts["profileList.emptyLabel"].exists)
    }

    @MainActor
    func test行をタップすると詳細が表示される() {
        let app = launchProfileList(scenario: "profiles")

        let profileRow = app.buttons["profileList.row.山田 太郎"]
        XCTAssertTrue(profileRow.waitForExistence(timeout: 5))
        profileRow.tap()

        XCTAssertTrue(app.staticTexts["profileDetail.name"].waitForExistence(timeout: 5))
    }
}
