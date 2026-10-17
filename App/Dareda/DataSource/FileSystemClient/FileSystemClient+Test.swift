import Foundation

nonisolated extension FileSystemClient {
    /// ディレクトリとファイルの内容を覚えるメモリ上のテストダブル。
    static func inMemory(removeFailures: Int = 0) -> FileSystemClient {
        let storage = InMemoryDirectories(removeFailures: removeFailures)
        return FileSystemClient(
            temporaryDirectory: { URL(fileURLWithPath: "/in-memory/tmp", isDirectory: true) },
            fileExists: { storage.contains($0) },
            createDirectory: { storage.insert($0) },
            contentsOfDirectory: { storage.children(of: $0) },
            removeItem: { try storage.remove($0) },
            readData: { storage.data(at: $0) },
            writeData: { storage.write($0, to: $1) }
        )
    }
}

private nonisolated final class InMemoryDirectories: @unchecked Sendable {
    private let lock = NSLock()
    private var paths: Set<String> = []
    private var files: [String: Data] = [:]
    private var remainingRemoveFailures: Int

    init(removeFailures: Int) { remainingRemoveFailures = removeFailures }

    func contains(_ url: URL) -> Bool {
        lock.withLock { paths.contains(url.standardizedFileURL.path) }
    }

    func insert(_ url: URL) {
        lock.withLock {
            var current = url.standardizedFileURL
            while current.path != "/", paths.insert(current.path).inserted {
                current = current.deletingLastPathComponent()
            }
        }
    }

    func children(of url: URL) -> [URL] {
        lock.withLock {
            let parent = url.standardizedFileURL.path
            return paths
                .filter { URL(fileURLWithPath: $0).deletingLastPathComponent().path == parent }
                .map { URL(fileURLWithPath: $0, isDirectory: true) }
        }
    }

    func remove(_ url: URL) throws {
        try lock.withLock {
            if remainingRemoveFailures > 0 {
                remainingRemoveFailures -= 1
                throw CocoaError(.fileWriteNoPermission)
            }
            let prefix = url.standardizedFileURL.path
            paths = paths.filter { $0 != prefix && !$0.hasPrefix(prefix + "/") }
            files = files.filter { $0.key != prefix && !$0.key.hasPrefix(prefix + "/") }
        }
    }

    func data(at url: URL) -> Data? {
        lock.withLock { files[url.standardizedFileURL.path] }
    }

    func write(_ data: Data, to url: URL) {
        lock.withLock {
            let path = url.standardizedFileURL.path
            files[path] = data
            paths.insert(path)
        }
    }
}
