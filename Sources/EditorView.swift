import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    enum Result {
        case cancel
        case startSaving
        case saved(HistoryItem)
        case error(String)
    }

    let metadata: VideoMetadata
    let onResult: (Result) -> Void

    @State private var title: String = ""
    @State private var artist: String = ""
    @State private var album: String = ""
    @State private var customArtworkPath: String?
    @State private var saving = false
    @State private var error: String?
    @State private var artworkHover = false

    private var effectiveArtwork: String? {
        customArtworkPath ?? metadata.thumbnailPath
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                HStack(alignment: .top, spacing: 28) {
                    artworkColumn
                    formColumn
                }
                .card()

                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                actionBar
            }
            .padding(28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            title = metadata.originalTitle
            artist = metadata.uploader
            album = metadata.uploader
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("曲の情報を編集")
                .font(.title2.weight(.semibold))
            Text("Apple Music に追加する前にメタデータを確認してください。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var artworkColumn: some View {
        VStack(spacing: 10) {
            ZStack {
                ArtworkView(path: effectiveArtwork, size: 200)
                if artworkHover {
                    RoundedRectangle(cornerRadius: Theme.artworkCorner)
                        .fill(.black.opacity(0.45))
                        .frame(width: 200, height: 200)
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 28, weight: .medium))
                        Text("画像をドロップ")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                }
            }
            .onHover { artworkHover = $0 }
            .animation(.easeOut(duration: 0.15), value: artworkHover)
            .onDrop(of: [.image, .fileURL], isTargeted: nil, perform: handleArtworkDrop)

            if customArtworkPath != nil {
                Button("元のサムネに戻す") {
                    customArtworkPath = nil
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
    }

    private var formColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            LabeledRow(label: "タイトル") {
                TextField("", text: $title).textFieldStyle(.roundedBorder)
            }
            Divider().padding(.vertical, 10)
            LabeledRow(label: "アーティスト") {
                TextField("", text: $artist).textFieldStyle(.roundedBorder)
            }
            Divider().padding(.vertical, 10)
            LabeledRow(label: "アルバム") {
                TextField("", text: $album).textFieldStyle(.roundedBorder)
            }
            if let dur = formatDuration(metadata.duration) {
                Divider().padding(.vertical, 10)
                LabeledRow(label: "長さ") {
                    Text(dur).foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .frame(minWidth: 320)
    }

    private var actionBar: some View {
        HStack {
            Button("キャンセル", role: .cancel) {
                onResult(.cancel)
            }
            .keyboardShortcut(.escape, modifiers: [])
            Spacer()
            Button {
                save()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "music.note.house.fill")
                    Text(saving ? "追加中…" : "Apple Music に追加")
                }
                .frame(minWidth: 160)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(saving || title.isEmpty || artist.isEmpty)
        }
    }

    private func save() {
        saving = true
        error = nil
        onResult(.startSaving)
        let snapshot = (title: title, artist: artist, album: album,
                        url: metadata.url, mp3: metadata.mp3Path,
                        thumb: effectiveArtwork)

        Task.detached(priority: .userInitiated) {
            do {
                let dest = try MusicLibrary.save(
                    mp3Source: snapshot.mp3,
                    thumbnail: snapshot.thumb,
                    title: snapshot.title,
                    artist: snapshot.artist,
                    album: snapshot.album
                )
                let savedThumb = HistoryStore.persistThumbnail(from: snapshot.thumb)
                let item = HistoryItem(
                    id: UUID(),
                    url: snapshot.url,
                    title: snapshot.title,
                    artist: snapshot.artist,
                    album: snapshot.album,
                    savedAt: Date(),
                    thumbnailPath: savedThumb,
                    savedFilePath: dest.path
                )
                await MainActor.run { onResult(.saved(item)) }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.saving = false
                    onResult(.error(error.localizedDescription))
                }
            }
        }
    }

    private func handleArtworkDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        let typeID = UTType.fileURL.identifier
        provider.loadItem(forTypeIdentifier: typeID, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                customArtworkPath = url.path
            }
        }
        return true
    }
}

private struct LabeledRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .frame(width: 92, alignment: .trailing)
                .foregroundStyle(.secondary)
                .font(.callout)
            content()
        }
    }
}
