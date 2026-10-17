import XCTest

final class SettingsScreenTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()
        return app
    }

    /// 設定画面を開き、本人の声の登録日時の表示を返す。
    @MainActor
    private func openSettings(_ app: XCUIApplication) -> String {
        let settingsButton = app.buttons["root.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        return registeredAt(app)
    }

    @MainActor
    private func registeredAt(_ app: XCUIApplication) -> String {
        let label = app.staticTexts["settings.selfVoiceRegisteredAt"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "label != '-'")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: label)], timeout: 5), .completed)
        return label.label
    }

    @MainActor
    private func startReregistration(_ app: XCUIApplication) {
        let reregisterButton = app.buttons["settings.reregisterVoiceButton"]
        XCTAssertTrue(reregisterButton.waitForExistence(timeout: 5))
        reregisterButton.tap()
        let recordButton = app.buttons["voiceEnrollment.recordButton"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        recordButton.tap()
        XCTAssertTrue(app.buttons["voiceEnrollment.stopButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test再登録に成功すると登録日時が更新される() {
        let app = launch(scenario: "default")
        let before = openSettings(app)

        startReregistration(app)
        app.buttons["voiceEnrollment.stopButton"].tap()

        XCTAssertTrue(app.buttons["settings.reregisterVoiceButton"].waitForExistence(timeout: 10))
        let label = app.staticTexts["settings.selfVoiceRegisteredAt"]
        let predicate = NSPredicate(format: "label != %@", before)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: label)], timeout: 5), .completed)
    }

    @MainActor
    func test再登録に失敗しても古い登録が残る() {
        let app = launch(scenario: "voiceReregistrationShort")
        let before = openSettings(app)

        startReregistration(app)
        app.buttons["voiceEnrollment.stopButton"].tap()
        XCTAssertTrue(app.staticTexts["voiceEnrollment.failure"].waitForExistence(timeout: 10))

        app.buttons["voiceEnrollment.cancelButton"].tap()

        XCTAssertTrue(app.buttons["settings.reregisterVoiceButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(registeredAt(app), before)
    }

    @MainActor
    func test録音中にキャンセルすると古い登録が残る() {
        let app = launch(scenario: "default")
        let before = openSettings(app)

        startReregistration(app)
        app.buttons["voiceEnrollment.cancelButton"].tap()

        XCTAssertTrue(app.buttons["settings.reregisterVoiceButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(registeredAt(app), before)
    }

    @MainActor
    func test初回登録ではキャンセルできない() {
        let app = launch(scenario: "voiceEnrollment")

        XCTAssertTrue(app.buttons["voiceEnrollment.recordButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["voiceEnrollment.cancelButton"].exists)
    }
}
