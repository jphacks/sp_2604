import Dependencies
import DependenciesMacros
import Foundation

/// 実機検証 (#27) のための計測値の記録。処理時間・メモリ・類似度などを `metrics.<対象>` の名前で出力する。
@DependencyClient
nonisolated struct MetricsGateway: Sendable {
    var recordValue: @Sendable (_ name: String, _ value: Double) -> Void
    var recordDuration: @Sendable (_ name: String, _ seconds: TimeInterval) -> Void
    /// その時点のアプリのメモリ使用量 (MB) を記録する。
    var recordMemoryFootprint: @Sendable (_ name: String) -> Void
}

nonisolated extension MetricsGateway: DependencyKey {
    static let liveValue: MetricsGateway = {
        let impl = MetricsGatewayImpl()
        return MetricsGateway(
            recordValue: impl.recordValue(_:_:),
            recordDuration: impl.recordDuration(_:_:),
            recordMemoryFootprint: impl.recordMemoryFootprint(_:)
        )
    }()
}

nonisolated extension DependencyValues {
    var metricsGateway: MetricsGateway {
        get { self[MetricsGateway.self] }
        set { self[MetricsGateway.self] = newValue }
    }
}

private nonisolated struct MetricsGatewayImpl: Sendable {
    @Dependency(\.metricsLogClient) private var metricsLogClient

    func recordValue(_ name: String, _ value: Double) {
        metricsLogClient.log(name, value, "")
    }

    func recordDuration(_ name: String, _ seconds: TimeInterval) {
        metricsLogClient.log(name, seconds, "s")
    }

    func recordMemoryFootprint(_ name: String) {
        guard let bytes = metricsLogClient.memoryFootprint() else { return }
        metricsLogClient.log(name, Double(bytes) / 1_048_576, "MB")
    }
}
