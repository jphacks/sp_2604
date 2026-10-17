import XCTest

final class ProfileListScreenTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func test未登録のときは空の案内が表示される() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = "default"
        app.launch()

        XCTAssertTrue(app.staticTexts["profileList.emptyLabel"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test保存済みプロフィールが一覧に表示される() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = "profiles"
        app.launch()

        XCTAssertTrue(app.buttons["profileList.row.山田 太郎"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profileList.row.佐藤 花子"].exists)
        XCTAssertFalse(app.staticTexts["profileList.emptyLabel"].exists)
    }

    @MainActor
    func test一覧から詳細を開くと全ての情報が表示される() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = "profiles"
        app.launch()

        app.buttons["profileList.row.山田 太郎"].tap()

        XCTAssertTrue(app.staticTexts["profileDetail.name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["profileDetail.name"].label, "山田 太郎")
        XCTAssertEqual(app.staticTexts["profileDetail.affiliation"].label, "株式会社サンプル")
        XCTAssertEqual(app.staticTexts["profileDetail.summary"].label, "新規事業について話した")
        XCTAssertTrue(app.staticTexts["profileDetail.metAt"].exists)
        XCTAssertEqual(app.staticTexts["profileDetail.place"].label, "渋谷駅")
    }

    @MainActor
    func test未登録の情報は詳細に表示されない() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = "profiles"
        app.launch()

        app.buttons["profileList.row.佐藤 花子"].tap()

        XCTAssertTrue(app.staticTexts["profileDetail.name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["profileDetail.metAt"].exists)
        XCTAssertFalse(app.staticTexts["profileDetail.affiliation"].exists)
        XCTAssertFalse(app.staticTexts["profileDetail.summary"].exists)
        XCTAssertFalse(app.staticTexts["profileDetail.place"].exists)
    }
}
