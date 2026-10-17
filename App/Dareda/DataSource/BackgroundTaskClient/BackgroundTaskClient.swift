import BackgroundTasks
import Dependencies
import DependenciesMacros
import Synchronization
import UIKit

/// `BGContinuedProcessingTask` によるバックグラウンドでの処理の継続。
/// 進捗はシステムの UI に表示され、ユーザーはそこから処理を止められる (止めると打ち切りとして扱う)。
/// 継続処理タスクを開始できない場合は `UIApplication.beginBackgroundTask` で実行時間の延長だけを行う。
@DependencyClient
nonisolated struct BackgroundTaskClient: Sendable {
    /// バックグラウンド実行を開始し、終了時に渡す識別子を返す。
    /// OS やユーザーが処理を打ち切るときは `expirationHandler` を呼び、その後このタスクを終了する。
    var begin: @Sendable (
        _ title: String, _ expirationHandler: @escaping @Sendable () -> Void
    ) async -> Int = { _, _ in 0 }
    /// システムの UI に表示する処理状況と進捗を更新する。
    var update: @Sendable (
        _ identifier: Int, _ subtitle: String, _ completedUnitCount: Int64, _ totalUnitCount: Int64
    ) async -> Void
    var end: @Sendable (_ identifier: Int) async -> Void
}

nonisolated extension BackgroundTaskClient: DependencyKey {
    static let liveValue: BackgroundTaskClient = {
        let impl = BackgroundTaskClientImpl()
        return BackgroundTaskClient(
            begin: impl.begin(title:expirationHandler:),
            update: impl.update(identifier:subtitle:completedUnitCount:totalUnitCount:),
            end: impl.end(identifier:)
        )
    }()

    static let testValue = BackgroundTaskClient.inMemory()
    static let previewValue = BackgroundTaskClient.inMemory()
}

nonisolated extension DependencyValues {
    var backgroundTaskClient: BackgroundTaskClient {
        get { self[BackgroundTaskClient.self] }
        set { self[BackgroundTaskClient.self] = newValue }
    }
}

private nonisolated final class BackgroundTaskClientImpl: Sendable {
    /// Info.plist の `BGTaskSchedulerPermittedIdentifiers` に `<bundle ID>.processing.*` として登録している。
    private static let identifierPrefix = "\(Bundle.main.bundleIdentifier ?? "com.kantacky.Dareda").processing"

    private struct Entry {
        var title: String
        var subtitle = ""
        var completedUnitCount: Int64 = 0
        var totalUnitCount: Int64 = 1
        var task: ContinuedProcessingTask?
        var fallbackIdentifier: UIBackgroundTaskIdentifier?
    }

    /// `BGContinuedProcessingTask` は `Sendable` ではないため、`Mutex` の中でだけ扱う。
    private struct ContinuedProcessingTask: @unchecked Sendable {
        let value: BGContinuedProcessingTask
    }

    private struct State {
        var nextIdentifier = 1
        var entries: [Int: Entry] = [:]
    }

    private let state = Mutex(State())

    func begin(title: String, expirationHandler: @escaping @Sendable () -> Void) async -> Int {
        let identifier = state.withLock { state in
            defer { state.nextIdentifier += 1 }
            state.entries[state.nextIdentifier] = Entry(title: title)
            return state.nextIdentifier
        }
        // 継続処理タスクは識別子ごとに動的に登録できる。前回の起動で登録した識別子と重ならないよう UUID を付ける。
        let taskIdentifier = "\(Self.identifierPrefix).\(UUID().uuidString)"
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) {
            [self] task in
            guard let task = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            launch(task, identifier: identifier, expirationHandler: expirationHandler)
        }
        let request = BGContinuedProcessingTaskRequest(identifier: taskIdentifier, title: title, subtitle: "")
        // ユーザー操作を起点とする処理なので、すぐに開始できなければ待たずに代替手段へ切り替える。
        request.strategy = .fail
        do {
            guard registered else { throw CocoaError(.featureUnsupported) }
            try await BGTaskScheduler.shared.submitTaskRequest(request)
        } catch {
            await beginFallback(identifier: identifier, expirationHandler: expirationHandler)
        }
        return identifier
    }

    func update(identifier: Int, subtitle: String, completedUnitCount: Int64, totalUnitCount: Int64) async {
        state.withLock { state in
            guard var entry = state.entries[identifier] else { return }
            entry.subtitle = subtitle
            entry.completedUnitCount = completedUnitCount
            entry.totalUnitCount = totalUnitCount
            state.entries[identifier] = entry
            if let task = entry.task { Self.apply(entry, to: task.value) }
        }
    }

    func end(identifier: Int) async {
        guard let entry = state.withLock({ $0.entries.removeValue(forKey: identifier) }) else { return }
        if let task = entry.task {
            task.value.progress.completedUnitCount = task.value.progress.totalUnitCount
            task.value.setTaskCompleted(success: true)
        }
        if let fallbackIdentifier = entry.fallbackIdentifier {
            await MainActor.run { UIApplication.shared.endBackgroundTask(fallbackIdentifier) }
        }
    }

    private func launch(
        _ task: BGContinuedProcessingTask, identifier: Int, expirationHandler: @escaping @Sendable () -> Void
    ) {
        let wrapped = ContinuedProcessingTask(value: task)
        task.expirationHandler = { [self] in
            // 打ち切り時に完了を報告しないとアプリが強制終了されるため、ここで終了する。
            guard state.withLock({ $0.entries.removeValue(forKey: identifier) }) != nil else { return }
            expirationHandler()
            wrapped.value.setTaskCompleted(success: false)
        }
        let isRunning = state.withLock { state in
            // 開始を待たずに処理が終わっていた場合はすぐに完了する。
            guard var entry = state.entries[identifier] else { return false }
            entry.task = wrapped
            state.entries[identifier] = entry
            Self.apply(entry, to: task)
            return true
        }
        if !isRunning { task.setTaskCompleted(success: true) }
    }

    private static func apply(_ entry: Entry, to task: BGContinuedProcessingTask) {
        task.progress.totalUnitCount = entry.totalUnitCount
        task.progress.completedUnitCount = entry.completedUnitCount
        task.updateTitle(entry.title, subtitle: entry.subtitle)
    }

    private func beginFallback(identifier: Int, expirationHandler: @escaping @Sendable () -> Void) async {
        let fallbackIdentifier = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: Self.identifierPrefix) { [self] in
                guard let entry = state.withLock({ $0.entries.removeValue(forKey: identifier) }) else { return }
                expirationHandler()
                if let fallbackIdentifier = entry.fallbackIdentifier {
                    UIApplication.shared.endBackgroundTask(fallbackIdentifier)
                }
            }
        }
        let isRunning = state.withLock { state in
            guard state.entries[identifier] != nil else { return false }
            state.entries[identifier]?.fallbackIdentifier = fallbackIdentifier
            return true
        }
        if !isRunning {
            await MainActor.run { UIApplication.shared.endBackgroundTask(fallbackIdentifier) }
        }
    }
}
