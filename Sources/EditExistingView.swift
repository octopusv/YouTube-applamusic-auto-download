import SwiftUI
import UniformTypeIdentifiers

struct EditExistingView: View {
    let item: HistoryItem
    @ObservedObject var history: HistoryStore
    let onClose: () -> Void

    @State private var title: String = ""
    @State private var artist: String = ""
    @State private var album: String = ""
    @State private var customArtworkPath: String?
    @State private var saving = false
    @State private var error: String?
    @State private var artworkHover = false

    private var effectiveArtwork: String? {
        customArtworkPath ?? item.thumbnailPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            HStack(alignment: .top, spacing: 24) {
                artworkColumn
                formColumn
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }

            Spacer(minLength: 0)

            HStack {
                Button("キャンセル", role: .cancel, action: onClose)
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button(action: save) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(saving ? "保存中…" : "保存")
                    }
                    .frame(minWidth: 100)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(saving || title.isEmpty || artist.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 580, height: 460)
        .onAppear {
            title = item.title
            artist = item.artist
            album = item.album
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                kindBadge
                Text("メタデータを編集").font(.title3.weight(.semibold))
            }
            Text(scopeHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var kindBadge: some View {
        switch item.kind {
        case .appleMusic:
            Label("Apple Music", systemImage: "music.note.house.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.pink)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.pink.opacity(0.12), in: Capsule())
        case .file:
            Label(item.formatLabel ?? "ファイル", systemImage: "arrow.down.doc.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.blue)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.blue.opacity(0.12), in: Capsule())
        }
    }

    private var scopeHint: String {
        switch item.kind {
        case .appleMusic:
            return "ミュージック.app のライブラリを直接書き換えます。初回は Automation 権限のダイアログが出ます。"
        case .file:
            return "保存済みファイルの ID3 タグを書き換えます。"
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
                    }
                    .foregroundStyle(.white)
                }
            }
            .onHover { artworkHover = $0 }
            .animation(.easeOut(duration: 0.15), value: artworkHover)
            .onDrop(of: [.image, .fileURL], isTargeted: nil, perform: handleArtworkDrop)

            if customArtworkPath != nil {
                Button("元に戻す") { customArtworkPath = nil }
                    .buttonStyle(.link).font(.caption)
            }
        }
    }

    private var formColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            field("タイトル", text: $title)
            Divider().padding(.vertical, 8)
            field("アーティスト", text: $artist)
            Divider().padding(.vertical, 8)
            field("アルバム", text: $album)
        }
        .frame(minWidth: 260)
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(.secondary)
                .font(.callout)
            TextField("", text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func save() {
        saving = true
        error = nil
        let snapshot = (title: title, artist: artist, album: album,
                        artwork: effectiveArtwork, item: item)

        Task.detached(priority: .userInitiated) {
            do {
                switch snapshot.item.kind {
                case .appleMusic:
                    try MusicLibraryEditor.update(
                        oldTitle: snapshot.item.title,
                        oldArtist: snapshot.item.artist,
                        newTitle: snapshot.title,
                        newArtist: snapshot.artist,
                        newAlbum: snapshot.album,
                        newAlbumArtist: snapshot.artist,
                        newArtworkPath: snapshot.artwork
                    )
                case .file:
                    guard let path = snapshot.item.savedFilePath else {
                        throw FileTagEditor.EditError.fileMissing
                    }
                    try FileTagEditor.update(
                        filePath: path,
                        title: snapshot.title,
                        artist: snapshot.artist,
                        album: snapshot.album,
                        albumArtist: snapshot.artist,
                        artworkPath: snapshot.artwork
                    )
                }

                let newThumb: String?
                if let custom = snapshot.artwork, custom != snapshot.item.thumbnailPath {
                    newThumb = HistoryStore.persistThumbnail(from: custom)
                } else {
                    newThumb = snapshot.item.thumbnailPath
                }

                let updated = HistoryItem(
                    id: snapshot.item.id,
                    kind: snapshot.item.kind,
                    url: snapshot.item.url,
                    title: snapshot.title,
                    artist: snapshot.artist,
                    album: snapshot.album,
                    savedAt: snapshot.item.savedAt,
                    thumbnailPath: newThumb,
                    savedFilePath: snapshot.item.savedFilePath,
                    formatLabel: snapshot.item.formatLabel
                )

                await MainActor.run {
                    history.update(updated)
                    onClose()
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
            DispatchQueue.main.async {
                customArtworkPath = url.path
            }
        }
        return true
    }
}
