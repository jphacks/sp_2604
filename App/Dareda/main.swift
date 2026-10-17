import Dependencies
import SQLiteData
import SwiftUI

let scenario = ProcessInfo.processInfo.environment["UI_TEST_SCENARIO"]

prepareDependencies {
    if scenario != nil {
        $0.defaultDatabase = try! appDatabase(inMemory: true)
    } else {
        $0.defaultDatabase = try! appDatabase()
    }
}

DaredaApp.main()
