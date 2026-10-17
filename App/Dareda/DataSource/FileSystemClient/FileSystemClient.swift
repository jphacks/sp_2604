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
    /// ファイルの内容を読み出す。存在しない場合は `nil`。
    var readData: @Sendable (_ url: URL) throws -> Data?
    /// ファイルに書き込む。既にある場合は置き換える。
    var writeData: @Sendable (_ data: Data, _ url: URL) throws -> Void
    /// ファイルをコピーする。コピー元がセキュリティスコープ付き URL (ファイルアプリで選んだファイルなど) でも読み出せる。
    var copyItem: @Sendable (_ source: URL, _ destination: URL) throws -> Void
}

nonisolated extension FileSystemClient: DependencyKey {
    static let liveValue: FileSystemClient = {
        let impl = FileSystemClientImpl()
        return FileSystemClient(
            temporaryDirectory: impl.temporaryDirectory,
            fileExists: impl.fileExists(_:),
            createDirectory: impl.createDirectory(_:),
            contentsOfDirectory: impl.contentsOfDirectory(_:),
            removeItem: impl.removeItem(_:),
            readData: impl.readData(_:),
            writeData: impl.writeData(_:to:),
            copyItem: impl.copyItem(_:to:)
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

    func readData(_ url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func writeData(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    func copyItem(_ source: URL, to destination: URL) throws {
        let isAccessing = source.startAccessingSecurityScopedResource()
        defer { if isAccessing { source.stopAccessingSecurityScopedResource() } }
        try FileManager.default.copyItem(at: source, to: destination)
    }
}
