import SwiftUI

struct AlbumDetailView: View {
    let albumName: String
    @Binding var selection: SidebarSelection?
    @EnvironmentObject var history: HistoryStore

    @State private var showingEdit = false
    @State private var showingAddTracks = false
    @State private var feedback: String?
    @State private var feedbackIsError = false

    private var album: AlbumGroup? { history.album(named: albumName) }

    var body: some View {
        if let album {
            content(for: album)
                .sheet(isPresented: $showingEdit) {
                    EditAlbumView(album: album, selection: $selection) { result in
                        showFeedback(result)
                    }
                    .environmentObject(history)
                }
                .sheet(isPresented: $showingAddTracks) {
                    AddTracksToAlbumView(album: album) { result in
                        showFeedback(result)
                    }
                    .environmentObject(history)
                }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "rectangle.stack").font(.system(size: 48)).foregroundStyle(.tertiary)
                Text("アルバム「\(albumName)」は履歴にありません")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func content(for album: AlbumGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(for: album)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 16)

            if let feedback {
                Label(feedback, systemImage: feedbackIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(feedbackIsError ? Color.red : Color.green)
                    .font(.callout)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background((feedbackIsError ? Color.red : Color.green).opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)
            }

            Divider()

            trackList(for: album)
        }
    }

    private func header(for album: AlbumGroup) -> some View {
        HStack(alignment: .top, spacing: 20) {
            ArtworkView(path: album.coverThumbnailPath, size: 140)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("アルバム").font(.caption).foregroundStyle(.secondary)
                Text(album.name).font(.title2.weight(.bold)).lineLimit(2)
                Text(album.albumArtist).font(.title3).foregroundStyle(.secondary).lineLimit(1)
                Text("\(album.items.count) 曲").font(.callout).foregroundStyle(.tertiary)

                HStack(spacing: 8) {
                    Button {
                        showingEdit = true
                    } label: {
                        Label("アルバムを編集", systemImage: "pencil")
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)

                    Button {
                        showingAddTracks = true
                    } label: {
                        Label("曲を追加", systemImage: "plus")
                    }
                    .controlSize(.large)
                }
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
    }

    private func trackList(for album: AlbumGroup) -> some View {
        List {
            ForEach(Array(album.items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title).font(.body).lineLimit(1)
                        Text(item.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture { selection = .history(item.id) }
            }
        }
        .listStyle(.inset)
    }

    private func showFeedback(_ result: AlbumActionResult) {
        feedback = result.message
        feedbackIsError = result.isError
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            feedback = nil
        }
    }
}

struct AlbumActionResult {
    let message: String
    let isError: Bool
}
