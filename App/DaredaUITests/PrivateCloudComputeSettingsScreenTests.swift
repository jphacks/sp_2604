import XCTest

final class PrivateCloudComputeSettingsScreenTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = "default"
        app.launch()
        return app
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication) -> XCUIElement {
        let settingsButton = app.buttons["root.privateCloudComputeSettingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let toggle = app.switches["privateCloudComputeSettings.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        return toggle
    }

    @MainActor
    func test未選択のときはPCCが無効で表示される() {
        let app = launch()

        let toggle = openSettings(app)

        XCTAssertEqual(toggle.value as? String, "0")
    }

    @MainActor
    func test有効化と無効化が閉じて開き直しても保持される() {
        let app = launch()

        let toggle = openSettings(app)
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")

        app.swipeDown(velocity: .fast)
        XCTAssertEqual(openSettings(app).value as? String, "1")

        openSettings(app).switches.firstMatch.tap()
        XCTAssertEqual(app.switches["privateCloudComputeSettings.toggle"].value as? String, "0")

        app.swipeDown(velocity: .fast)
        XCTAssertEqual(openSettings(app).value as? String, "0")
    }
}
