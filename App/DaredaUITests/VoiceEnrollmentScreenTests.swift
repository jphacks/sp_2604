import XCTest

final class VoiceEnrollmentScreenTests: XCTestCase {
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

    @MainActor
    func test本人の声が未登録なら起動時に例文と録音ボタンが表示される() {
        let app = launch(scenario: "voiceEnrollment")

        XCTAssertTrue(app.staticTexts["voiceEnrollment.sampleText"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["voiceEnrollment.recordButton"].exists)
    }

    @MainActor
    func test本人の声が登録済みなら登録画面は表示されない() {
        let app = launch(scenario: "default")

        XCTAssertTrue(app.buttons["root.recordButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["voiceEnrollment.sampleText"].exists)
    }

    @MainActor
    func test録音して停止すると登録が完了してホームに戻る() {
        let app = launch(scenario: "voiceEnrollment")

        let recordButton = app.buttons["voiceEnrollment.recordButton"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        recordButton.tap()

        let stopButton = app.buttons["voiceEnrollment.stopButton"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
        stopButton.tap()

        XCTAssertTrue(app.buttons["root.recordButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["voiceEnrollment.sampleText"].exists)
    }
}
