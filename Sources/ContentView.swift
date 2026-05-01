import SwiftUI

struct ContentView: View {
    @EnvironmentObject var downloader: DownloadManager
    @EnvironmentObject var history: HistoryStore
    @State private var selection: SidebarSelection? = .newDownload

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            detailContent
                .navigationSplitViewColumnWidth(min: 560, ideal: 760)
        }
        .onChange(of: downloader.state) { _, newValue in
            if case .ready = newValue { selection = .newDownload }
            if case .working = newValue { selection = .newDownload }
            if case .saving = newValue { selection = .newDownload }
            if case .saved = newValue { selection = .newDownload }
            if case .error = newValue { selection = .newDownload }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .none, .some(.newDownload):
            NewDownloadView(selection: $selection)
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
