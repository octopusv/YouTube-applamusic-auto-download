import SwiftUI
import AppKit

struct ErrorView: View {
    let message: String
    let onReset: () -> Void
    var onRetry: (() -> Void)? = nil

    @EnvironmentObject var settings: AppSettings
    @State private var showDetails = false

    private enum Kind {
        case botDetection
        case cookieAccessDenied
        case generic
    }

    private var kind: Kind {
        let lower = message.lowercased()
        if lower.contains("sign in to confirm you") || lower.contains("confirm you’re not a bot") || lower.contains("confirm you're not a bot") {
            return .botDetection
        }
        if lower.contains("operation not permitted") &&
            (lower.contains("cookies.binarycookies") || lower.contains("/library/containers/")) {
            return .cookieAccessDenied
        }
        return .generic
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                icon
                titleSection

                if kind != .generic {
                    fixSection
                        .frame(maxWidth: 480)
                }

                if hasDetails {
                    DisclosureGroup(isExpanded: $showDetails) {
                        ScrollView {
                            Text(message)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .frame(maxHeight: 160)
                        .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 8))
                    } label: {
                        Text("詳細を表示").font(.caption)
                    }
                    .frame(maxWidth: 480)
                }

                actionBar
            }
            .frame(maxWidth: 540)
            .card()
            Spacer()
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .botDetection:
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 44)).foregroundStyle(.orange.gradient)
                .symbolRenderingMode(.hierarchical)
        case .cookieAccessDenied:
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44)).foregroundStyle(.blue.gradient)
                .symbolRenderingMode(.hierarchical)
        case .generic:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44)).foregroundStyle(.orange.gradient)
                .symbolRenderingMode(.hierarchical)
        }
    }

    @ViewBuilder
    private var titleSection: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
    }

    private var title: String {
        switch kind {
        case .botDetection: return "YouTube からボット検出されました"
        case .cookieAccessDenied: return "Cookie の読み取りが拒否されました"
        case .generic: return "ダウンロードに失敗しました"
        }
    }

    private var subtitle: String {
        switch kind {
        case .botDetection:
            return "ログイン中のブラウザの Cookie を使うと回避できます。下から選んでリトライしてください。"
        case .cookieAccessDenied:
            return "macOS の保護領域にあるブラウザ Cookie に YTtoMusic からアクセスできません。フルディスクアクセスを許可するか、別のブラウザに切り替えてください。"
        case .generic:
            return firstLine
        }
    }

    private var firstLine: String {
        message.split(whereSeparator: { $0 == "\n" }).first.map(String.init) ?? message
    }

    private var hasDetails: Bool {
        message.contains("\n") || kind != .generic
    }

    @ViewBuilder
    private var fixSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ブラウザの Cookie")
                    .font(.callout.weight(.medium))
                Spacer()
                Picker("", selection: $settings.cookieBrowser) {
                    ForEach(CookieBrowser.allCases) { b in
                        Text(b.displayName).tag(b)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 200)
            }

            if kind == .cookieAccessDenied {
                HStack(spacing: 10) {
                    Button {
                        openFullDiskAccessSettings()
                    } label: {
                        Label("フルディスクアクセスを許可…", systemImage: "lock.open.fill")
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
                Text("※ システム設定で YTtoMusic を追加 → アプリを再起動してリトライ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if kind == .botDetection && settings.cookieBrowser == .none {
                Text("※ 「使わない」のままだとリトライしても同じエラーになります")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("最初に戻る", role: .cancel, action: onReset)
            if let onRetry {
                Button {
                    onRetry()
                } label: {
                    Label("リトライ", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(kind == .botDetection && settings.cookieBrowser == .none)
            }
        }
        .controlSize(.large)
    }

    private func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
