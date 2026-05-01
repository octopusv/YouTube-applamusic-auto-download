import SwiftUI
import UniformTypeIdentifiers

struct NewDownloadView: View {
    @EnvironmentObject var downloader: DownloadManager
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var settings: AppSettings
    @Binding var selection: SidebarSelection?

    @State private var url: String = ""
    @FocusState private var urlFocused: Bool

    var body: some View {
        ZStack {
            content
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Theme.primaryAnimation, value: stateKey)
        .toolbar { toolbarContent }
        .onReceive(NotificationCenter.default.publisher(for: .newDownload)) { _ in
            downloader.reset()
            url = ""
            urlFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .pasteAndStart)) { _ in
            if let s = NSPasteboard.general.string(forType: .string) {
                url = s
                start()
            }
        }
        .onDrop(of: [.url, .text], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch downloader.state {
        case .idle:
            EmptyDropZoneView(url: $url, urlFocused: $urlFocused, onStart: start)
                .id("idle")
        case .working(let stage, let status):
            DownloadProgressView(
                stage: stage,
                status: status,
                preview: downloader.preview,
                url: url,
                onCancel: { downloader.cancel() }
            )
            .id("working")
        case .ready(let meta):
            EditorView(metadata: meta) { result in
                handleEditorResult(result)
            }
            .id("ready")
        case .saving:
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text("Apple Music に追加中…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id("saving")
        case .saved(let item):
            SavedSuccessView(item: item) {
                downloader.reset()
                url = ""
            } onShowInSidebar: {
                selection = .history(item.id)
                downloader.reset()
                url = ""
            }
            .id("saved")
        case .error(let msg):
            ErrorView(message: msg, onReset: {
                downloader.reset()
            }, onRetry: {
                downloader.reset()
                start()
            })
            .id("error")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                TextField("YouTube URL を貼り付け", text: $url)
                    .textFieldStyle(.plain)
                    .focused($urlFocused)
                    .onSubmit(start)
                    .frame(minWidth: 320, idealWidth: 460, maxWidth: 560)
                if !url.isEmpty {
                    Button {
                        url = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
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
                if let s = NSPasteboard.general.string(forType: .string) {
                    url = s
                }
            } label: {
                Label("ペースト", systemImage: "doc.on.clipboard")
            }
            .help("クリップボードから URL を貼り付け")

            Button(action: start) {
                Label("ダウンロード", systemImage: "arrow.down.circle.fill")
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)
        }
    }

    private var isBusy: Bool {
        switch downloader.state {
        case .working, .ready, .saving: return true
        default: return false
        }
    }

    private var stateKey: String {
        switch downloader.state {
        case .idle: "idle"
        case .working: "working"
        case .ready: "ready"
        case .saving: "saving"
        case .saved: "saved"
        case .error: "error"
        }
    }

    private func start() {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        downloader.download(url: trimmed, cookieBrowser: settings.cookieBrowser)
    }

    private func handleEditorResult(_ result: EditorView.Result) {
        switch result {
        case .cancel:
            downloader.reset()
            url = ""
        case .startSaving:
            downloader.setSaving()
        case .saved(let item):
            history.add(item)
            downloader.setSaved(item)
        case .error(let msg):
            downloader.failSaving(msg)
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
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                let s: String?
                if let str = item as? String { s = str }
                else if let data = item as? Data { s = String(data: data, encoding: .utf8) }
                else { s = nil }
                if let s {
                    DispatchQueue.main.async {
                        self.url = s.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.start()
                    }
                }
            }
            return true
        }
        return false
    }
}
