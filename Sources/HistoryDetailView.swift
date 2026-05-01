import SwiftUI

struct HistoryDetailView: View {
    let item: HistoryItem
    @EnvironmentObject var history: HistoryStore
    @Binding var selection: SidebarSelection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                detailGrid
                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    MusicLibrary.openMusicApp()
                } label: {
                    Label("ミュージックで開く", systemImage: "music.note")
                }

                Menu {
                    Button("URL をコピー") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.url, forType: .string)
                    }
                    if let path = item.savedFilePath {
                        Button("ファイルを Finder で表示") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                        }
                    }
                    Divider()
                    Button("履歴から削除", role: .destructive) {
                        selection = .newDownload
                        history.delete(item)
                    }
                } label: {
                    Label("その他", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 24) {
            ArtworkView(path: item.thumbnailPath, size: 220, corner: 14)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.title.weight(.semibold))
                    .lineLimit(3)
                Text(item.artist)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if !item.album.isEmpty {
                    Text(item.album)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
    }

    private var detailGrid: some View {
        VStack(spacing: 0) {
            row(label: "追加日時", value: dateString(item.savedAt))
            Divider().padding(.vertical, 6)
            row(label: "URL") {
                Text(item.url)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            if let path = item.savedFilePath {
                Divider().padding(.vertical, 6)
                row(label: "保存先") {
                    Text(path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
        }
        .card()
    }

    private func row(label: String, value: String) -> some View {
        row(label: label) { Text(value).font(.callout) }
    }

    private func row<V: View>(label: String, @ViewBuilder content: () -> V) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 92, alignment: .trailing)
                .foregroundStyle(.secondary)
                .font(.callout)
            content()
            Spacer(minLength: 0)
        }
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: d)
    }
}
