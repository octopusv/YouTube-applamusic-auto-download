import SwiftUI

struct EmptyDropZoneView: View {
    @Binding var url: String
    @FocusState.Binding var urlFocused: Bool
    let onStart: () -> Void

    @State private var iconBounce = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: "music.note.list")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(iconBounce ? 1.04 : 1.0)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: iconBounce)
            }

            VStack(spacing: 8) {
                Text("YouTube から Apple Music へ")
                    .font(.title.weight(.semibold))
                Text("URL を貼り付けるか、ブラウザのアドレスバーからドラッグしてください")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 14) {
                ShortcutHint(symbol: "command.square", text: "⌘V でペースト")
                ShortcutHint(symbol: "arrow.down.square", text: "⌘↩︎ で開始")
            }
            .padding(.top, 4)

            Spacer()
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            iconBounce = true
            urlFocused = true
        }
    }
}

private struct ShortcutHint: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.body)
            Text(text).font(.callout)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.quaternary, in: Capsule())
    }
}
