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

        let profilesButton = app.buttons["root.profilesButton"]
        XCTAssertTrue(profilesButton.waitForExistence(timeout: 5))
        profilesButton.tap()
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
    func test一覧から詳細を開くと全ての情報が表示される() {
        let app = launchProfileList(scenario: "profiles")

        let profileRow = app.buttons["profileList.row.山田 太郎"]
        XCTAssertTrue(profileRow.waitForExistence(timeout: 5))
        profileRow.tap()

        XCTAssertTrue(app.staticTexts["profileDetail.name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["profileDetail.name"].label, "山田 太郎")
        XCTAssertEqual(app.staticTexts["profileDetail.affiliation"].label, "株式会社サンプル")
        XCTAssertEqual(app.staticTexts["profileDetail.summary"].label, "新規事業について話した")
        XCTAssertTrue(app.staticTexts["profileDetail.metAt"].exists)
        XCTAssertEqual(app.staticTexts["profileDetail.place"].label, "渋谷駅")
    }

    @MainActor
    func test出会いが未登録でもプロフィールの基本情報を表示する() {
        let app = launchProfileList(scenario: "profiles")
        let profileRow = app.buttons["profileList.row.鈴木 一郎"]
        XCTAssertTrue(profileRow.waitForExistence(timeout: 5))
        profileRow.tap()

        XCTAssertTrue(app.staticTexts["profileDetail.name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["profileDetail.name"].label, "鈴木 一郎")
        XCTAssertEqual(app.staticTexts["profileDetail.affiliation"].label, "サンプル大学")
        XCTAssertFalse(app.staticTexts["profileDetail.metAt"].exists)
        XCTAssertFalse(app.staticTexts["profileDetail.summary"].exists)
        XCTAssertFalse(app.staticTexts["profileDetail.place"].exists)
    }

    @MainActor
    func test未登録の情報は詳細に表示されない() {
        let app = launchProfileList(scenario: "profiles")

        let profileRow = app.buttons["profileList.row.佐藤 花子"]
        XCTAssertTrue(profileRow.waitForExistence(timeout: 5))
        profileRow.tap()

        XCTAssertTrue(app.staticTexts["profileDetail.name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["profileDetail.metAt"].exists)
        XCTAssertFalse(app.staticTexts["profileDetail.affiliation"].exists)
        XCTAssertFalse(app.staticTexts["profileDetail.summary"].exists)
        XCTAssertFalse(app.staticTexts["profileDetail.place"].exists)
    }
}
