import Dependencies
import Foundation
import SQLiteData

/// UI テスト用の初期データを投入する。
nonisolated func seedProfilesScenario(_ database: any DatabaseWriter) throws {
    let full = UUID()
    let minimal = UUID()
    try database.write { db in
        try ProfileRecord.insert {
            ProfileRecord(id: full, name: "山田 太郎", affiliation: "株式会社サンプル", vector: Data())
            ProfileRecord(id: minimal, name: "佐藤 花子", affiliation: "", vector: Data())
            ProfileRecord(id: UUID(), name: "鈴木 一郎", affiliation: "サンプル大学", vector: Data())
        }.execute(db)
        try EncounterRecord.insert {
            EncounterRecord(
                id: UUID(), profileID: full, summary: "新規事業について話した",
                metAt: Date(timeIntervalSince1970: 1_790_000_000),
                placeName: "渋谷駅", latitude: 35.658, longitude: 139.701
            )
            EncounterRecord(
                id: UUID(), profileID: minimal, summary: "",
                metAt: Date(timeIntervalSince1970: 1_790_100_000),
                placeName: nil, latitude: nil, longitude: nil
            )
        }.execute(db)
    }
}

/// UI テスト用に本人の声を登録済みにする。
nonisolated func seedSelfVoiceScenario(_ database: any DatabaseWriter) throws {
    try database.write { db in
        try SelfVoiceRecord.insert {
            SelfVoiceRecord(
                id: SelfVoiceRecord.singletonID, vector: Data(),
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }.execute(db)
    }
}
