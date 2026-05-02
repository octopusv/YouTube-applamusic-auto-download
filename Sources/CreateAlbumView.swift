import SwiftUI
import UniformTypeIdentifiers

struct CreateAlbumView: View {
    @Binding var selection: SidebarSelection?
    @EnvironmentObject var history: HistoryStore

    @State private var albumName: String = ""
    @State private var albumArtist: String = ""
    @State private var selected: Set<UUID> = []
    @State private var customArtworkPath: String?
    @State private var artworkHover = false
    @State private var saving = false
    @State private var error: String?
    @State private var feedback: String?

    private var candidates: [HistoryItem] {
        history.items.filter { $0.kind == .appleMusic }
    }

    private var selectedItems: [HistoryItem] {
        let order = candidates
        let set = selected
        return order.filter { set.contains($0.id) }
    }

    private var artwork: String? {
        customArtworkPath ?? selectedItems.first?.thumbnailPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)
            Divider()
            HStack(spacing: 0) {
                tracksColumn
                Divider()
                formColumn
                    .frame(width: 320)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("アルバムを新規作成").font(.title3.weight(.semibold))
                Text("履歴から Apple Music 取り込み済みの曲を選び、選んだ順に track 番号を 1 から振り直します。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var tracksColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("曲を選択").font(.headline)
                Spacer()
                Text("\(selected.count) / \(candidates.count) 選択中")
                    .font(.caption).foregroundStyle(.secondary)
                Button("全解除") { selected.removeAll() }
                    .buttonStyle(.link).font(.caption)
                    .disabled(selected.isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            Divider()

            if candidates.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note").font(.largeTitle).foregroundStyle(.tertiary)
                    Text("Apple Music に追加した履歴がありません")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(candidates) { item in
                        trackRow(item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selected.contains(item.id) {
                                    selected.remove(item.id)
                                } else {
                                    selected.insert(item.id)
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func trackRow(_ item: HistoryItem) -> some View {
        let isSelected = selected.contains(item.id)
        let order = isSelected ? (selectedItems.firstIndex(where: { $0.id == item.id }).map { $0 + 1 }) : nil
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if isSelected {
                    RoundedRectangle(cornerRadius: 4).fill(Color.accentColor).frame(width: 22, height: 22)
                    if let order {
                        Text("\(order)").font(.caption.bold().monospacedDigit()).foregroundStyle(.white)
                    } else {
                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                    }
                }
            }
            ArtworkView(path: item.thumbnailPath, size: 36, corner: 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.body).lineLimit(1)
                Text(item.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if !item.album.isEmpty {
                Text(item.album).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                    .frame(maxWidth: 140, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }

    private var formColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("アルバム情報").font(.headline)
                .padding(.bottom, 4)

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    ArtworkView(path: artwork, size: 90)
                    if artworkHover {
                        RoundedRectangle(cornerRadius: Theme.artworkCorner)
                            .fill(.black.opacity(0.45))
                            .frame(width: 90, height: 90)
                        Image(systemName: "photo.badge.plus")
                            .font(.title3).foregroundStyle(.white)
                    }
                }
                .onHover { artworkHover = $0 }
                .animation(.easeOut(duration: 0.15), value: artworkHover)
                .onDrop(of: [.image, .fileURL], isTargeted: nil, perform: handleArtworkDrop)

                VStack(alignment: .leading, spacing: 6) {
                    Text("アートワーク").font(.caption).foregroundStyle(.secondary)
                    Text("最初に選んだ曲のサムネを自動で使います。差し替えるなら画像をドラッグ。")
                        .font(.caption2).foregroundStyle(.tertiary)
                    if customArtworkPath != nil {
                        Button("既定に戻す") { customArtworkPath = nil }
                            .buttonStyle(.link).font(.caption)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("アルバム名").font(.caption).foregroundStyle(.secondary)
                TextField("My Album", text: $albumName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("アルバムアーティスト").font(.caption).foregroundStyle(.secondary)
                Text("空欄なら各曲の元のアーティストを保持")
                    .font(.caption2).foregroundStyle(.tertiary)
                TextField("Various Artists など", text: $albumArtist)
                    .textFieldStyle(.roundedBorder)
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.caption)
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            } else if let feedback {
                Label(feedback, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.caption)
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }

            Spacer(minLength: 0)

            Button(action: create) {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.stack.badge.plus")
                    Text(saving ? "作成中…" : "アルバムを作成")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(saving || selected.isEmpty || albumName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(20)
    }

    private func create() {
        saving = true
        error = nil
        feedback = nil
        let name = albumName.trimmingCharacters(in: .whitespaces)
        let artistRaw = albumArtist.trimmingCharacters(in: .whitespaces)
        let artworkPath = artwork
        let items = selectedItems

        Task.detached(priority: .userInitiated) {
            let tracks = items.map { (oldTitle: $0.title, oldArtist: $0.artist) }
            do {
                let result = try MusicLibraryEditor.assignToAlbum(
                    tracks: tracks,
                    album: name,
                    albumArtist: artistRaw.isEmpty ? nil : artistRaw,
                    artworkPath: artworkPath,
                    startTrackNumber: 1,
                    totalTracks: items.count
                )

                let newThumb: String?
                if let custom = artworkPath, custom != items.first?.thumbnailPath {
                    newThumb = HistoryStore.persistThumbnail(from: custom)
                } else {
                    newThumb = items.first?.thumbnailPath
                }

                let updates: [HistoryItem] = items.map { item in
                    HistoryItem(
                        id: item.id,
                        kind: item.kind,
                        url: item.url,
                        title: item.title,
                        artist: artistRaw.isEmpty ? item.artist : artistRaw,
                        album: name,
                        savedAt: item.savedAt,
                        thumbnailPath: newThumb,
                        savedFilePath: item.savedFilePath,
                        formatLabel: item.formatLabel
                    )
                }

                await MainActor.run {
                    history.bulkUpdate(updates)
                    saving = false
                    if result.failed.isEmpty {
                        feedback = "\(result.succeeded) 曲をアルバム「\(name)」にまとめました"
                    } else {
                        feedback = "\(result.succeeded) 曲成功、失敗: \(result.failed.joined(separator: ", "))"
                    }
                    selected.removeAll()
                    selection = .album(name)
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.saving = false
                }
            }
        }
    }

    private func handleArtworkDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async { customArtworkPath = url.path }
        }
        return true
    }
}
