import XCTest

final class ProcessingScreenTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    private func start(scenario: String = "processing", mode: String = "recording.registrationButton") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()
        let record = app.buttons["root.recordButton"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        let stop = app.buttons["recording.stopButton"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        let modeButton = app.buttons[mode]
        XCTAssertTrue(modeButton.waitForExistence(timeout: 5))
        modeButton.tap()
        return app
    }

    @MainActor
    private func stageValue(_ app: XCUIApplication, _ stage: String) -> String? {
        app.descendants(matching: .any)["processing.stage.\(stage)"].value as? String
    }

    @MainActor
    func test新規登録で文字起こしから要約まで完了する() {
        let app = start()
        XCTAssertTrue(app.staticTexts["processing.completedNotice"].waitForExistence(timeout: 30))
        XCTAssertEqual(stageValue(app, "transcribing"), "完了")
        XCTAssertEqual(stageValue(app, "identifyingSpeakers"), "完了")
        XCTAssertEqual(stageValue(app, "summarizing"), "完了")
        attach(app, name: "processing-completed")
    }

    @MainActor
    func test人物を探すでは要約せずに照合まで完了する() {
        let app = start(mode: "recording.searchButton")
        XCTAssertTrue(app.staticTexts["processing.completedNotice"].waitForExistence(timeout: 30))
        XCTAssertEqual(stageValue(app, "identifyingSpeakers"), "完了")
        XCTAssertFalse(app.descendants(matching: .any)["processing.stage.summarizing"].exists)
    }

    @MainActor
    func test失敗した処理を表示し再試行では成功済みの処理を再実行しない() {
        // 文字起こしは 2 回目の呼び出しで失敗するため、再試行で再実行されると完了しない
        let app = start(scenario: "processingFailure")
        let retry = app.buttons["processing.retryButton"]
        XCTAssertTrue(retry.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["processing.errorNotice"].exists)
        XCTAssertEqual(stageValue(app, "transcribing"), "完了")
        XCTAssertEqual(stageValue(app, "identifyingSpeakers"), "失敗")
        XCTAssertEqual(stageValue(app, "summarizing"), "待機中")
        attach(app, name: "processing-failed")
        retry.tap()
        XCTAssertTrue(app.staticTexts["processing.completedNotice"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["processing.errorNotice"].exists)
    }

    @MainActor
    func test本人を判別できない場合は案内を表示する() {
        let app = start(scenario: "processingSelfUnknown")
        XCTAssertTrue(app.staticTexts["processing.selfSelectionNotice"].waitForExistence(timeout: 30))
        XCTAssertEqual(stageValue(app, "identifyingSpeakers"), "完了")
        XCTAssertEqual(stageValue(app, "summarizing"), "待機中")
    }

    @MainActor
    func testキャンセルを取り消すと処理画面に留まる() {
        let app = start(scenario: "processingFailure")
        XCTAssertTrue(app.buttons["processing.retryButton"].waitForExistence(timeout: 30))
        app.buttons["processing.cancelButton"].tap()
        let keep = app.buttons["processing.cancelDiscardButton"].firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 5))
        keep.tap()
        XCTAssertTrue(app.buttons["processing.retryButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.recordButton"].isHittable)
    }

    @MainActor
    func testキャンセルを確定するとホームに戻り新しく録音できる() {
        let app = start(scenario: "processingFailure")
        XCTAssertTrue(app.buttons["processing.retryButton"].waitForExistence(timeout: 30))
        app.buttons["processing.cancelButton"].tap()
        let confirm = app.buttons["processing.confirmDiscardButton"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["root.recordButton"].waitForExistence(timeout: 5))
        app.buttons["root.recordButton"].tap()
        // 前回の録音は残らず、操作選択前の新しい録音から始まる
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["processing.cancelButton"].exists)
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
