import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var history: HistoryStore
    @Binding var selection: SidebarSelection?

    var body: some View {
        List(selection: $selection) {
            Section {
                Label {
                    Text("新規ダウンロード").font(.body)
                } icon: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.tint)
                }
                .tag(SidebarSelection.newDownload)
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
                                Divider()
                                Button("削除", role: .destructive) {
                                    if selection == .history(item.id) {
                                        selection = .newDownload
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
            ArtworkView(path: item.thumbnailPath, size: 36, corner: 5)
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.body)
                    .lineLimit(1)
                Text(item.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
