import Foundation
import Combine

struct PreviewMetadata: Equatable {
    let title: String
    let uploader: String
    let duration: Int?
    let thumbnailPath: String?
}

@MainActor
final class DownloadManager: ObservableObject {
    @Published var state: DownloadState = .idle
    @Published var preview: PreviewMetadata?

    private var process: Process?
    private var stderrBuffer = ""
    private var currentTempDir: URL?
    private var previewEmitted = false

    func download(url: String, cookieBrowser: CookieBrowser = .none) {
        guard let ytdlp = Tools.ytdlp else {
            state = .error("yt-dlp が見つかりません。`brew install yt-dlp` を実行してください")
            return
        }
        guard let ffmpeg = Tools.ffmpeg else {
            state = .error("ffmpeg が見つかりません。`brew install ffmpeg` を実行してください")
            return
        }
        let ffmpegDir = (ffmpeg as NSString).deletingLastPathComponent

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("yttomusic-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        currentTempDir = tempDir

        let outputTemplate = tempDir.appendingPathComponent("%(id)s.%(ext)s").path

        let p = Process()
        p.executableURL = URL(fileURLWithPath: ytdlp)
        p.arguments = [
            "-x",
            "--audio-format", "mp3",
            "--audio-quality", "0",
            "--write-info-json",
            "--write-thumbnail",
            "--convert-thumbnails", "jpg",
            "--no-playlist",
            "--newline",
            "--progress",
            "--ffmpeg-location", ffmpegDir,
            "-o", outputTemplate
        ] + cookieBrowser.ytDlpArgs + [url]

        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        stderrBuffer = ""
        previewEmitted = false
        preview = nil

        state = .working(stage: .starting, status: "開始中…")

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.parseOutput(str)
            }
        }

        p.terminationHandler = { [weak self] proc in
            Task { @MainActor [weak self] in
                self?.handleCompletion(in: tempDir, exitCode: proc.terminationStatus, url: url)
            }
        }

        do {
            try p.run()
            self.process = p
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func parseOutput(_ output: String) {
        stderrBuffer += output
        for raw in output.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = String(raw).trimmingCharacters(in: .whitespaces)
            updateStage(from: line)
        }
        tryEmitPreview()
    }

    private func updateStage(from line: String) {
        if line.contains("[youtube]") || line.contains("Extracting URL") || line.contains("Downloading webpage") {
            state = .working(stage: .fetchingInfo, status: "情報を取得中…")
            return
        }
        if line.contains("[info]") {
            state = .working(stage: .fetchingInfo, status: "情報を取得中…")
            return
        }
        if let m = line.range(of: #"(\d+(?:\.\d+)?)%"#, options: .regularExpression) {
            let pctStr = line[m].dropLast()
            if let pct = Double(pctStr) {
                state = .working(stage: .downloading(progress: pct / 100), status: line)
                return
            }
        }
        if line.contains("[ExtractAudio]") {
            state = .working(stage: .extractingAudio, status: "音声を抽出中…")
            return
        }
        if line.contains("[EmbedThumbnail]") || line.contains("[Metadata]") || line.contains("[ThumbnailsConvertor]") {
            state = .working(stage: .embeddingMetadata, status: "メタデータを埋め込み中…")
        }
    }

    private func tryEmitPreview() {
        guard !previewEmitted, let dir = currentTempDir else { return }
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        guard let infoJSON = files.first(where: { $0.lastPathComponent.hasSuffix(".info.json") }),
              let data = try? Data(contentsOf: infoJSON),
              let info = try? JSONDecoder().decode(InfoJSON.self, from: data) else { return }
        let thumb = files.first { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
        previewEmitted = true
        preview = PreviewMetadata(
            title: info.title,
            uploader: info.uploader ?? info.channel ?? "",
            duration: info.duration,
            thumbnailPath: thumb?.path
        )
    }

    private func handleCompletion(in dir: URL, exitCode: Int32, url: String) {
        guard exitCode == 0 else {
            let tail = String(stderrBuffer.suffix(400))
            state = .error("ダウンロード失敗 (exit \(exitCode))\n\(tail)")
            return
        }

        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        guard let mp3 = files.first(where: { $0.pathExtension.lowercased() == "mp3" }) else {
            state = .error("mp3 が見つかりません")
            return
        }
        guard let infoJSON = files.first(where: { $0.lastPathComponent.hasSuffix(".info.json") }),
              let data = try? Data(contentsOf: infoJSON),
              let info = try? JSONDecoder().decode(InfoJSON.self, from: data) else {
            state = .error("メタデータ解析失敗")
            return
        }
        let thumb = files.first { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }

        let meta = VideoMetadata(
            url: url,
            videoID: info.id,
            originalTitle: info.title,
            uploader: info.uploader ?? info.channel ?? "",
            duration: info.duration,
            thumbnailPath: thumb?.path,
            mp3Path: mp3.path
        )
        state = .ready(meta)
    }

    func reset() {
        state = .idle
        preview = nil
        stderrBuffer = ""
    }

    func setSaving() { state = .saving }
    func setSaved(_ item: HistoryItem) { state = .saved(item) }
    func failSaving(_ msg: String) { state = .error(msg) }
}

private struct InfoJSON: Decodable {
    let id: String
    let title: String
    let uploader: String?
    let channel: String?
    let duration: Int?
}
