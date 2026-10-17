import Foundation
import SQLiteData

/// アプリのデータベースを開き、マイグレーションを適用する。
/// - Parameter inMemory: `true` のときはインメモリのデータベースを使う (UI テスト用)。
nonisolated func appDatabase(inMemory: Bool = false) throws -> any DatabaseWriter {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true

    let database: any DatabaseWriter
    if inMemory {
        database = try DatabaseQueue(configuration: configuration)
    } else {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        database = try DatabaseQueue(
            path: directory.appending(path: "db.sqlite").path(percentEncoded: false),
            configuration: configuration
        )
    }

    try migrator.migrate(database)
    return database
}

private nonisolated var migrator: DatabaseMigrator {
    var migrator = DatabaseMigrator()
    #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
    #endif

    migrator.registerMigration("Create initial tables") { db in
        try #sql(
            """
            CREATE TABLE "selfVoices" (
              "id" INTEGER PRIMARY KEY NOT NULL CHECK ("id" = 1),
              "vector" BLOB NOT NULL,
              "createdAt" TEXT NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "profiles" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "name" TEXT NOT NULL,
              "affiliation" TEXT NOT NULL,
              "vector" BLOB NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE TABLE "encounters" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "profileID" TEXT NOT NULL UNIQUE REFERENCES "profiles"("id") ON DELETE CASCADE,
              "summary" TEXT NOT NULL,
              "metAt" TEXT NOT NULL,
              "placeName" TEXT,
              "latitude" REAL,
              "longitude" REAL
            ) STRICT
            """
        )
        .execute(db)
    }

    return migrator
}
