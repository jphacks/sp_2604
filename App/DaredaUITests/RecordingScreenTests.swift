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
        XCTAssertTrue(app.staticTexts["recording.selectedMode.registration"].waitForExistence(timeout: 5))
        attach(app, name: "recording-choice-after")
    }

    @MainActor
    func test停止後に人物を探すを選べる() {
        let app = start()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        app.buttons["recording.stopButton"].tap()
        XCTAssertTrue(app.buttons["recording.searchButton"].waitForExistence(timeout: 5))
        app.buttons["recording.searchButton"].tap()
        XCTAssertTrue(app.staticTexts["recording.selectedMode.search"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["root.preparationErrorNotice"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.recordButton"].isEnabled)
        app.buttons["root.preparationRetryButton"].tap()
        XCTAssertFalse(app.staticTexts["root.preparationErrorNotice"].exists)
        XCTAssertTrue(app.buttons["root.recordButton"].isEnabled)
        app.buttons["root.recordButton"].tap()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func startAnalysis(scenario: String) -> XCUIApplication {
        let app = start(scenario: scenario)
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        app.buttons["recording.stopButton"].tap()
        XCTAssertTrue(app.buttons["recording.searchButton"].waitForExistence(timeout: 5))
        app.buttons["recording.searchButton"].tap()
        return app
    }

    @MainActor
    func test操作を選ぶと解析が完了する() {
        let app = startAnalysis(scenario: "default")
        XCTAssertTrue(app.staticTexts["recording.analysisCompleted"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["recording.analysisError"].exists)
    }

    @MainActor
    func test解析がOSに中断されても復帰後に未完了の処理だけを再試行して完了する() {
        let app = startAnalysis(scenario: "analysisSuspended")
        // 文字起こしを終えて話者分離中にバックグラウンドへ移行し、OS に打ち切られる
        XCTAssertTrue(app.descendants(matching: .any)["recording.analysisStage"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))

        app.activate()
        // 文字起こしは 2 回目が失敗するテストダブルなので、完了すれば文字起こしは再実行されていない
        XCTAssertTrue(app.staticTexts["recording.analysisCompleted"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["recording.analysisError"].exists)
        attach(app, name: "recording-analysis-resumed-after")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
