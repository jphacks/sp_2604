import Darwin
import Dependencies
import DependenciesMacros
import Foundation
import os

/// 実機検証 (#27) のための計測値を統合ログ (Console.app) と signpost (Instruments) に出力する。
/// info レベルで出力するため、ログを採取していない通常利用時はほとんど負荷がかからず、挙動にも影響しない。
@DependencyClient
nonisolated struct MetricsLogClient: Sendable {
    var log: @Sendable (_ name: String, _ value: Double, _ unit: String) -> Void
    /// アプリの物理メモリ使用量 (バイト)。取得できない場合は nil。
    var memoryFootprint: @Sendable () -> UInt64? = { nil }
}

nonisolated extension MetricsLogClient: DependencyKey {
    static let liveValue: MetricsLogClient = {
        let impl = MetricsLogClientImpl()
        return MetricsLogClient(
            log: impl.log(_:_:_:),
            memoryFootprint: impl.memoryFootprint
        )
    }()

    static let testValue = MetricsLogClient.noop()
    static let previewValue = MetricsLogClient.noop()
}

nonisolated extension DependencyValues {
    var metricsLogClient: MetricsLogClient {
        get { self[MetricsLogClient.self] }
        set { self[MetricsLogClient.self] = newValue }
    }
}

nonisolated extension MetricsLogClient {
    /// 何も出力しないテストダブル
    static func noop(memoryFootprint: UInt64? = nil) -> Self {
        Self(log: { _, _, _ in }, memoryFootprint: { memoryFootprint })
    }
}

private nonisolated struct MetricsLogClientImpl: Sendable {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Dareda"
    private static let logger = Logger(subsystem: subsystem, category: "Metrics")
    private static let signposter = OSSignposter(subsystem: subsystem, category: "Metrics")

    func log(_ name: String, _ value: Double, _ unit: String) {
        Self.logger.info("\(name, privacy: .public)=\(value, privacy: .public)\(unit, privacy: .public)")
        Self.signposter.emitEvent("Metric", "\(name, privacy: .public)=\(value, privacy: .public)\(unit, privacy: .public)")
    }

    func memoryFootprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : nil
    }
}
