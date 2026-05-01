import SwiftUI
import UniformTypeIdentifiers

struct FileDownloadView: View {
    @EnvironmentObject var downloader: FileDownloadManager
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var settings: AppSettings
    @Binding var selection: SidebarSelection?

    @State private var url: String = ""
    @State private var selectedFormat: FileFormat = .mp4_1080
    @State private var destination: URL = URL(fileURLWithPath: NSHomeDirectory())
    @FocusState private var urlFocused: Bool

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Theme.primaryAnimation, value: stateKey)
        .toolbar { toolbarContent }
        .onAppear {
            selectedFormat = settings.defaultFormat
            destination = settings.defaultFolder
        }
        .onDrop(of: [.url, .text], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch downloader.state {
        case .idle:
            idleView
        case .working(let stage, let status):
            VStack(spacing: 14) {
                DownloadProgressView(stage: stage, status: status, preview: nil, url: url)
                Button(role: .destructive) {
                    downloader.cancel()
                } label: {
                    Label("キャンセル", systemImage: "xmark.circle.fill")
                }
                .controlSize(.regular)
            }
            .id("file-working")
        case .saved(let item):
            FileSavedView(item: item) {
                downloader.reset()
                url = ""
            }
            .id("file-saved")
        case .error(let msg):
            ErrorView(message: msg, onReset: {
                downloader.reset()
            }, onRetry: {
                downloader.reset()
                start()
            })
            .id("file-error")
        }
    }

    private var idleView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    formatSection
                    Divider()
                    destinationSection
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
            Label("ファイルとして保存", systemImage: "arrow.down.doc.fill")
                .font(.title2.weight(.semibold))
                .labelStyle(.titleAndIcon)
            Text("YouTube から動画/音声をダウンロードして任意のフォルダに保存します。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("フォーマット")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(FileFormat.allCases) { fmt in
                    FormatButton(format: fmt, selected: selectedFormat == fmt) {
                        selectedFormat = fmt
                        if settings.rememberLastFormat {
                            settings.defaultFormat = fmt
                        }
                    }
                }
            }
        }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("保存先")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.tint)
                Text(destination.path)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("変更…") {
                    pickFolder()
                }
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .help("Finder で開く")
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 8))

            Toggle("このフォルダをデフォルトに設定", isOn: Binding(
                get: { destination == settings.defaultFolder },
                set: { newValue in
                    if newValue { settings.defaultFolder = destination }
                }
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            HStack(spacing: 8) {
                Image(systemName: "link").foregroundStyle(.secondary)
                TextField("YouTube URL を貼り付け", text: $url)
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
                Label("ダウンロード", systemImage: "arrow.down.circle.fill")
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)
        }
    }

    private var isBusy: Bool {
        switch downloader.state {
        case .working: return true
        default: return false
        }
    }

    private var stateKey: String {
        switch downloader.state {
        case .idle: "idle"
        case .working: "working"
        case .saved: "saved"
        case .error: "error"
        }
    }

    private func start() {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        downloader.download(url: trimmed,
                            format: selectedFormat,
                            destination: destination,
                            cookieBrowser: settings.cookieBrowser)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = destination
        panel.prompt = "選択"
        if panel.runModal() == .OK, let url = panel.url {
            destination = url
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { obj, _ in
                if let u = obj {
                    DispatchQueue.main.async {
                        self.url = u.absoluteString
                        self.start()
                    }
                }
            }
            return true
        }
        return false
    }
}

private struct FormatButton: View {
    let format: FileFormat
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: format.symbol)
                    .font(.title3)
                Text(format.displayName)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct FileSavedView: View {
    let item: HistoryItem
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 22) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green.gradient)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 6) {
                    Text("保存しました")
                        .font(.title2.weight(.semibold))
                    Text(item.savedFilePath ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                HStack(spacing: 12) {
                    ArtworkView(path: item.thumbnailPath, size: 56, corner: 7)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.body.weight(.medium)).lineLimit(1)
                        if let f = item.formatLabel {
                            Text(f).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 360)

                HStack(spacing: 10) {
                    Button {
                        if let p = item.savedFilePath {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p)])
                        }
                    } label: {
                        Label("Finder で表示", systemImage: "folder")
                    }
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
    }
}
