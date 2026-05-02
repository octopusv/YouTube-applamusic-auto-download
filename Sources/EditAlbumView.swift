import SwiftUI
import UniformTypeIdentifiers

struct EditAlbumView: View {
    let album: AlbumGroup
    @Binding var selection: SidebarSelection?
    let onComplete: (AlbumActionResult) -> Void

    @EnvironmentObject var history: HistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var albumArtist: String = ""
    @State private var customArtworkPath: String?
    @State private var saving = false
    @State private var error: String?
    @State private var artworkHover = false

    private var effectiveArtwork: String? {
        customArtworkPath ?? album.coverThumbnailPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("アルバムを一括編集").font(.title3.weight(.semibold))
                Text("ミュージック.app の \(album.items.count) 曲すべてに適用されます。履歴も自動で更新されます。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 24) {
                artworkColumn
                formColumn
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.callout)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }

            Spacer(minLength: 0)

            HStack {
                Button("キャンセル", role: .cancel) { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button(action: save) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(saving ? "適用中…" : "保存")
                    }.frame(minWidth: 100)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(saving || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 560, height: 420)
        .onAppear {
            name = album.name
            albumArtist = album.albumArtist
        }
    }

    private var artworkColumn: some View {
        VStack(spacing: 8) {
            ZStack {
                ArtworkView(path: effectiveArtwork, size: 160)
                if artworkHover {
                    RoundedRectangle(cornerRadius: Theme.artworkCorner)
                        .fill(.black.opacity(0.45))
                        .frame(width: 160, height: 160)
                    VStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus").font(.title2)
                        Text("画像をドロップ").font(.caption2)
                    }.foregroundStyle(.white)
                }
            }
            .onHover { artworkHover = $0 }
            .animation(.easeOut(duration: 0.15), value: artworkHover)
            .onDrop(of: [.image, .fileURL], isTargeted: nil, perform: handleArtworkDrop)
            if customArtworkPath != nil {
                Button("元に戻す") { customArtworkPath = nil }.buttonStyle(.link).font(.caption)
            }
        }
    }

    private var formColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            field("アルバム名", text: $name)
            Divider().padding(.vertical, 8)
            field("アルバムアーティスト", text: $albumArtist)
            Spacer(minLength: 0)
        }.frame(minWidth: 260)
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .frame(width: 130, alignment: .trailing)
                .foregroundStyle(.secondary).font(.callout)
            TextField("", text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func save() {
        saving = true
        error = nil
        let oldAlbum = album.name
        let newName = name.trimmingCharacters(in: .whitespaces)
        let newAlbumArtist = albumArtist.trimmingCharacters(in: .whitespaces)
        let artwork = effectiveArtwork
        let oldThumbnail = album.coverThumbnailPath
        let oldItems = album.items
        let nextSelection = newName == oldAlbum ? selection : SidebarSelection.album(newName)

        Task.detached(priority: .userInitiated) {
            do {
                let result = try MusicLibraryEditor.updateAlbum(
                    oldAlbum: oldAlbum,
                    newAlbum: newName,
                    newAlbumArtist: newAlbumArtist.isEmpty ? nil : newAlbumArtist,
                    newArtworkPath: artwork
                )

                let newThumb: String?
                if let custom = artwork, custom != oldThumbnail {
                    newThumb = HistoryStore.persistThumbnail(from: custom)
                } else {
                    newThumb = oldThumbnail
                }

                let updated: [HistoryItem] = oldItems.map { item in
                    HistoryItem(
                        id: item.id,
                        kind: item.kind,
                        url: item.url,
                        title: item.title,
                        artist: newAlbumArtist.isEmpty ? item.artist : newAlbumArtist,
                        album: newName,
                        savedAt: item.savedAt,
                        thumbnailPath: newThumb,
                        savedFilePath: item.savedFilePath,
                        formatLabel: item.formatLabel
                    )
                }

                await MainActor.run {
                    history.bulkUpdate(updated)
                    selection = nextSelection
                    let summary: String
                    if result.failed == 0 {
                        summary = "\(result.succeeded) 曲を更新しました"
                    } else {
                        summary = "\(result.succeeded) 曲を更新、\(result.failed) 曲は見つかりませんでした"
                    }
                    onComplete(AlbumActionResult(message: summary, isError: result.failed > 0 && result.succeeded == 0))
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
