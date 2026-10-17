import Dependencies
import SQLiteData
import SwiftUI

let scenario = ProcessInfo.processInfo.environment["UI_TEST_SCENARIO"]

prepareDependencies {
    if let scenario {
        let database = try! appDatabase(inMemory: true)
        if scenario == "profiles" {
            try! seedProfilesScenario(database)
        }
        $0.defaultDatabase = database
    } else {
        $0.defaultDatabase = try! appDatabase()
    }
}

DaredaApp.main()
