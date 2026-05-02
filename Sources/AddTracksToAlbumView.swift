import SwiftUI

struct AddTracksToAlbumView: View {
    let album: AlbumGroup
    let onComplete: (AlbumActionResult) -> Void

    @EnvironmentObject var history: HistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<UUID> = []
    @State private var saving = false
    @State private var error: String?

    private var candidates: [HistoryItem] {
        let existingIDs = Set(album.items.map(\.id))
        return history.items.filter { $0.kind == .appleMusic && !existingIDs.contains($0.id) }
    }

    private var selectedItems: [HistoryItem] {
        candidates.filter { selected.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("「\(album.name)」に曲を追加").font(.title3.weight(.semibold))
                Text("選んだ順に既存トラックの末尾へ続けて並べます。track 番号は再採番されます。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 12)

            HStack {
                Text("\(selected.count) 曲選択中").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("全解除") { selected.removeAll() }
                    .buttonStyle(.link).font(.caption)
                    .disabled(selected.isEmpty)
            }
            .padding(.horizontal, 24).padding(.bottom, 8)

            Divider()

            if candidates.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.largeTitle).foregroundStyle(.tertiary)
                    Text("追加できる曲がありません").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(candidates) { item in
                        row(item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selected.contains(item.id) { selected.remove(item.id) }
                                else { selected.insert(item.id) }
                            }
                    }
                }
                .listStyle(.inset)
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.caption)
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal, 24)
            }

            Divider()

            HStack {
                Button("キャンセル", role: .cancel) { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button(action: addToAlbum) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text(saving ? "追加中…" : "追加")
                    }.frame(minWidth: 100)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(saving || selected.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 600, height: 540)
    }

    private func row(_ item: HistoryItem) -> some View {
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

    private func addToAlbum() {
        saving = true
        error = nil
        let albumName = album.name
        let albumArtist = album.albumArtist
        let coverArtwork = album.coverThumbnailPath
        let existingItems = album.items
        let newItems = selectedItems
        let totalAfter = existingItems.count + newItems.count

        Task.detached(priority: .userInitiated) {
            let tracks = newItems.map { (oldTitle: $0.title, oldArtist: $0.artist) }
            do {
                let result = try MusicLibraryEditor.assignToAlbum(
                    tracks: tracks,
                    album: albumName,
                    albumArtist: albumArtist.isEmpty ? nil : albumArtist,
                    artworkPath: coverArtwork,
                    startTrackNumber: existingItems.count + 1,
                    totalTracks: totalAfter
                )

                // 既存トラックの track count も最新に揃える
                let existingTrackPairs = existingItems.map { (oldTitle: $0.title, oldArtist: $0.artist) }
                _ = try? MusicLibraryEditor.assignToAlbum(
                    tracks: existingTrackPairs,
                    album: albumName,
                    albumArtist: albumArtist.isEmpty ? nil : albumArtist,
                    artworkPath: nil,
                    startTrackNumber: 1,
                    totalTracks: totalAfter
                )

                let updates: [HistoryItem] = newItems.map { item in
                    HistoryItem(
                        id: item.id,
                        kind: item.kind,
                        url: item.url,
                        title: item.title,
                        artist: albumArtist.isEmpty ? item.artist : albumArtist,
                        album: albumName,
                        savedAt: item.savedAt,
                        thumbnailPath: coverArtwork ?? item.thumbnailPath,
                        savedFilePath: item.savedFilePath,
                        formatLabel: item.formatLabel
                    )
                }

                await MainActor.run {
                    history.bulkUpdate(updates)
                    let summary: String
                    if result.failed.isEmpty {
                        summary = "\(result.succeeded) 曲を追加しました"
                    } else {
                        summary = "\(result.succeeded) 曲成功、失敗: \(result.failed.joined(separator: ", "))"
                    }
                    onComplete(AlbumActionResult(message: summary, isError: result.succeeded == 0))
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.saving = false
                }
            }
        }
    }
}
