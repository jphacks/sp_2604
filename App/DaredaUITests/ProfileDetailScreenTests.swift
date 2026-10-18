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

    @MainActor
    func test名前と所属を編集すると詳細に反映される() {
        let app = launchProfileDetail(name: "山田 太郎")

        let editButton = app.buttons["profileDetail.editButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        let nameField = app.textFields["profileEdit.nameTextField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        // 編集メニューの表示は OS によって変わるため、削除キーで既存の値を消す
        let currentName = nameField.value as? String ?? ""
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentName.count))
        nameField.typeText("山田 次郎")
        app.buttons["profileEdit.saveButton"].tap()

        XCTAssertTrue(app.staticTexts["profileDetail.name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["profileDetail.name"].label, "山田 次郎")
    }

    @MainActor
    func test前回の会話の要約を編集すると詳細に反映される() {
        let app = launchProfileDetail(name: "山田 太郎")

        let editButton = app.buttons["profileDetail.editButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        let summaryField = app.textViews["profileEdit.summaryTextField"].exists
            ? app.textViews["profileEdit.summaryTextField"]
            : app.textFields["profileEdit.summaryTextField"]
        XCTAssertTrue(summaryField.waitForExistence(timeout: 5))
        summaryField.tap()
        summaryField.typeText("追記")
        app.buttons["profileEdit.saveButton"].tap()

        XCTAssertTrue(app.staticTexts["profileDetail.summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["profileDetail.summary"].label.contains("追記"))
    }

    @MainActor
    func test削除すると一覧から消える() {
        let app = launchProfileDetail(name: "山田 太郎")

        let deleteButton = app.buttons["profileDetail.deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()
        app.buttons["profileDetail.deleteConfirmButton"].firstMatch.tap()

        XCTAssertTrue(app.buttons["profileList.row.佐藤 花子"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profileList.row.山田 太郎"].exists)
    }
}
