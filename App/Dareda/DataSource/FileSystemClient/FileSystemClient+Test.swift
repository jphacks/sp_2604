import Foundation

nonisolated extension FileSystemClient {
    /// ディレクトリの存在だけを覚えるメモリ上のテストダブル。
    static func inMemory() -> FileSystemClient {
        let storage = InMemoryDirectories()
        return FileSystemClient(
            temporaryDirectory: { URL(fileURLWithPath: "/in-memory/tmp", isDirectory: true) },
            fileExists: { storage.contains($0) },
            createDirectory: { storage.insert($0) },
            contentsOfDirectory: { storage.children(of: $0) },
            removeItem: { storage.remove($0) }
        )
    }
}

private nonisolated final class InMemoryDirectories: @unchecked Sendable {
    private let lock = NSLock()
    private var paths: Set<String> = []

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

    func remove(_ url: URL) {
        lock.withLock {
            let prefix = url.standardizedFileURL.path
            paths = paths.filter { $0 != prefix && !$0.hasPrefix(prefix + "/") }
        }
    }
}
