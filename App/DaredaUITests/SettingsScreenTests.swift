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

    @MainActor
    private func openPrivateCloudComputeToggle(_ app: XCUIApplication) -> XCUIElement {
        let settingsButton = app.buttons["root.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let toggle = app.switches["settings.privateCloudComputeToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        return toggle
    }

    @MainActor
    func test未選択のときはPCCが無効で表示される() {
        let app = launch(scenario: "default")

        let toggle = openPrivateCloudComputeToggle(app)

        XCTAssertEqual(toggle.value as? String, "0")
    }

    @MainActor
    func test有効化と無効化が閉じて開き直しても保持される() {
        let app = launch(scenario: "default")

        let toggle = openPrivateCloudComputeToggle(app)
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")

        app.swipeDown(velocity: .fast)
        XCTAssertEqual(openPrivateCloudComputeToggle(app).value as? String, "1")

        openPrivateCloudComputeToggle(app).switches.firstMatch.tap()
        XCTAssertEqual(app.switches["settings.privateCloudComputeToggle"].value as? String, "0")

        app.swipeDown(velocity: .fast)
        XCTAssertEqual(openPrivateCloudComputeToggle(app).value as? String, "0")
    }

    @MainActor
    func test権限の許可状態が表示される() {
        let app = launch(scenario: "settingsPermissions")
        let settingsButton = app.buttons["root.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let microphone = app.buttons["settings.microphonePermission"]
        XCTAssertTrue(microphone.waitForExistence(timeout: 5))
        let deniedPredicate = NSPredicate(format: "label CONTAINS '未許可'")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: deniedPredicate, evaluatedWith: microphone)], timeout: 5), .completed)
        let notification = app.buttons["settings.notificationPermission"]
        let grantedPredicate = NSPredicate(format: "label CONTAINS '許可' AND NOT label CONTAINS '未許可'")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: grantedPredicate, evaluatedWith: notification)], timeout: 5), .completed)
    }
}
