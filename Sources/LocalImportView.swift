import SwiftUI
import UniformTypeIdentifiers

struct LocalImportView: View {
    @EnvironmentObject var importer: LocalImportManager
    @EnvironmentObject var history: HistoryStore
    @Binding var selection: SidebarSelection?

    @State private var dropTargeted = false

    var body: some View {
        ZStack {
            content
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Theme.primaryAnimation, value: stateKey)
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            handleDrop(providers)
        }
        .toolbar { toolbarContent }
        .onReceive(NotificationCenter.default.publisher(for: .newLocalImport)) { _ in
            importer.reset()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch importer.state {
        case .idle:
            DropZone(targeted: dropTargeted, onChoose: pickFiles)
                .id("local-idle")
        case .preparing(let fileName, let index, let total):
            PreparingView(fileName: fileName, index: index, total: total)
                .id("local-preparing")
        case .editing(let meta, let index, let total, _):
            VStack(spacing: 0) {
                if total > 1 {
                    QueueBar(index: index, total: total)
                }
                EditorView(metadata: meta) { result in
                    handleEditorResult(result)
                }
                .id(meta.mp3Path)   // ファイルごとに State を作り直す
            }
            .id("local-editing")
        case .saving:
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text("Apple Music に追加中…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id("local-saving")
        case .saved(let item, let remaining):
            ImportSavedView(item: item, remaining: remaining,
                onNext: { importer.continueQueue() },
                onShowInSidebar: {
                    selection = .history(item.id)
                    importer.reset()
                })
                .id("local-saved")
        case .error(let msg):
            ErrorView(message: msg, onReset: {
                importer.reset()
            }, onRetry: {
                importer.continueQueue()
            })
            .id("local-error")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                pickFiles()
            } label: {
                Label("ファイルを選択", systemImage: "folder.badge.plus")
            }
            .disabled(isBusy)
            .help("取り込む音声・動画ファイルを選びます")
        }
    }

    private var isBusy: Bool {
        switch importer.state {
        case .preparing, .editing, .saving: return true
        default: return false
        }
    }

    private var stateKey: String {
        switch importer.state {
        case .idle: "idle"
        case .preparing: "preparing"
        case .editing: "editing"
        case .saving: "saving"
        case .saved: "saved"
        case .error: "error"
        }
    }

    private func handleEditorResult(_ result: EditorView.Result) {
        switch result {
        case .cancel:
            // この曲は取り込まず次へ
            importer.skipCurrent()
        case .startSaving:
            importer.setSaving()
        case .saved(let item):
            history.add(item)
            importer.advanceAfterSave(item)
        case .error(let msg):
            importer.failSaving(msg)
        }
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = "取り込む"
        panel.message = "Apple Music に取り込む音声・動画ファイルを選んでください"
        var types: [UTType] = [.audio, .movie, .mpeg4Movie, .mp3, .quickTimeMovie]
        if let m4a = UTType(filenameExtension: "m4a") { types.append(m4a) }
        panel.allowedContentTypes = types
        if panel.runModal() == .OK {
            importer.add(files: panel.urls)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { obj, _ in
                if let u = obj {
                    lock.lock(); urls.append(u); lock.unlock()
                }
                group.leave()
            }
        }
        guard !urls.isEmpty || !providers.isEmpty else { return false }
        group.notify(queue: .main) {
            if !urls.isEmpty { importer.add(files: urls) }
        }
        return true
    }
}

private struct DropZone: View {
    let targeted: Bool
    let onChoose: () -> Void
    @State private var iconBounce = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(targeted ? 0.22 : 0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: "square.and.arrow.down.on.square.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(iconBounce ? 1.04 : 1.0)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: iconBounce)
            }

            VStack(spacing: 8) {
                Text("手持ちのファイルを Apple Music へ")
                    .font(.title.weight(.semibold))
                Text("mp3 / m4a / wav / flac などの音声、mp4 / mov などの動画（音声に自動変換）をドラッグするか、ファイルを選択してください")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            Button(action: onChoose) {
                Label("ファイルを選択", systemImage: "folder.badge.plus")
                    .frame(minWidth: 160)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            Spacer()
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundStyle(targeted ? Color.accentColor : Color.clear)
                .padding(20)
                .animation(.easeOut(duration: 0.15), value: targeted)
        )
        .onAppear { iconBounce = true }
    }
}

private struct PreparingView: View {
    let fileName: String
    let index: Int
    let total: Int

    var body: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            VStack(spacing: 6) {
                Text(total > 1 ? "準備中… (\(index)/\(total))" : "準備中…")
                    .font(.title3.weight(.medium))
                Text(fileName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("音声の抽出・変換とタグの読み取りをしています")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct QueueBar: View {
    let index: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.stack")
                .foregroundStyle(.secondary)
            Text("\(index) / \(total) 曲目を編集中")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(.background.tertiary)
    }
}

private struct ImportSavedView: View {
    let item: HistoryItem
    let remaining: Int
    let onNext: () -> Void
    let onShowInSidebar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 22) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green.gradient)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 6) {
                    Text(remaining > 0 ? "追加しました" : "すべて追加しました")
                        .font(.title2.weight(.semibold))
                    Text("ミュージック.app が自動で取り込みます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    ArtworkView(path: item.thumbnailPath, size: 56, corner: 7)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.body.weight(.medium)).lineLimit(1)
                        Text(item.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 360)

                HStack(spacing: 10) {
                    Button {
                        onShowInSidebar()
                    } label: {
                        Label("履歴で表示", systemImage: "sidebar.left")
                    }
                    Button(action: onNext) {
                        if remaining > 0 {
                            Label("次の曲へ (残り \(remaining))", systemImage: "arrow.right")
                        } else {
                            Label("続けて取り込む", systemImage: "plus")
                        }
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
}
