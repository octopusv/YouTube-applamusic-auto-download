import SwiftUI

struct ContentView: View {
    @EnvironmentObject var downloader: DownloadManager
    @EnvironmentObject var fileDownloader: FileDownloadManager
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var updater: YtDlpUpdater
    @State private var selection: SidebarSelection? = .appleMusicDownload

    private var bannerKey: String {
        switch updater.state {
        case .unknown, .checking, .current: return "hidden"
        case .available: return "available"
        case .updating: return "updating"
        case .justUpdated: return "done"
        case .failed: return "failed"
        }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            VStack(spacing: 0) {
                UpdateBanner()
                    .animation(.smooth(duration: 0.25), value: bannerKey)
                detailContent
            }
            .navigationSplitViewColumnWidth(min: 560, ideal: 760)
        }
        .onChange(of: downloader.state) { _, newValue in
            switch newValue {
            case .working, .ready, .saving, .saved, .error:
                selection = .appleMusicDownload
            default: break
            }
        }
        .onChange(of: fileDownloader.state) { _, newValue in
            switch newValue {
            case .working, .saved, .error:
                selection = .fileDownload
            default: break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newDownload)) { _ in
            selection = .appleMusicDownload
            downloader.reset()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newFileDownload)) { _ in
            selection = .fileDownload
            fileDownloader.reset()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .none, .some(.appleMusicDownload):
            NewDownloadView(selection: $selection)
        case .some(.fileDownload):
            FileDownloadView(selection: $selection)
        case .some(.history(let id)):
            if let item = history.item(id: id) {
                HistoryDetailView(item: item, selection: $selection)
            } else {
                ContentUnavailable()
            }
        }
    }
}

private struct ContentUnavailable: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("項目を選択してください")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
