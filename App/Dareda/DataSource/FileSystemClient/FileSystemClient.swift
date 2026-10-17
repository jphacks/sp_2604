import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
nonisolated struct FileSystemClient: Sendable {
    var temporaryDirectory: @Sendable () -> URL = { URL(fileURLWithPath: NSTemporaryDirectory()) }
    var fileExists: @Sendable (_ url: URL) -> Bool = { _ in false }
    var createDirectory: @Sendable (_ url: URL) throws -> Void
    var contentsOfDirectory: @Sendable (_ url: URL) throws -> [URL]
    var removeItem: @Sendable (_ url: URL) throws -> Void
}

nonisolated extension FileSystemClient: DependencyKey {
    static let liveValue: FileSystemClient = {
        let impl = FileSystemClientImpl()
        return FileSystemClient(
            temporaryDirectory: impl.temporaryDirectory,
            fileExists: impl.fileExists(_:),
            createDirectory: impl.createDirectory(_:),
            contentsOfDirectory: impl.contentsOfDirectory(_:),
            removeItem: impl.removeItem(_:)
        )
    }()

    static let testValue = FileSystemClient.inMemory()
    static let previewValue = FileSystemClient.inMemory()
}

nonisolated extension DependencyValues {
    var fileSystemClient: FileSystemClient {
        get { self[FileSystemClient.self] }
        set { self[FileSystemClient.self] = newValue }
    }
}

private nonisolated struct FileSystemClientImpl: Sendable {
    func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
    }

    func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func createDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func contentsOfDirectory(_ url: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }

    func removeItem(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
