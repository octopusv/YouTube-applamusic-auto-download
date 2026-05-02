import SwiftUI

struct AccessibilityBanner: View {
    @EnvironmentObject var notice: AccessibilityNotice

    var body: some View {
        if notice.isVisible {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 1) {
                    Text("アクセシビリティ権限の確認をお願いします")
                        .font(.callout.weight(.medium))
                    Text("更新後はミュージック.app の操作（クラウド同期・アルバム編集など）に再付与が必要なことがあります。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Button("設定を開く") {
                    notice.openSystemSettings()
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                Button("閉じる") {
                    notice.dismiss()
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.purple.opacity(0.1))
            .overlay(Divider(), alignment: .bottom)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
