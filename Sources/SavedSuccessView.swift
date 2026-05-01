import SwiftUI

struct SavedSuccessView: View {
    let item: HistoryItem
    let onContinue: () -> Void
    let onShowInSidebar: () -> Void

    @State private var checkScale: CGFloat = 0.4
    @State private var checkOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 22) {
                checkmark

                VStack(spacing: 6) {
                    Text("Apple Music に追加しました")
                        .font(.title2.weight(.semibold))
                    Text("数秒〜数分で iPhone のライブラリにも反映されます")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    ArtworkView(path: item.thumbnailPath, size: 56, corner: 7)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.body.weight(.medium)).lineLimit(1)
                        Text(item.artist).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 360)

                HStack(spacing: 10) {
                    Button {
                        MusicLibrary.openMusicApp()
                    } label: {
                        Label("ミュージックを開く", systemImage: "music.note")
                    }
                    Button("履歴で表示", action: onShowInSidebar)
                    Button {
                        onContinue()
                    } label: {
                        Label("続けてダウンロード", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
                .controlSize(.large)
            }
            .frame(maxWidth: 540)
            .card()

            Spacer()
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { runAnimation() }
    }

    private var checkmark: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.35), lineWidth: 3)
                .frame(width: 100, height: 100)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            Circle()
                .fill(Color.green.gradient)
                .frame(width: 80, height: 80)
                .shadow(color: .green.opacity(0.35), radius: 12)

            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect(checkScale)
                .opacity(checkOpacity)
        }
    }

    private func runAnimation() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
            checkScale = 1.0
            checkOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.05)) {
            ringScale = 1.4
            ringOpacity = 0
        }
    }
}
