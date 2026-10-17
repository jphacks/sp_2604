import XCTest

final class RootScreenTests: XCTestCase {
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
    func test起動するとルート画面が表示される() {
        let app = launch(scenario: "default")

        XCTAssertTrue(app.buttons["root.recordButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test起動するとプロフィール一覧が表示される() {
        let app = launch(scenario: "profiles")

        XCTAssertTrue(app.buttons["profileList.row.山田 太郎"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test利用可の場合は録音を開始できる() {
        let app = launch(scenario: "default")

        let recordButton = app.buttons["root.recordButton"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        XCTAssertTrue(recordButton.isEnabled)
    }

    @MainActor
    func test非対応の場合は録音は無効でプロフィール閲覧は可能() {
        let app = launch(scenario: "unsupported")

        XCTAssertTrue(app.buttons["root.recordButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.recordButton"].isEnabled)
        XCTAssertTrue(app.staticTexts["profileList.emptyLabel"].exists)
    }

    @MainActor
    func test一時的に利用不可の場合は録音は無効でプロフィール閲覧は可能() {
        let app = launch(scenario: "modelNotReady")

        XCTAssertTrue(app.buttons["root.recordButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.recordButton"].isEnabled)
        XCTAssertTrue(app.staticTexts["profileList.emptyLabel"].exists)
    }

    @MainActor
    func testAppleIntelligenceが無効なら録音できずプロフィール一覧を開ける() {
        let app = launch(scenario: "appleIntelligenceDisabled")

        XCTAssertTrue(app.buttons["root.recordButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.recordButton"].isEnabled)
        XCTAssertTrue(app.staticTexts["profileList.emptyLabel"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testマイク未決定でも起動時は権限のアラートを表示しない() {
        let app = launch(scenario: "microphoneUndeterminedDenied")
        XCTAssertTrue(app.buttons["root.recordButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    @MainActor
    func test未決定から許可すると許可済みになる() {
        assertMicrophoneGranted(scenario: "microphoneUndeterminedGranted")
    }

    @MainActor
    func test許可済みなら録音操作で許可済みになる() {
        assertMicrophoneGranted(scenario: "microphoneGranted")
    }

    @MainActor
    func test未決定から拒否するとアラートを表示する() {
        assertMicrophoneDenied(scenario: "microphoneUndeterminedDenied")
    }

    @MainActor
    func test拒否済みならアラートを表示する() {
        let app = assertMicrophoneDenied(scenario: "microphoneDenied")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "microphone-denied-after"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func test設定アプリから戻った後に再操作して許可を確認できる() {
        let app = assertMicrophoneDenied(scenario: "microphoneSettingsGranted")
        app.buttons["root.openSettingsButton"].tap()
        app.buttons["root.recordButton"].tap()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.openSettingsButton"].exists)
    }

    @MainActor
    private func assertMicrophoneGranted(scenario: String) {
        let app = launch(scenario: scenario)
        let button = app.buttons["root.recordButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.openSettingsButton"].exists)
    }

    @MainActor
    @discardableResult
    private func assertMicrophoneDenied(scenario: String) -> XCUIApplication {
        let app = launch(scenario: scenario)
        let button = app.buttons["root.recordButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.alerts["マイクの使用が許可されていません"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["root.openSettingsButton"].exists)
        return app
    }

    @MainActor
    func test人物検索の通知をタップすると候補一覧が開く() {
        // 通知のタップは UserNotificationClient のテストダブルが起動後に発生させる
        let app = launch(scenario: "personSearchNotificationTapped")

        // TODO: #23 で候補一覧画面に差し替えたら、検証する要素も差し替える
        XCTAssertTrue(app.buttons["profileList.row.山田 太郎"].waitForExistence(timeout: 5))
    }
}
