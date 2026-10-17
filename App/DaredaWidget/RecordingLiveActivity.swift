import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// 録音中は経過時間と停止ボタン、解析後は相手の候補 1 名と閉じるボタンを表示する。
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            RecordingActivityContent(phase: context.state.phase)
                .padding()
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            let phase = context.state.phase
            return DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    RecordingActivityContent(phase: phase)
                }
            } compactLeading: {
                RecordingActivityIcon(phase: phase)
            } compactTrailing: {
                RecordingActivityCompactTrailing(phase: phase)
            } minimal: {
                RecordingActivityIcon(phase: phase)
            }
        }
    }
}

struct RecordingActivityContent: View {
    let phase: RecordingActivityAttributes.Phase

    var body: some View {
        switch phase {
        case let .recording(startedAt):
            HStack {
                Label {
                    Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                        .font(.title2.monospacedDigit())
                } icon: {
                    Image(systemName: "mic.fill").foregroundStyle(.red)
                }
                Spacer()
                Button(intent: StopRecordingIntent()) {
                    Label("停止", systemImage: "stop.fill")
                }
                .tint(.red)
            }
        case let .analyzing(stage):
            HStack {
                ProgressView()
                VStack(alignment: .leading) {
                    Text("音声を解析しています")
                        .font(.headline)
                    Text(stage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        case let .candidate(candidate):
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading) {
                        Text(candidate.name)
                            .font(.headline)
                        Text(candidate.affiliation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    DismissButton()
                }
                if candidate.metAt != nil || candidate.placeName != nil {
                    HStack(spacing: 12) {
                        if let metAt = candidate.metAt {
                            Label(metAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        }
                        if let placeName = candidate.placeName {
                            Label(placeName, systemImage: "mappin.and.ellipse")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                if let summary = candidate.summary {
                    Text(summary)
                        .font(.caption)
                        .lineLimit(3)
                }
            }
        case let .message(message):
            HStack {
                Text(message)
                    .font(.subheadline)
                Spacer()
                DismissButton()
            }
        }
    }
}

private struct DismissButton: View {
    var body: some View {
        Button(intent: DismissRecordingActivityIntent()) {
            Label("閉じる", systemImage: "xmark")
                .labelStyle(.iconOnly)
        }
        .buttonBorderShape(.circle)
    }
}

private struct RecordingActivityIcon: View {
    let phase: RecordingActivityAttributes.Phase

    var body: some View {
        switch phase {
        case .recording:
            Image(systemName: "mic.fill").foregroundStyle(.red)
        case .analyzing:
            Image(systemName: "waveform")
        case .candidate:
            Image(systemName: "person.fill")
        case .message:
            Image(systemName: "exclamationmark.circle")
        }
    }
}

private struct RecordingActivityCompactTrailing: View {
    let phase: RecordingActivityAttributes.Phase

    var body: some View {
        switch phase {
        case let .recording(startedAt):
            Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                .monospacedDigit()
                .frame(maxWidth: 44)
        case .analyzing:
            ProgressView()
        case let .candidate(candidate):
            Text(candidate.name)
                .lineLimit(1)
                .frame(maxWidth: 64)
        case .message:
            EmptyView()
        }
    }
}

#Preview("録音中", as: .content, using: RecordingActivityAttributes()) {
    RecordingLiveActivity()
} contentStates: {
    RecordingActivityAttributes.ContentState(phase: .recording(startedAt: Date(timeIntervalSince1970: 1_800_000_000)))
    RecordingActivityAttributes.ContentState(phase: .analyzing(stage: "文字起こし中"))
    RecordingActivityAttributes.ContentState(phase: .candidate(RecordingActivityAttributes.Candidate(
        name: "田中 太郎",
        affiliation: "株式会社サンプル",
        metAt: Date(timeIntervalSince1970: 1_800_000_000),
        placeName: "札幌駅",
        summary: "JPHACKS で出会い、音声処理について話した。"
    )))
    RecordingActivityAttributes.ContentState(phase: .message("登録済みの人物が見つかりませんでした。"))
}
