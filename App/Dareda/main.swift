import Dependencies
import FoundationModels
import SQLiteData
import SwiftUI

let scenario = ProcessInfo.processInfo.environment["UI_TEST_SCENARIO"]

prepareDependencies {
    if let scenario {
        let database = try! appDatabase(inMemory: true)
        if scenario == "profiles" || scenario == "personSearchNotificationTapped" {
            try! seedProfilesScenario(database)
        }
        // 本人の声の登録画面を検証するシナリオ以外は、登録済みの状態から始める
        if !scenario.hasPrefix("voiceEnrollment") {
            try! seedSelfVoiceScenario(database)
        }
        $0.defaultDatabase = database
        $0.audioRecorderClient = .inMemory()
        $0.fileSystemClient = .inMemory()
        $0.speakerEmbeddingModelClient = .stub()
        switch scenario {
        case "voiceEnrollmentShort", "voiceReregistrationShort":
            $0.audioFileClient = .speech(seconds: 10, amplitude: 0.3)
        // 登録に必要な有効発話時間 (ProvisionalParameters) の境界を検証する
        case "voiceEnrollmentJustBelowRequired":
            $0.audioFileClient = .speech(seconds: 29, amplitude: 0.3)
        case "voiceEnrollmentJustAboveRequired":
            $0.audioFileClient = .speech(seconds: 31, amplitude: 0.3)
        case "voiceEnrollmentQuiet":
            $0.audioFileClient = .speech(seconds: 35, amplitude: 0.005)
        default:
            $0.audioFileClient = .speech(seconds: 35, amplitude: 0.3)
        }
        $0.appSettingsClient = .inMemory()
        $0.userDefaultsClient = .inMemory()
        $0.userNotificationClient =
            if scenario == "personSearchNotificationTapped" {
                .inMemory(tappedUserInfo: ["kind": "personSearch"])
            } else {
                .inMemory()
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
        case "microphoneDenied", "settingsFailure":
            $0.audioRecorderClient = .inMemory(permissions: [.denied])
        case "microphoneSettingsGranted":
            $0.audioRecorderClient = .inMemory(permissions: [.denied, .granted], permissionAfterRequest: false)
        default:
            break
        }
        if scenario == "settingsFailure" {
            $0.appSettingsClient = .inMemory { throw CocoaError(.featureUnsupported) }
        }
        switch scenario {
        case "unsupported":
            $0.foundationModelsClient = .inMemory(availability: [.unavailable(.deviceNotEligible)])
        case "appleIntelligenceDisabled":
            $0.foundationModelsClient = .inMemory(availability: [.unavailable(.appleIntelligenceNotEnabled)])
        case "modelNotReady":
            $0.foundationModelsClient = .inMemory(availability: [.unavailable(.modelNotReady)])
        case "recovering":
            // 1 回目は準備中、再判定で利用可になる
            $0.foundationModelsClient = .inMemory(availability: [.unavailable(.modelNotReady), .available])
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
