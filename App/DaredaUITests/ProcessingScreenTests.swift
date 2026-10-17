import XCTest

final class ProcessingScreenTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    private func start(scenario: String = "processing") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_SCENARIO"] = scenario
        app.launch()
        let record = app.buttons["root.recordButton"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        let stop = app.buttons["recording.stopButton"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        // 停止すると、操作を選ばずにすぐ処理が始まる
        XCTAssertTrue(app.buttons["processing.cancelButton"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func stageValue(_ app: XCUIApplication, _ stage: String) -> String? {
        app.descendants(matching: .any)["processing.stage.\(stage)"].value as? String
    }

    @MainActor
    func test要約まで完了すると候補を提示し新規登録に進むと入力画面を表示する() {
        let app = start()
        // 登録0人のため、文字起こし・話者識別・要約の全てが済んだ後に新規登録を案内する
        XCTAssertTrue(app.buttons["personSearch.newRegistrationButton"].waitForExistence(timeout: 30))
        XCTAssertEqual(stageValue(app, "identifyingSpeakers"), "完了")
        XCTAssertEqual(stageValue(app, "summarizing"), "完了")
        attach(app, name: "processing-completed")
        app.buttons["personSearch.newRegistrationButton"].tap()
        XCTAssertTrue(app.textFields["registration.nameTextField"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.descendants(matching: .any)["processing.stage.transcribing"].exists)
    }

    @MainActor
    func test処理が完了すると登録0人ならその旨を表示する() {
        let app = start()
        XCTAssertTrue(app.staticTexts["personSearch.noProfilesNotice"].waitForExistence(timeout: 30))
        XCTAssertEqual(stageValue(app, "summarizing"), "完了")
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
        XCTAssertTrue(app.staticTexts["personSearch.noProfilesNotice"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["processing.errorNotice"].exists)
    }

    @MainActor
    func test解析がOSに中断されても復帰後に未完了の処理だけを再試行して完了する() {
        let app = start(scenario: "analysisSuspended")
        // 文字起こしを終えて話者分離中にバックグラウンドへ移行し、OS に打ち切られる
        let identifying = app.descendants(matching: .any)["processing.stage.identifyingSpeakers"]
        XCTAssertTrue(identifying.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue(identifying, "処理中"))
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))

        app.activate()
        // 文字起こしは 2 回目が失敗するテストダブルなので、完了すれば文字起こしは再実行されていない
        XCTAssertTrue(app.staticTexts["personSearch.noProfilesNotice"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["processing.errorNotice"].exists)
        attach(app, name: "processing-resumed-after")
    }

    @MainActor
    private func waitForValue(_ element: XCUIElement, _ value: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }

    @MainActor
    func test本人を判別できない場合は話者別の発言から自分を選ぶと要約を経て候補を提示する() {
        let app = start(scenario: "processingSelfUnknown")
        XCTAssertTrue(app.descendants(matching: .any)["processing.selfSelectionNotice"].waitForExistence(timeout: 30))
        XCTAssertEqual(stageValue(app, "identifyingSpeakers"), "完了")
        XCTAssertEqual(stageValue(app, "summarizing"), "待機中")
        // 2 人の話者それぞれの発言を表示する
        XCTAssertTrue(app.staticTexts["はじめまして、田中です。"].exists)
        XCTAssertTrue(app.staticTexts["よろしくお願いします。"].exists)
        XCTAssertTrue(app.buttons["processing.selfCandidate.1"].exists)
        attach(app, name: "processing-self-selection")

        app.buttons["processing.selfCandidate.0"].tap()
        // 選んだ本人で照合と要約まで済むと候補を提示し、新規登録に進める
        XCTAssertTrue(app.staticTexts["personSearch.noProfilesNotice"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.descendants(matching: .any)["processing.selfSelectionNotice"].exists)
        XCTAssertFalse(app.staticTexts["processing.errorNotice"].exists)
        app.buttons["personSearch.newRegistrationButton"].tap()
        XCTAssertTrue(app.textFields["registration.nameTextField"].waitForExistence(timeout: 30))
    }

    @MainActor
    func test自分を判断できないときは録音し直せる() {
        let app = start(scenario: "processingSelfUnknown")
        let rerecord = app.buttons["processing.rerecordButton"]
        XCTAssertTrue(rerecord.waitForExistence(timeout: 30))
        rerecord.tap()
        // 録音画面に戻り、新しい録音が始まる
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["processing.cancelButton"].exists)
        app.buttons["recording.stopButton"].tap()
        XCTAssertTrue(app.buttons["processing.cancelButton"].waitForExistence(timeout: 5))
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
        // 前回の録音は残らず、新しい録音から始まる
        XCTAssertTrue(app.buttons["recording.stopButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["processing.cancelButton"].exists)
    }

    @MainActor
    func test人物を探すと声の近い順に候補を表示し選ぶとプロフィール詳細を表示する() {
        let app = start(scenario: "personSearch")
        let first = app.buttons["personSearch.candidate.0"]
        XCTAssertTrue(first.waitForExistence(timeout: 30))
        // 登録済みの 3 人を全て表示し、1 位は相手の声と同じ「山田 太郎」。未登録の情報は表示しない
        XCTAssertTrue(first.label.contains("山田 太郎"))
        XCTAssertTrue(first.label.contains("株式会社サンプル"))
        XCTAssertTrue(first.label.contains("渋谷駅"))
        XCTAssertTrue(first.label.contains("新規事業について話した"))
        XCTAssertTrue(app.buttons["personSearch.candidate.2"].exists)
        XCTAssertFalse(app.buttons["personSearch.candidate.3"].exists)
        XCTAssertTrue(app.buttons["personSearch.manualSelectionButton"].exists)
        XCTAssertTrue(app.buttons["personSearch.newRegistrationButton"].exists)
        attach(app, name: "person-search-candidates")

        first.tap()
        let name = app.staticTexts["profileDetail.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertEqual(name.label, "山田 太郎")
        // 既存の人物を選んでもプロフィールは増えない
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["root.recordButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "山田 太郎")).count, 1)
    }

    @MainActor
    func test別の人を選ぶと保存済みのプロフィールから選んで確定できる() {
        let app = start(scenario: "personSearch")
        let manual = app.buttons["personSearch.manualSelectionButton"]
        XCTAssertTrue(manual.waitForExistence(timeout: 30))
        manual.tap()
        let option = app.buttons["personSearch.manualSelection.2"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        attach(app, name: "person-search-manual-selection")
        let selectedName = option.label.components(separatedBy: ",").first ?? ""
        option.tap()
        let name = app.staticTexts["profileDetail.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertTrue(selectedName.contains(name.label))
    }

    @MainActor
    func test該当なしを選ぶと要約済みの新規登録の入力画面に進む() {
        let app = start(scenario: "personSearch")
        let newRegistration = app.buttons["personSearch.newRegistrationButton"]
        XCTAssertTrue(newRegistration.waitForExistence(timeout: 30))
        newRegistration.tap()
        XCTAssertTrue(app.textFields["registration.nameTextField"].waitForExistence(timeout: 30))
    }

    @MainActor
    func test登録0人のときは新規登録に進める() {
        let app = start()
        XCTAssertTrue(app.staticTexts["personSearch.noProfilesNotice"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["personSearch.candidate.0"].exists)
        attach(app, name: "person-search-no-profiles")
        app.buttons["personSearch.newRegistrationButton"].tap()
        XCTAssertTrue(app.textFields["registration.nameTextField"].waitForExistence(timeout: 30))
    }

    @MainActor
    func test相手の発話が足りないときは追加録音を促し追加すると候補を表示する() {
        let app = start(scenario: "personSearchShortPartner")
        let additional = app.buttons["personSearch.additionalRecordingButton"]
        XCTAssertTrue(additional.waitForExistence(timeout: 30))
        XCTAssertTrue(app.descendants(matching: .any)["personSearch.insufficientSpeechNotice"].exists)
        XCTAssertFalse(app.buttons["personSearch.candidate.0"].exists)
        attach(app, name: "person-search-insufficient-speech")

        additional.tap()
        // 録音画面を再利用して追加録音する
        let stop = app.buttons["recording.stopButton"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        let add = app.buttons["recording.addButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let first = app.buttons["personSearch.candidate.0"]
        XCTAssertTrue(first.waitForExistence(timeout: 30))
        XCTAssertTrue(first.label.contains("山田 太郎"))
    }

    @MainActor
    func test相手の発話が足りないときは追加せずに手動で選べる() {
        let app = start(scenario: "personSearchShortPartner")
        let skip = app.buttons["personSearch.skipAdditionalRecordingButton"]
        XCTAssertTrue(skip.waitForExistence(timeout: 30))
        skip.tap()
        let option = app.buttons["personSearch.manualSelection.0"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        XCTAssertTrue(app.staticTexts["profileDetail.name"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
