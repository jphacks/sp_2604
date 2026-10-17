import Dependencies
import FoundationModels
import Logging
import SQLiteData
import SwiftUI

LoggingSystem.bootstrap { label in
    var handler = StreamLogHandler.standardError(label: label)
    #if DEBUG
        handler.logLevel = .debug
    #else
        handler.logLevel = .info
    #endif
    return handler
}

let scenario = ProcessInfo.processInfo.environment["UI_TEST_SCENARIO"]

prepareDependencies {
    if let scenario {
        let database = try! appDatabase(inMemory: true)
        if scenario == "profiles" || scenario == "personSearchNotificationTapped" {
            try! seedProfilesScenario(database)
        }
        if scenario.hasPrefix("personSearch") && scenario != "personSearchNotificationTapped" {
            try! seedPersonSearchScenario(database)
        }
        // 本人の声の登録画面を検証するシナリオ以外は、登録済みの状態から始める
        if !scenario.hasPrefix("voiceEnrollment") {
            try! seedSelfVoiceScenario(database, matchesStub: scenario != "processingSelfUnknown")
        }
        $0.defaultDatabase = database
        $0.audioRecorderClient = .inMemory()
        $0.fileSystemClient = .inMemory()
        $0.speakerEmbeddingModelClient = .stub()
        switch scenario {
        case "processingSelfUnknown":
            // 本人 (0〜15 秒) と相手 (15〜30 秒) のそれぞれに発言を割り当てる
            $0.backgroundTaskClient = .inMemory()
            $0.speechClient = .inMemory(segments: [
                (text: "はじめまして、田中です。", start: 0, end: 2.5),
                (text: "よろしくお願いします。", start: 16, end: 18),
            ])
            $0.fluidAudioClient = .twoSpeakers()
        case "processingFailure":
            // 話者分離は 1 回目だけ失敗し、文字起こしは 2 回目以降失敗する。再試行で完了すれば、
            // 完了済みの文字起こしを再実行していないことになる。
            $0.backgroundTaskClient = .inMemory()
            $0.speechClient = .inMemory(succeedsOnce: true)
            $0.fluidAudioClient = .twoSpeakers(failureCount: 1)
        case "analysisSuspended":
            // 話者分離中にバックグラウンドへ移行して打ち切られる。文字起こしは 2 回目以降失敗するので、
            // 復帰後の再試行で完了すれば、完了済みの文字起こしを再実行していないことになる。
            $0.backgroundTaskClient = .inMemory(expiresOnEnteringBackground: true)
            $0.speechClient = .inMemory(succeedsOnce: true)
            $0.fluidAudioClient = .twoSpeakers(delay: .seconds(8))
        default:
            $0.backgroundTaskClient = .inMemory()
            $0.speechClient = .inMemory()
            $0.fluidAudioClient = .twoSpeakers()
        }
        switch scenario {
        case "voiceEnrollmentShort", "voiceReregistrationShort":
            $0.audioFileClient = .speech(seconds: 10, amplitude: 0.3)
        // 登録に必要な有効発話時間 (ProvisionalParameters) の境界を検証する
        case "voiceEnrollmentJustBelowRequired":
            $0.audioFileClient = .speech(seconds: 29, amplitude: 0.3)
        case "voiceEnrollmentJustAboveRequired":
            $0.audioFileClient = .speech(seconds: 31, amplitude: 0.3)
        default:
            $0.audioFileClient = .speech(seconds: 35, amplitude: 0.3)
        }
        switch scenario {
        case "registrationNoPartner":
            // 本人の声だけの録音 (相手を分離できない)
            $0.fluidAudioClient = .oneSpeaker()
        case "personSearchShortPartner":
            // 相手の発話が 6 秒しかない。追加録音 (同じ会話) と合わせると照合できる
            $0.fluidAudioClient = .twoSpeakers(partnerEnd: 21)
        case "registrationSaveFailure":
            $0.sqliteDataClient = .failing(insertProfileFailures: 1)
        default:
            break
        }
        $0.watchConnectivityClient = .inMemory()
        $0.mapKitClient = .inMemory()
        $0.appSettingsClient = .inMemory()
        $0.bundleClient = .inMemory()
        $0.userDefaultsClient = .inMemory()
        $0.userNotificationClient =
            if scenario == "personSearchNotificationTapped" {
                .inMemory(tappedUserInfo: ["kind": "personSearch"])
            } else {
                .inMemory()
            }
        if scenario.hasPrefix("processing") || scenario.hasPrefix("personSearch") || scenario == "analysisSuspended"
            || scenario == "registration" || scenario == "registrationSaveFailure" {
            $0.audioFileClient = .conversation()
        }
        if scenario == "recordingCleanupFailure" {
            let client = FileSystemClient.inMemory(removeFailures: 1)
            try! client.createDirectory(client.temporaryDirectory().appending(path: "Recordings"))
            $0.fileSystemClient = client
        }
        switch scenario {
        case "recordingLimit":
            $0.audioRecorderClient = .inMemory(elapsedTimes: [0] + Array(repeating: 540, count: 20) + [600])
        case "recordingInterrupted":
            $0.audioRecorderClient = .inMemory(elapsedTimes: [42], interruptionDelay: .seconds(2))
        case "recordingFailure":
            $0.audioRecorderClient = .inMemory(failsToStart: true)
        case "microphoneGranted":
            $0.audioRecorderClient = .inMemory(permissions: [.granted], permissionAfterRequest: false)
        case "microphoneUndeterminedGranted":
            $0.audioRecorderClient = .inMemory(permissions: [.undetermined])
        case "microphoneUndeterminedDenied":
            $0.audioRecorderClient = .inMemory(permissions: [.undetermined], permissionAfterRequest: false)
        case "microphoneDenied", "settingsPermissions":
            $0.audioRecorderClient = .inMemory(permissions: [.denied])
        case "microphoneSettingsGranted":
            $0.audioRecorderClient = .inMemory(permissions: [.denied, .granted], permissionAfterRequest: false)
        default:
            break
        }
        switch scenario {
        case "unsupported":
            $0.foundationModelsClient = .inMemory(availability: [.unavailable(.deviceNotEligible)])
        case "appleIntelligenceDisabled":
            $0.foundationModelsClient = .inMemory(availability: [.unavailable(.appleIntelligenceNotEnabled)])
        case "modelNotReady":
            $0.foundationModelsClient = .inMemory(availability: [.unavailable(.modelNotReady)])
        default:
            $0.foundationModelsClient = .inMemory()
        }
    } else {
        $0.defaultDatabase = try! appDatabase()
        // 起動直後の通知タップを受け取れるよう、delegate を先に登録しておく
        _ = $0.userNotificationClient
    }
}

DaredaApp.main()
