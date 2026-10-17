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

        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testプロフィールボタンでプロフィール一覧が表示される() {
        let app = launch(scenario: "profiles")

        let profilesButton = app.buttons["root.profilesButton"]
        XCTAssertTrue(profilesButton.waitForExistence(timeout: 5))
        profilesButton.tap()

        XCTAssertTrue(app.buttons["profileList.row.山田 太郎"].waitForExistence(timeout: 5))
    }

    @MainActor
    func test利用可の場合は案内が出ず録音を開始できる() {
        let app = launch(scenario: "default")

        let recordButton = app.buttons["root.recordButton"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        XCTAssertTrue(recordButton.isEnabled)
        XCTAssertFalse(app.buttons["root.recheckButton"].exists)
    }

    @MainActor
    func test非対応の場合は案内が出て録音は無効でプロフィール閲覧は可能() {
        let app = launch(scenario: "unsupported")

        XCTAssertTrue(app.otherElements["root.availabilityNotice.unsupported"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.recordButton"].isEnabled)
        XCTAssertTrue(app.buttons["root.profilesButton"].isEnabled)
    }

    @MainActor
    func test一時的に利用不可の場合は案内が出て録音は無効でプロフィール閲覧は可能() {
        let app = launch(scenario: "modelNotReady")

        XCTAssertTrue(app.otherElements["root.availabilityNotice.temporarilyUnavailable"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.recordButton"].isEnabled)
        XCTAssertTrue(app.buttons["root.profilesButton"].isEnabled)
    }

    @MainActor
    func test再判定で利用可になると案内が消えて録音が有効になる() {
        let app = launch(scenario: "recovering")

        let recheckButton = app.buttons["root.recheckButton"]
        XCTAssertTrue(recheckButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.recordButton"].isEnabled)

        recheckButton.tap()

        XCTAssertTrue(app.buttons["root.recordButton"].isEnabled)
        XCTAssertFalse(app.buttons["root.recheckButton"].exists)
    }
    @MainActor
    func testマイク未決定でも起動時は権限案内を表示しない() {
        let app = launch(scenario: "microphoneUndeterminedDenied")
        XCTAssertTrue(app.buttons["root.recordButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["root.microphoneDeniedNotice"].exists)
        XCTAssertFalse(app.staticTexts["root.microphoneGrantedNotice"].exists)
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
    func test未決定から拒否すると設定案内を表示する() {
        assertMicrophoneDenied(scenario: "microphoneUndeterminedDenied")
    }

    @MainActor
    func test拒否済みなら設定案内を表示する() {
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
        XCTAssertTrue(app.staticTexts["root.microphoneGrantedNotice"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.openSettingsButton"].exists)
    }

    @MainActor
    func test設定アプリを開けない場合は手動で開く方法を案内する() {
        let app = assertMicrophoneDenied(scenario: "settingsFailure")
        app.buttons["root.openSettingsButton"].tap()
        XCTAssertTrue(app.staticTexts["root.settingsErrorNotice"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func assertMicrophoneGranted(scenario: String) {
        let app = launch(scenario: scenario)
        let button = app.buttons["root.recordButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.staticTexts["root.microphoneGrantedNotice"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["root.openSettingsButton"].exists)
    }

    @MainActor
    @discardableResult
    private func assertMicrophoneDenied(scenario: String) -> XCUIApplication {
        let app = launch(scenario: scenario)
        let button = app.buttons["root.recordButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.staticTexts["root.microphoneDeniedNotice"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["root.openSettingsButton"].exists)
        XCTAssertFalse(app.staticTexts["root.microphoneGrantedNotice"].exists)
        return app
    }

}
