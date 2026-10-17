import XCTest

final class ProfileDetailScreenTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchProfileDetail(name: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = "profiles"
        app.launch()

        let profilesButton = app.buttons["root.profilesButton"]
        XCTAssertTrue(profilesButton.waitForExistence(timeout: 5))
        profilesButton.tap()

        let profileRow = app.buttons["profileList.row.\(name)"]
        XCTAssertTrue(profileRow.waitForExistence(timeout: 5))
        profileRow.tap()
        return app
    }

    @MainActor
    func test登録済みの情報が全て表示される() {
        let app = launchProfileDetail(name: "山田 太郎")

        XCTAssertTrue(app.staticTexts["profileDetail.name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["profileDetail.name"].label, "山田 太郎")
        XCTAssertEqual(app.staticTexts["profileDetail.affiliation"].label, "株式会社サンプル")
        XCTAssertEqual(app.staticTexts["profileDetail.summary"].label, "新規事業について話した")
        XCTAssertTrue(app.staticTexts["profileDetail.metAt"].exists)
        XCTAssertEqual(app.staticTexts["profileDetail.place"].label, "渋谷駅")
    }

    @MainActor
    func test出会いが未登録でもプロフィールの基本情報を表示する() {
        let app = launchProfileDetail(name: "鈴木 一郎")

        XCTAssertTrue(app.staticTexts["profileDetail.name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["profileDetail.name"].label, "鈴木 一郎")
        XCTAssertEqual(app.staticTexts["profileDetail.affiliation"].label, "サンプル大学")
        XCTAssertFalse(app.staticTexts["profileDetail.metAt"].exists)
        XCTAssertFalse(app.staticTexts["profileDetail.summary"].exists)
        XCTAssertFalse(app.staticTexts["profileDetail.place"].exists)
    }

    @MainActor
    func test未登録の情報は詳細に表示されない() {
        let app = launchProfileDetail(name: "佐藤 花子")

        XCTAssertTrue(app.staticTexts["profileDetail.name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["profileDetail.metAt"].exists)
        XCTAssertFalse(app.staticTexts["profileDetail.affiliation"].exists)
        XCTAssertFalse(app.staticTexts["profileDetail.summary"].exists)
        XCTAssertFalse(app.staticTexts["profileDetail.place"].exists)
    }
}
