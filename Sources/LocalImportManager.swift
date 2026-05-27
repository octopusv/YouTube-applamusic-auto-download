import Foundation
import Combine

/// 手持ちの mp3 / mp4 などローカルファイルを Apple Music に取り込むためのマネージャ。
///
/// 流れ:
///   ファイル群を受け取る → キューに積む
///   → 1 件ずつ `prepare`（mp3 へ正規化・埋め込みアート抽出・タグ読み取り）
///   → VideoMetadata を作って `.editing` へ（EditorView を再利用して保存）
///   → 保存完了で次の 1 件へ。
///
/// 出口（タグ埋め込み + 自動取り込みフォルダへ配置）は既存の `MusicLibrary.save` を流用するため、
/// このマネージャは「入力を mp3 に揃えて VideoMetadata を用意する」ところまでを担う。
@MainActor
final class LocalImportManager: ObservableObject {
    @Published var state: LocalImportState = .idle

    private var queue: [URL] = []
    private var totalCount = 0
    private var currentIndex = 0
    /// prepare で作った一時ファイルの置き場（セッション終了時に掃除される）
    private var sessionTempDir: URL?

    /// Finder/ドロップから渡された URL 群のうち、取り込み可能なものをキューに積んで処理を開始する。
    func add(files: [URL]) {
        let accepted = files.filter { url in
            let ext = url.pathExtension.lowercased()
            return Tools.audioExtensions.contains(ext) || Tools.videoExtensions.contains(ext)
        }
        guard !accepted.isEmpty else {
            state = .error("対応していないファイル形式です。mp3 / m4a / wav / flac や mp4 / mov などの音声・動画ファイルを選んでください")
            return
        }
        guard Tools.ffmpeg != nil else {
            state = .error("ffmpeg が見つかりません。`brew install ffmpeg` を実行してください")
            return
        }

        queue = accepted
        totalCount = accepted.count
        currentIndex = 0
        prepareNext()
    }

    /// EditorView での保存完了後に呼ぶ。残りがあれば次の 1 件へ進む。
    func advanceAfterSave(_ item: HistoryItem) {
        let remaining = queue.count
        state = .saved(item: item, remaining: remaining)
        if remaining == 0 { cleanupSession() }
    }

    /// 「次へ」操作（保存済みビューから次の準備を開始）
    func continueQueue() {
        if queue.isEmpty {
            reset()
        } else {
            prepareNext()
        }
    }

    /// 現在の 1 件をスキップして次へ。
    func skipCurrent() {
        continueQueue()
    }

    func reset() {
        queue = []
        totalCount = 0
        currentIndex = 0
        state = .idle
        cleanupSession()
    }

    func setSaving() {
        state = .saving
    }

    func failSaving(_ message: String) {
        state = .error(message)
    }

    // MARK: - 準備処理

    private func prepareNext() {
        guard !queue.isEmpty else {
            state = .idle
            cleanupSession()
            return
        }
        let url = queue.removeFirst()
        currentIndex += 1
        let index = currentIndex
        let total = totalCount
        let remaining = queue.count
        state = .preparing(fileName: url.lastPathComponent, index: index, total: total)

        let tempDir = ensureSessionTempDir()

        Task.detached(priority: .userInitiated) {
            do {
                let meta = try Self.prepare(source: url, tempDir: tempDir)
                await MainActor.run {
                    self.state = .editing(metadata: meta, index: index, total: total, remaining: remaining)
                }
            } catch {
                await MainActor.run {
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    private func ensureSessionTempDir() -> URL {
        if let dir = sessionTempDir { return dir }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("yttomusic-import-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        sessionTempDir = dir
        return dir
    }

    private func cleanupSession() {
        if let dir = sessionTempDir {
            try? FileManager.default.removeItem(at: dir)
        }
        sessionTempDir = nil
    }

    // MARK: - 1 ファイルを VideoMetadata に変換（MainActor 外で実行）

    private nonisolated static func prepare(source: URL, tempDir: URL) throws -> VideoMetadata {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw LocalImportError.fileMissing(source.lastPathComponent)
        }
        guard let ffmpeg = Tools.ffmpeg else { throw LocalImportError.ffmpegMissing }

        let ext = source.pathExtension.lowercased()
        let isVideo = Tools.videoExtensions.contains(ext)

        // 1) 音声を mp3 に揃える。元が mp3 なら無変換でそのまま使う（再エンコードによる劣化を避ける）。
        let mp3Path: String
        if ext == "mp3" {
            mp3Path = source.path
        } else {
            let out = tempDir.appendingPathComponent("\(UUID().uuidString).mp3")
            try runFFmpeg(ffmpeg, [
                "-y", "-i", source.path,
                "-vn",                       // 映像を捨てて音声だけ取り出す（動画→音声変換もここで成立）
                "-c:a", "libmp3lame", "-q:a", "0",
                out.path
            ])
            mp3Path = out.path
        }

        // 2) アートワーク抽出（埋め込み画像 or 動画の 1 フレーム目）。失敗しても nil でよい。
        let thumbPath = extractArtwork(ffmpeg: ffmpeg, source: source, isVideo: isVideo, tempDir: tempDir)

        // 3) タグからタイトル/アーティストを読む。無ければファイル名を使う。
        let tags = readTags(source: source)
        let fallbackTitle = source.deletingPathExtension().lastPathComponent
        let title = tags.title?.isEmpty == false ? tags.title! : fallbackTitle

        return VideoMetadata(
            url: source.path,
            videoID: "",
            originalTitle: title,
            uploader: tags.artist ?? "",
            duration: tags.duration,
            thumbnailPath: thumbPath,
            mp3Path: mp3Path
        )
    }

    private nonisolated static func extractArtwork(ffmpeg: String, source: URL, isVideo: Bool, tempDir: URL) -> String? {
        let out = tempDir.appendingPathComponent("\(UUID().uuidString).jpg")
        let args: [String]
        if isVideo {
            // 動画は先頭付近の 1 フレームをサムネとして抜く
            args = ["-y", "-i", source.path, "-frames:v", "1", "-q:v", "2", out.path]
        } else {
            // 音声ファイルに埋め込まれたカバー画像を取り出す
            args = ["-y", "-i", source.path, "-an", "-vcodec", "copy", out.path]
        }
        do {
            try runFFmpeg(ffmpeg, args)
        } catch {
            return nil
        }
        guard FileManager.default.fileExists(atPath: out.path),
              Sanitization.isLikelyImage(at: out.path) else { return nil }
        return out.path
    }

    private nonisolated static func readTags(source: URL) -> (title: String?, artist: String?, duration: Int?) {
        guard let ffprobe = Tools.ffprobe else { return (nil, nil, nil) }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ffprobe)
        p.arguments = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            source.path
        ]
        p.environment = Tools.augmentedEnvironment()
        let outPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = Pipe()
        do {
            try p.run()
        } catch {
            return (nil, nil, nil)
        }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let probe = try? JSONDecoder().decode(FFProbeOutput.self, from: data) else {
            return (nil, nil, nil)
        }
        let tags = probe.format?.tags
        let title = tags?.title ?? tags?.Title
        let artist = tags?.artist ?? tags?.Artist ?? tags?.album_artist
        let duration = probe.format?.duration.flatMap { Double($0) }.map { Int($0.rounded()) }
        return (title.map { Sanitization.metadata($0) },
                artist.map { Sanitization.metadata($0) },
                duration)
    }

    private nonisolated static func runFFmpeg(_ ffmpeg: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ffmpeg)
        p.arguments = args
        p.environment = Tools.augmentedEnvironment()
        let errPipe = Pipe()
        p.standardOutput = Pipe()
        p.standardError = errPipe
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw LocalImportError.ffmpegFailed(String(msg.suffix(300)))
        }
    }
}

enum LocalImportError: LocalizedError {
    case ffmpegMissing
    case ffmpegFailed(String)
    case fileMissing(String)

    var errorDescription: String? {
        switch self {
        case .ffmpegMissing: return "ffmpeg が見つかりません。`brew install ffmpeg` を実行してください"
        case .ffmpegFailed(let msg): return "音声の変換に失敗しました: \(msg)"
        case .fileMissing(let name): return "ファイルが見つかりません: \(name)"
        }
    }
}

private struct FFProbeOutput: Decodable {
    let format: Format?
    struct Format: Decodable {
        let duration: String?
        let tags: Tags?
    }
    struct Tags: Decodable {
        let title: String?
        let Title: String?
        let artist: String?
        let Artist: String?
        let album_artist: String?
    }
}
