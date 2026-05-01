import SwiftUI
import UniformTypeIdentifiers

struct PlaylistView: View {
    @EnvironmentObject var manager: PlaylistDownloadManager
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var settings: AppSettings
    @Binding var selection: SidebarSelection?

    @State private var url: String = ""
    @State private var albumName: String = ""
    @State private var albumArtist: String = ""
    @State private var fixArtist: Bool = true
    @FocusState private var urlFocused: Bool

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Theme.primaryAnimation, value: stateKey)
        .toolbar { toolbarContent }
        .onDrop(of: [.url, .text], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch manager.state {
        case .idle:
            idleView
        case .fetching:
            fetchingView
        case .downloading(let current, let total, let title, let progress):
            progressView(current: current, total: total, title: title, progress: progress)
        case .finished(let succeeded, let failed):
            finishedView(succeeded: succeeded, failed: failed)
        case .cancelled(let succeeded, let total):
            cancelledView(succeeded: succeeded, total: total)
        case .error(let msg):
            ErrorView(message: msg) { manager.reset() }
        }
    }

    private var idleView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    field("アルバム名") {
                        TextField("例: Greatest Hits", text: $albumName).textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $fixArtist) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("アーティストを固定").font(.callout)
                                Text(fixArtist ? "全トラックを同じアーティスト名に統一" : "動画ごとのチャンネル名をそのまま使う")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if fixArtist {
                            field("アーティスト名") {
                                TextField("例: The Beatles", text: $albumArtist).textFieldStyle(.roundedBorder)
                            }
                            .padding(.leading, 0)
                        }
                    }
                }
                .card()

                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("プレイリスト → アルバム", systemImage: "rectangle.stack.badge.plus")
                .font(.title2.weight(.semibold))
                .labelStyle(.titleAndIcon)
            Text("YouTube プレイリスト全体を 1 つのアルバムとして Apple Music に追加します。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func field<V: View>(_ label: String, @ViewBuilder content: () -> V) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .frame(width: 100, alignment: .trailing)
                .foregroundStyle(.secondary)
                .font(.callout)
            content()
        }
    }

    private var fetchingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text("プレイリスト情報を取得中…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func progressView(current: Int, total: Int, title: String, progress: Double) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 22) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 6)
                            .frame(width: 70, height: 70)
                        Circle()
                            .trim(from: 0, to: CGFloat(current) / CGFloat(max(total, 1)))
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 70, height: 70)
                            .animation(.smooth, value: current)
                        Text("\(current)/\(total)")
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ダウンロード中").font(.headline)
                        Text(title).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                ProgressView(value: progress)
                Text("このトラック: \(Int(progress * 100))%")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        manager.cancel()
                    } label: {
                        Label("キャンセル", systemImage: "xmark.circle.fill")
                    }
                }
            }
            .frame(maxWidth: 540)
            .card()
            Spacer()
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func finishedView(succeeded: Int, failed: [String]) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green.gradient)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 6) {
                    Text("\(succeeded) 曲を Apple Music に追加しました")
                        .font(.title3.weight(.semibold))
                    if !failed.isEmpty {
                        Text("\(failed.count) 曲が失敗")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }

                if !failed.isEmpty {
                    DisclosureGroup("失敗したトラック") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(failed, id: \.self) { t in
                                Text("• \(t)").font(.caption)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                    }
                    .frame(maxWidth: 480)
                }

                HStack(spacing: 10) {
                    Button {
                        MusicLibrary.openMusicApp()
                    } label: {
                        Label("ミュージックを開く", systemImage: "music.note")
                    }
                    Button {
                        manager.reset()
                        url = ""; albumName = ""; albumArtist = ""
                    } label: {
                        Label("続けて別のプレイリスト", systemImage: "plus")
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
    }

    private func cancelledView(succeeded: Int, total: Int) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange.gradient)
            Text("キャンセルしました")
                .font(.title3.weight(.semibold))
            Text("\(succeeded) / \(total) 曲を追加した時点で中断")
                .foregroundStyle(.secondary)
            Button("最初に戻る") { manager.reset() }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            HStack(spacing: 8) {
                Image(systemName: "link").foregroundStyle(.secondary)
                TextField("YouTube プレイリスト URL", text: $url)
                    .textFieldStyle(.plain)
                    .focused($urlFocused)
                    .onSubmit(start)
                    .frame(minWidth: 320, idealWidth: 460, maxWidth: 560)
                if !url.isEmpty {
                    Button { url = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                if let s = NSPasteboard.general.string(forType: .string) { url = s }
            } label: {
                Label("ペースト", systemImage: "doc.on.clipboard")
            }
            Button(action: start) {
                Label("ダウンロード開始", systemImage: "arrow.down.circle.fill")
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!canStart)
        }
    }

    private var canStart: Bool {
        guard case .idle = manager.state else { return false }
        let trimmedURL = url.trimmingCharacters(in: .whitespaces)
        let trimmedAlbum = albumName.trimmingCharacters(in: .whitespaces)
        guard !trimmedURL.isEmpty, !trimmedAlbum.isEmpty else { return false }
        if fixArtist && albumArtist.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        return true
    }

    private var stateKey: String {
        switch manager.state {
        case .idle: "idle"
        case .fetching: "fetching"
        case .downloading: "downloading"
        case .finished: "finished"
        case .cancelled: "cancelled"
        case .error: "error"
        }
    }

    private func start() {
        guard canStart else { return }
        let u = url.trimmingCharacters(in: .whitespaces)
        let album = albumName.trimmingCharacters(in: .whitespaces)
        let fixed = fixArtist ? albumArtist.trimmingCharacters(in: .whitespaces) : nil
        Task {
            await manager.start(
                url: u,
                albumName: album,
                fixedAlbumArtist: fixed,
                cookieBrowser: settings.cookieBrowser,
                history: history
            )
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { obj, _ in
                if let u = obj {
                    DispatchQueue.main.async { self.url = u.absoluteString }
                }
            }
            return true
        }
        return false
    }
}
