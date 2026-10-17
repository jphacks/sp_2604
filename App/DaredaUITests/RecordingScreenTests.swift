import XCTest

final class RecordingScreenTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    private func start(scenario: String = "default") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()
        let button = app.buttons["root.recordButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        let recordFromMicrophone = app.buttons["root.recordFromMicrophoneButton"].firstMatch
        XCTAssertTrue(recordFromMicrophone.waitForExistence(timeout: 5))
        recordFromMicrophone.tap()
        return app
    }

    @MainActor
    func test停止するとすぐに処理を開始する() {
        let app = start()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        attach(app, name: "recording-after")
        app.buttons["recording.stopButton"].tap()
        XCTAssertTrue(app.buttons["processing.cancelButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["processing.stage.transcribing"].exists)
        attach(app, name: "recording-choice-after")
    }

    @MainActor
    func test残り1分を案内して上限で自動停止する() {
        let app = start(scenario: "recordingLimit")
        XCTAssertTrue(app.staticTexts["recording.remainingMinuteNotice"].waitForExistence(timeout: 5))
        // 上限で停止するとすぐに処理画面へ進むため、上限の案内ではなく処理の開始を確認する
        XCTAssertTrue(app.buttons["processing.cancelButton"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["recording.stopButton"].exists)
    }

    @MainActor
    func test中断すると録音済み部分を保持して処理を開始する() {
        let app = start(scenario: "recordingInterrupted")
        // 中断するとすぐに処理画面へ進むため、中断の案内ではなく処理の開始を確認する
        XCTAssertTrue(app.buttons["processing.cancelButton"].waitForExistence(timeout: 13))
        XCTAssertFalse(app.buttons["recording.stopButton"].exists)
    }

    @MainActor
    func test録音開始失敗時に再試行できる() {
        let app = start(scenario: "recordingFailure")
        XCTAssertTrue(app.staticTexts["recording.errorNotice"].waitForExistence(timeout: 5))
        app.buttons["recording.retryButton"].tap()
        XCTAssertTrue(app.staticTexts["recording.errorNotice"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["processing.cancelButton"].exists)
    }

    @MainActor
    func test破棄を取り消すと録音を継続する() {
        let app = start()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        app.buttons["recording.discardButton"].tap()
        XCTAssertTrue(app.buttons["recording.confirmDiscardButton"].firstMatch.waitForExistence(timeout: 5))
        // iPhone の confirmationDialog は cancel ロールのボタンを表示しないため、外側をタップして閉じる
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["processing.cancelButton"].exists)
    }

    @MainActor
    func test破棄確認後に閉じて再度録音できる() {
        let app = start()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        app.buttons["recording.discardButton"].tap()
        let confirm = app.buttons["recording.confirmDiscardButton"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["root.recordButton"].waitForExistence(timeout: 5))
        app.buttons["root.recordButton"].tap()
        let recordFromMicrophone = app.buttons["root.recordFromMicrophoneButton"].firstMatch
        XCTAssertTrue(recordFromMicrophone.waitForExistence(timeout: 5))
        recordFromMicrophone.tap()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test起動時の録音整理に失敗したら再試行後に録音できる() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = "recordingCleanupFailure"
        app.launch()
        XCTAssertTrue(app.alerts["前回の録音を整理できませんでした"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.recordButton"].isEnabled)
        // ボタンが 1 つだけのアラートでは accessibilityIdentifier が反映されないため、アラート内のボタンをタップする
        app.alerts.firstMatch.buttons.firstMatch.tap()
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(app.buttons["root.recordButton"].isEnabled)
        app.buttons["root.recordButton"].tap()
        let recordFromMicrophone = app.buttons["root.recordFromMicrophoneButton"].firstMatch
        XCTAssertTrue(recordFromMicrophone.waitForExistence(timeout: 5))
        recordFromMicrophone.tap()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
