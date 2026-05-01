import SwiftUI

struct UpdateBanner: View {
    @EnvironmentObject var updater: YtDlpUpdater

    var body: some View {
        Group {
            switch updater.state {
            case .available(let current, let latest):
                banner(
                    icon: "arrow.down.circle.fill",
                    tint: .orange,
                    title: "yt-dlp の更新があります",
                    detail: "\(current) → \(latest)",
                    actionTitle: "更新",
                    action: { Task { await updater.update() } },
                    dismissable: true
                )
            case .updating:
                banner(
                    icon: "arrow.triangle.2.circlepath",
                    tint: .blue,
                    title: "yt-dlp を更新中…",
                    detail: "ターミナル不要。完了までしばらくお待ちください。",
                    actionTitle: nil,
                    action: nil,
                    dismissable: false,
                    showSpinner: true
                )
            case .justUpdated(let version):
                banner(
                    icon: "checkmark.circle.fill",
                    tint: .green,
                    title: "yt-dlp を更新しました",
                    detail: "現在のバージョン: \(version)",
                    actionTitle: "閉じる",
                    action: { updater.state = .current(version: version) },
                    dismissable: true
                )
            case .failed(let msg):
                banner(
                    icon: "exclamationmark.triangle.fill",
                    tint: .red,
                    title: "更新に失敗",
                    detail: String(msg.prefix(120)),
                    actionTitle: "閉じる",
                    action: { updater.state = .unknown },
                    dismissable: true
                )
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func banner(icon: String,
                        tint: Color,
                        title: String,
                        detail: String,
                        actionTitle: String?,
                        action: (() -> Void)?,
                        dismissable: Bool,
                        showSpinner: Bool = false) -> some View {
        HStack(spacing: 12) {
            if showSpinner {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tint.opacity(0.1))
        .overlay(Divider(), alignment: .bottom)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
