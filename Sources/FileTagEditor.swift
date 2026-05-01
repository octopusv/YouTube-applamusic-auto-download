import Foundation

/// ローカルファイル（kind == .file）の ID3 タグとアートワークを ffmpeg で書き換える。
enum FileTagEditor {

    enum EditError: LocalizedError {
        case ffmpegMissing
        case fileMissing
        case ffmpegFailed(String)

        var errorDescription: String? {
            switch self {
            case .ffmpegMissing: return "ffmpeg が見つかりません"
            case .fileMissing: return "対象ファイルが見つかりません"
            case .ffmpegFailed(let s): return "ffmpeg 失敗: \(s)"
            }
        }
    }

    static func update(
        filePath: String,
        title: String,
        artist: String,
        album: String,
        albumArtist: String?,
        artworkPath: String?
    ) throws {
        guard let ffmpeg = Tools.ffmpeg else { throw EditError.ffmpegMissing }
        guard FileManager.default.fileExists(atPath: filePath) else { throw EditError.fileMissing }

        let src = URL(fileURLWithPath: filePath)
        let ext = src.pathExtension
        let tempOut = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).\(ext)")

        var args: [String] = ["-y", "-i", filePath]
        let isAudio = ["mp3", "m4a"].contains(ext.lowercased())

        if let artworkPath, FileManager.default.fileExists(atPath: artworkPath), isAudio {
            args += ["-i", artworkPath, "-map", "0:a", "-map", "1", "-c", "copy"]
            args += ["-id3v2_version", "3",
                     "-metadata:s:v", "title=Album cover",
                     "-metadata:s:v", "comment=Cover (front)"]
        } else {
            args += ["-c", "copy"]
            if isAudio { args += ["-id3v2_version", "3"] }
        }

        let albumArtistValue = albumArtist ?? artist
        args += [
            "-metadata", "title=\(title)",
            "-metadata", "artist=\(artist)",
            "-metadata", "album=\(album)",
            "-metadata", "album_artist=\(albumArtistValue)",
            tempOut.path
        ]

        let p = Process()
        p.executableURL = URL(fileURLWithPath: ffmpeg)
        p.arguments = args
        let errPipe = Pipe()
        p.standardOutput = Pipe()
        p.standardError = errPipe
        try p.run()
        p.waitUntilExit()

        guard p.terminationStatus == 0 else {
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            try? FileManager.default.removeItem(at: tempOut)
            throw EditError.ffmpegFailed(String(msg.suffix(300)))
        }

        try FileManager.default.removeItem(at: src)
        try FileManager.default.moveItem(at: tempOut, to: src)
    }
}
