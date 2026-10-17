import Dependencies
import FoundationModels
import SQLiteData
import SwiftUI

let scenario = ProcessInfo.processInfo.environment["UI_TEST_SCENARIO"]

prepareDependencies {
    if let scenario {
        $0.defaultDatabase = try! appDatabase(inMemory: true)
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
    }
}

DaredaApp.main()
