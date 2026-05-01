import Foundation
import Combine

@MainActor
final class FileDownloadManager: ObservableObject {
    @Published var state: FileDownloadState = .idle

    private var process: Process?
    private var stderrBuffer = ""

    func download(url: String, format: FileFormat, destination: URL, cookieBrowser: CookieBrowser = .none) {
        guard let validatedURL = Sanitization.validateHTTPURL(url) else {
            state = .error("URL が不正です。http(s) スキームの URL を入力してください")
            return
        }
        let safeURL = validatedURL.absoluteString
        guard let ytdlp = Tools.ytdlp else {
            state = .error("yt-dlp が見つかりません。`brew install yt-dlp` を実行してください")
            return
        }
        guard let ffmpeg = Tools.ffmpeg else {
            state = .error("ffmpeg が見つかりません。`brew install ffmpeg` を実行してください")
            return
        }
        let ffmpegDir = (ffmpeg as NSString).deletingLastPathComponent

        guard FileManager.default.fileExists(atPath: destination.path) else {
            state = .error("保存先フォルダが見つかりません: \(destination.path)")
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("yttomusic-file-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let outputTemplate = tempDir.appendingPathComponent("%(title)s.%(ext)s").path

        let p = Process()
        p.executableURL = URL(fileURLWithPath: ytdlp)
        p.arguments = [
            "--write-info-json",
            "--write-thumbnail",
            "--convert-thumbnails", "jpg",
            "--no-playlist",
            "--newline",
            "--progress",
            "--ffmpeg-location", ffmpegDir,
            "-o", outputTemplate
        ] + format.ytDlpArgs + cookieBrowser.ytDlpArgs + ["--", safeURL]

        p.environment = Tools.augmentedEnvironment()

        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        stderrBuffer = ""

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
                self?.handleCompletion(in: tempDir,
                                       exitCode: proc.terminationStatus,
                                       url: url,
                                       format: format,
                                       destination: destination)
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
    }

    private func updateStage(from line: String) {
        if line.contains("Extracting URL") || line.contains("Downloading webpage") || line.contains("[info]") {
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
        if line.contains("[Merger]") || line.contains("[VideoConvertor]") {
            state = .working(stage: .embeddingMetadata, status: "結合中…")
            return
        }
        if line.contains("[EmbedThumbnail]") || line.contains("[Metadata]") {
            state = .working(stage: .embeddingMetadata, status: "メタデータを処理中…")
        }
    }

    private func handleCompletion(in dir: URL,
                                  exitCode: Int32,
                                  url: String,
                                  format: FileFormat,
                                  destination: URL) {
        guard exitCode == 0 else {
            let tail = String(stderrBuffer.suffix(400))
            state = .error("ダウンロード失敗 (exit \(exitCode))\n\(tail)")
            return
        }

        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let target = files.first { $0.pathExtension.lowercased() == format.fileExtension }
            ?? files.first(where: { !$0.lastPathComponent.contains(".info.json")
                                   && !["jpg", "jpeg", "png", "webp"].contains($0.pathExtension.lowercased()) })

        guard let media = target else {
            state = .error("出力ファイルが見つかりません")
            return
        }

        let thumb = files.first { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
        let infoJSON = files.first { $0.lastPathComponent.hasSuffix(".info.json") }
        var title = media.deletingPathExtension().lastPathComponent
        var uploader = ""
        if let info = infoJSON,
           let data = try? Data(contentsOf: info),
           let parsed = try? JSONDecoder().decode(InfoJSON.self, from: data) {
            title = parsed.title
            uploader = parsed.uploader ?? parsed.channel ?? ""
        }

        let safeName = sanitize(title) + "." + format.fileExtension
        let dest = destination.appendingPathComponent(safeName)
        let finalDest = uniquePath(dest)

        do {
            try FileManager.default.moveItem(at: media, to: finalDest)
        } catch {
            state = .error("移動失敗: \(error.localizedDescription)")
            return
        }

        let savedThumb = HistoryStore.persistThumbnail(from: thumb?.path)
        let item = HistoryItem(
            id: UUID(),
            kind: .file,
            url: url,
            title: title,
            artist: uploader,
            album: "",
            savedAt: Date(),
            thumbnailPath: savedThumb,
            savedFilePath: finalDest.path,
            formatLabel: format.displayName
        )
        state = .saved(item)
    }

    func cancel() {
        process?.terminate()
        process = nil
        state = .idle
        stderrBuffer = ""
    }

    func reset() {
        state = .idle
        stderrBuffer = ""
    }

    private func sanitize(_ s: String) -> String {
        Sanitization.filename(s)
    }

    private func uniquePath(_ url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let dir = url.deletingLastPathComponent()
        var i = 2
        while true {
            let candidate = dir.appendingPathComponent("\(base) (\(i)).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            i += 1
        }
    }
}

private struct InfoJSON: Decodable {
    let title: String
    let uploader: String?
    let channel: String?
}
