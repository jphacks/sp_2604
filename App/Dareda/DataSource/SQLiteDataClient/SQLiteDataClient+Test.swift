import Foundation
import Synchronization

nonisolated extension SQLiteDataClient {
    /// プロフィールの追加が最初の `insertProfileFailures` 回だけ失敗するテストダブル。それ以外は本物の実装を使う。
    static func failing(insertProfileFailures: Int) -> SQLiteDataClient {
        let remaining = Mutex(insertProfileFailures)
        var client = liveValue
        client.insertProfile = { profile, encounter in
            let fails = remaining.withLock { value in
                defer { value = max(value - 1, 0) }
                return value > 0
            }
            if fails { throw CocoaError(.fileWriteUnknown) }
            try await liveValue.insertProfile(profile, encounter)
        }
        return client
    }
}
