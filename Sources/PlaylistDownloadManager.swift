import Foundation
import Combine

@MainActor
final class PlaylistDownloadManager: ObservableObject {
    @Published var state: PlaylistDownloadState = .idle

    private var cancelled = false
    private var currentProcess: Process?

    func start(url: String,
               albumName: String,
               fixedAlbumArtist: String?,
               cookieBrowser: CookieBrowser,
               history: HistoryStore) async {
        cancelled = false
        currentProcess = nil

        guard let ytdlp = Tools.ytdlp else {
            state = .error("yt-dlp が見つかりません")
            return
        }
        guard let ffmpeg = Tools.ffmpeg else {
            state = .error("ffmpeg が見つかりません")
            return
        }
        let ffmpegDir = (ffmpeg as NSString).deletingLastPathComponent

        state = .fetching

        guard let info = await fetchPlaylistInfo(url: url, ytdlp: ytdlp, cookieBrowser: cookieBrowser) else {
            state = .error("プレイリスト情報の取得に失敗")
            return
        }
        guard !info.entries.isEmpty else {
            state = .error("プレイリストが空です")
            return
        }

        var succeeded = 0
        var failed: [String] = []
        var sharedAlbumArt: String?
        let total = info.entries.count

        for (index, entry) in info.entries.enumerated() {
            if cancelled {
                state = .cancelled(succeeded: succeeded, total: total)
                return
            }

            state = .downloading(current: index + 1,
                                 total: total,
                                 currentTitle: entry.title,
                                 currentProgress: 0)

            do {
                let item = try await downloadOne(
                    entry: entry,
                    trackNumber: index + 1,
                    totalTracks: total,
                    albumName: albumName,
                    fixedAlbumArtist: fixedAlbumArtist,
                    fallbackAlbumArtist: info.uploader,
                    sharedAlbumArt: &sharedAlbumArt,
                    ytdlp: ytdlp,
                    ffmpegDir: ffmpegDir,
                    cookieBrowser: cookieBrowser
                )
                history.add(item)
                succeeded += 1
            } catch {
                failed.append(entry.title)
            }
        }

        if cancelled {
            state = .cancelled(succeeded: succeeded, total: total)
        } else {
            state = .finished(succeeded: succeeded, failed: failed)
        }
    }

    func cancel() {
        cancelled = true
        currentProcess?.terminate()
    }

    func reset() {
        state = .idle
        cancelled = false
    }

    // MARK: - Playlist info

    private struct PlaylistInfo {
        let title: String
        let uploader: String
        let entries: [PlaylistEntry]
    }

    private struct PlaylistEntry {
        let videoID: String
        let title: String
        var watchURL: String { "https://www.youtube.com/watch?v=\(videoID)" }
    }

    private struct FlatPlaylistJSON: Decodable {
        let title: String?
        let uploader: String?
        let channel: String?
        let entries: [Entry]?

        struct Entry: Decodable {
            let id: String
            let title: String?
        }
    }

    private func fetchPlaylistInfo(url: String, ytdlp: String, cookieBrowser: CookieBrowser) async -> PlaylistInfo? {
        await withCheckedContinuation { (cont: CheckedContinuation<PlaylistInfo?, Never>) in
            DispatchQueue.global().async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: ytdlp)
                p.arguments = [
                    "--flat-playlist",
                    "--dump-single-json",
                    "--yes-playlist",
                    "--no-warnings"
                ] + cookieBrowser.ytDlpArgs + [url]

                let pipe = Pipe()
                p.standardOutput = pipe
                p.standardError = Pipe()

                do {
                    try p.run()
                    p.waitUntilExit()
                } catch {
                    cont.resume(returning: nil)
                    return
                }

                guard p.terminationStatus == 0 else {
                    cont.resume(returning: nil)
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let parsed = try? JSONDecoder().decode(FlatPlaylistJSON.self, from: data) else {
                    cont.resume(returning: nil)
                    return
                }

                let entries = (parsed.entries ?? []).map { e in
                    PlaylistEntry(videoID: e.id, title: e.title ?? e.id)
                }
                let info = PlaylistInfo(
                    title: parsed.title ?? "Untitled Playlist",
                    uploader: parsed.uploader ?? parsed.channel ?? "",
                    entries: entries
                )
                cont.resume(returning: info)
            }
        }
    }

    // MARK: - Single track

    private struct TrackInfoJSON: Decodable {
        let title: String
        let uploader: String?
        let channel: String?
    }

    private func downloadOne(
        entry: PlaylistEntry,
        trackNumber: Int,
        totalTracks: Int,
        albumName: String,
        fixedAlbumArtist: String?,
        fallbackAlbumArtist: String,
        sharedAlbumArt: inout String?,
        ytdlp: String,
        ffmpegDir: String,
        cookieBrowser: CookieBrowser
    ) async throws -> HistoryItem {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("yttomusic-pl-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let outputTemplate = tempDir.appendingPathComponent("%(id)s.%(ext)s").path

        let args: [String] = [
            "-x",
            "--audio-format", "mp3",
            "--audio-quality", "0",
            "--write-info-json",
            "--write-thumbnail",
            "--convert-thumbnails", "jpg",
            "--no-playlist",
            "--newline",
            "--progress",
            "--no-warnings",
            "--ffmpeg-location", ffmpegDir,
            "-o", outputTemplate
        ] + cookieBrowser.ytDlpArgs + [entry.watchURL]

        try await runProcessTrackingProgress(executable: ytdlp, arguments: args, current: trackNumber, total: totalTracks, title: entry.title)

        let files = (try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)) ?? []
        guard let mp3 = files.first(where: { $0.pathExtension.lowercased() == "mp3" }) else {
            throw NSError(domain: "Playlist", code: 1, userInfo: [NSLocalizedDescriptionKey: "mp3 not found"])
        }
        let infoJSON = files.first { $0.lastPathComponent.hasSuffix(".info.json") }
        let thumb = files.first { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }

        var trackTitle = entry.title
        var perTrackArtist = fallbackAlbumArtist
        if let info = infoJSON,
           let data = try? Data(contentsOf: info),
           let parsed = try? JSONDecoder().decode(TrackInfoJSON.self, from: data) {
            trackTitle = parsed.title
            perTrackArtist = parsed.uploader ?? parsed.channel ?? fallbackAlbumArtist
        }

        let artistForTrack = fixedAlbumArtist ?? perTrackArtist
        let albumArtistForTrack = fixedAlbumArtist ?? fallbackAlbumArtist

        // 最初のトラックのサムネをアルバム全体の表紙として使い回す
        let artForThisTrack: String?
        if let existing = sharedAlbumArt {
            artForThisTrack = existing
        } else if let thumb {
            sharedAlbumArt = thumb.path
            artForThisTrack = thumb.path
        } else {
            artForThisTrack = nil
        }

        let savedURL = try MusicLibrary.save(
            mp3Source: mp3.path,
            thumbnail: artForThisTrack,
            title: trackTitle,
            artist: artistForTrack,
            album: albumName,
            albumArtist: albumArtistForTrack,
            trackNumber: trackNumber,
            totalTracks: totalTracks
        )

        let savedThumb = HistoryStore.persistThumbnail(from: artForThisTrack)
        let item = HistoryItem(
            id: UUID(),
            kind: .appleMusic,
            url: entry.watchURL,
            title: trackTitle,
            artist: artistForTrack,
            album: albumName,
            savedAt: Date(),
            thumbnailPath: savedThumb,
            savedFilePath: savedURL.path
        )
        return item
    }

    private func runProcessTrackingProgress(executable: String,
                                            arguments: [String],
                                            current: Int,
                                            total: Int,
                                            title: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: executable)
            p.arguments = arguments

            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe

            let buffer = OutputBuffer()

            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
                _ = buffer.append(s)
                if let m = s.range(of: #"(\d+(?:\.\d+)?)%"#, options: .regularExpression) {
                    let pctStr = s[m].dropLast()
                    if let pct = Double(pctStr) {
                        Task { @MainActor [weak self] in
                            self?.state = .downloading(current: current, total: total, currentTitle: title, currentProgress: pct / 100)
                        }
                    }
                }
            }

            p.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                if proc.terminationStatus == 0 {
                    cont.resume(returning: ())
                } else {
                    let tail = String(buffer.snapshot().suffix(300))
                    cont.resume(throwing: NSError(
                        domain: "Playlist", code: Int(proc.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: tail]
                    ))
                }
            }

            do {
                try p.run()
                Task { @MainActor [weak self] in
                    self?.currentProcess = p
                }
            } catch {
                cont.resume(throwing: error)
            }
        }
    }

    private final class OutputBuffer: @unchecked Sendable {
        private var value = ""
        private let lock = NSLock()
        func append(_ s: String) -> String {
            lock.lock(); defer { lock.unlock() }
            value += s
            return value
        }
        func snapshot() -> String {
            lock.lock(); defer { lock.unlock() }
            return value
        }
    }
}
