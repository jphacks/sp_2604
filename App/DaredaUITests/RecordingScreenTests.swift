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
        return app
    }

    @MainActor
    func test録音中はモードを表示せず停止後に新規登録を選べる() {
        let app = start()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["recording.registrationButton"].exists)
        XCTAssertFalse(app.buttons["recording.searchButton"].exists)
        attach(app, name: "recording-after")
        app.buttons["recording.stopButton"].tap()
        XCTAssertTrue(app.buttons["recording.registrationButton"].waitForExistence(timeout: 5))
        app.buttons["recording.registrationButton"].tap()
        XCTAssertTrue(app.buttons["processing.cancelButton"].waitForExistence(timeout: 5))
        attach(app, name: "recording-choice-after")
    }

    @MainActor
    func test停止後に人物を探すを選べる() {
        let app = start()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        app.buttons["recording.stopButton"].tap()
        XCTAssertTrue(app.buttons["recording.searchButton"].waitForExistence(timeout: 5))
        app.buttons["recording.searchButton"].tap()
        XCTAssertTrue(app.buttons["processing.cancelButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test残り1分を案内して上限で自動停止する() {
        let app = start(scenario: "recordingLimit")
        XCTAssertTrue(app.staticTexts["recording.remainingMinuteNotice"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["recording.limitNotice"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["recording.registrationButton"].exists)
        XCTAssertFalse(app.buttons["recording.stopButton"].exists)
    }

    @MainActor
    func test中断すると録音済み部分を保持して操作を選べる() {
        let app = start(scenario: "recordingInterrupted")
        XCTAssertTrue(app.staticTexts["recording.interruptionNotice"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["recording.searchButton"].exists)
        XCTAssertFalse(app.buttons["recording.stopButton"].exists)
    }

    @MainActor
    func test録音開始失敗時に再試行できる() {
        let app = start(scenario: "recordingFailure")
        XCTAssertTrue(app.staticTexts["recording.errorNotice"].waitForExistence(timeout: 5))
        app.buttons["recording.retryButton"].tap()
        XCTAssertTrue(app.staticTexts["recording.errorNotice"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["recording.registrationButton"].exists)
    }

    @MainActor
    func test破棄を取り消すと録音を継続する() {
        let app = start()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        app.buttons["recording.discardButton"].tap()
        XCTAssertTrue(app.buttons["recording.cancelDiscardButton"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["recording.cancelDiscardButton"].firstMatch.tap()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["recording.registrationButton"].exists)
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
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test起動時の録音整理に失敗したら再試行後に録音できる() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = "recordingCleanupFailure"
        app.launch()
        XCTAssertTrue(app.alerts["前回の録音を整理できませんでした"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.recordButton"].isEnabled)
        app.buttons["root.preparationRetryButton"].tap()
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(app.buttons["root.recordButton"].isEnabled)
        app.buttons["root.recordButton"].tap()
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
