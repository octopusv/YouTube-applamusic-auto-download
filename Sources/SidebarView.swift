import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var history: HistoryStore
    @Binding var selection: SidebarSelection?

    var body: some View {
        List(selection: $selection) {
            Section {
                Label {
                    Text("Apple Music に追加")
                } icon: {
                    Image(systemName: "music.note.house.fill")
                        .foregroundStyle(.pink)
                }
                .tag(SidebarSelection.appleMusicDownload)

                Label {
                    Text("ファイルとして保存")
                } icon: {
                    Image(systemName: "arrow.down.doc.fill")
                        .foregroundStyle(.blue)
                }
                .tag(SidebarSelection.fileDownload)
            }

            ForEach(history.grouped, id: \.group) { group in
                Section(group.group.rawValue) {
                    ForEach(group.items) { item in
                        SidebarRow(item: item)
                            .tag(SidebarSelection.history(item.id))
                            .contextMenu {
                                Button("URL をコピー") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(item.url, forType: .string)
                                }
                                if item.kind == .file, let path = item.savedFilePath {
                                    Button("Finder で表示") {
                                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                                    }
                                }
                                Divider()
                                Button("削除", role: .destructive) {
                                    if selection == .history(item.id) {
                                        selection = .appleMusicDownload
                                    }
                                    history.delete(item)
                                }
                            }
                    }
                }
            }

            if history.items.isEmpty {
                Text("履歴はまだありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
                    .padding(.top, 8)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $history.searchText, placement: .sidebar, prompt: "履歴を検索")
        .navigationTitle("YT to Music")
    }
}

private struct SidebarRow: View {
    let item: HistoryItem

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                ArtworkView(path: item.thumbnailPath, size: 36, corner: 5)
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                kindBadge
                    .offset(x: 2, y: 2)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        switch item.kind {
        case .appleMusic: return item.artist
        case .file:
            if let f = item.formatLabel { return f }
            return item.artist
        }
    }

    @ViewBuilder
    private var kindBadge: some View {
        switch item.kind {
        case .appleMusic:
            Image(systemName: "music.note")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.pink))
                .overlay(Circle().stroke(.background, lineWidth: 1.5))
        case .file:
            Image(systemName: "arrow.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.blue))
                .overlay(Circle().stroke(.background, lineWidth: 1.5))
        }
    }
}
