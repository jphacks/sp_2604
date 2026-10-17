import XCTest

final class RegistrationScreenTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// 録音を停止して処理を始める。
    @MainActor
    private func stopRecording(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()
        let recordButton = app.buttons["root.recordButton"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        recordButton.tap()
        let recordFromMicrophone = app.buttons["root.recordFromMicrophoneButton"].firstMatch
        XCTAssertTrue(recordFromMicrophone.waitForExistence(timeout: 5))
        recordFromMicrophone.tap()
        let stopButton = app.buttons["recording.stopButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
        stopButton.tap()
        return app
    }

    /// 録音を停止して処理を終え、候補の提示後に該当なしとして新規登録に進む。
    @MainActor
    private func startRegistration(scenario: String = "registration") -> XCUIApplication {
        let app = stopRecording(scenario: scenario)
        let registrationButton = app.buttons["personSearch.newRegistrationButton"]
        XCTAssertTrue(registrationButton.waitForExistence(timeout: 30))
        registrationButton.tap()
        return app
    }

    @MainActor
    private func waitForForm(_ app: XCUIApplication) {
        // 要約まで済むと登録画面に切り替わる
        XCTAssertTrue(app.textFields["registration.nameTextField"].waitForExistence(timeout: 30))
    }

    @MainActor
    private func type(_ text: String, into identifier: String, in app: XCUIApplication) {
        let field = app.textFields[identifier]
        field.tap()
        field.typeText(text)
    }

    @MainActor
    func test入力した内容で保存すると詳細が表示され一覧にも並ぶ() {
        let app = startRegistration()
        waitForForm(app)
        attach(app, name: "registration-after")

        type("高橋 次郎", into: "registration.nameTextField", in: app)
        type("サンプル商事", into: "registration.affiliationTextField", in: app)
        XCTAssertTrue(app.datePickers["registration.metAtPicker"].exists)

        app.buttons["placePicker.selectButton"].tap()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("札幌")
        let result = app.buttons["placeSearch.result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(app.staticTexts["placePicker.placeName"].waitForExistence(timeout: 5))

        app.buttons["registration.saveButton"].tap()

        let name = app.staticTexts["profileDetail.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertEqual(name.label, "高橋 次郎")
        XCTAssertEqual(app.staticTexts["profileDetail.affiliation"].label, "サンプル商事")
        XCTAssertEqual(app.staticTexts["profileDetail.place"].label, "札幌駅")
        XCTAssertFalse(app.staticTexts["profileDetail.summary"].label.isEmpty)
        XCTAssertTrue(app.staticTexts["profileDetail.metAt"].exists)
        attach(app, name: "registration-detail-after")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["profileList.row.高橋 次郎"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test名前を入力するまで保存できない() {
        let app = startRegistration()
        waitForForm(app)
        let saveButton = app.buttons["registration.saveButton"]
        XCTAssertFalse(saveButton.isEnabled)
        type("   ", into: "registration.nameTextField", in: app)
        XCTAssertFalse(saveButton.isEnabled)
        type("高橋", into: "registration.nameTextField", in: app)
        XCTAssertTrue(saveButton.isEnabled)
    }

    @MainActor
    func test保存に失敗しても入力を保持して再試行できる() {
        let app = startRegistration(scenario: "registrationSaveFailure")
        waitForForm(app)
        type("高橋 次郎", into: "registration.nameTextField", in: app)
        app.buttons["registration.saveButton"].tap()

        let alertOKButton = app.buttons["registration.saveErrorAlertOKButton"].firstMatch
        XCTAssertTrue(alertOKButton.waitForExistence(timeout: 5))
        attach(app, name: "registration-save-failure-alert")
        alertOKButton.tap()
        XCTAssertEqual(app.textFields["registration.nameTextField"].value as? String, "高橋 次郎")
        attach(app, name: "registration-save-failure-after")

        app.buttons["registration.saveButton"].tap()
        let name = app.staticTexts["profileDetail.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertEqual(name.label, "高橋 次郎")
    }

    @MainActor
    func test相手の声を検出できないと登録に進めない() {
        let app = stopRecording(scenario: "registrationNoPartner")
        XCTAssertTrue(app.staticTexts["processing.errorNotice"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.textFields["registration.nameTextField"].exists)
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
