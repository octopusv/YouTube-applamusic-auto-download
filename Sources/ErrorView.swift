import SwiftUI

struct ErrorView: View {
    let message: String
    let onReset: () -> Void

    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange.gradient)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 6) {
                    Text("ダウンロードに失敗しました")
                        .font(.title3.weight(.semibold))
                    Text(firstLine)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
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
                        .frame(maxHeight: 180)
                        .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 8))
                    } label: {
                        Text("詳細を表示").font(.caption)
                    }
                    .frame(maxWidth: 480)
                }

                Button("最初に戻る", action: onReset)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .frame(maxWidth: 540)
            .card()

            Spacer()
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var firstLine: String {
        message.split(whereSeparator: { $0 == "\n" }).first.map(String.init) ?? message
    }

    private var hasDetails: Bool {
        message.contains("\n")
    }
}
