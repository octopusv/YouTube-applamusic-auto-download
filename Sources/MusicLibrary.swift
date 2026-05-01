import Foundation
import AppKit

enum MusicLibraryError: LocalizedError {
    case ffmpegMissing
    case ffmpegFailed(String)
    case autoAddFolderMissing

    var errorDescription: String? {
        switch self {
        case .ffmpegMissing: return "ffmpeg が見つかりません"
        case .ffmpegFailed(let msg): return "ffmpeg 失敗: \(msg)"
        case .autoAddFolderMissing:
            return "自動取り込みフォルダが見つかりません。ミュージック.app を一度起動してください"
        }
    }
}

enum MusicLibrary {
    static func save(
        mp3Source: String,
        thumbnail: String?,
        title: String,
        artist: String,
        album: String,
        albumArtist: String? = nil,
        trackNumber: Int? = nil,
        totalTracks: Int? = nil
    ) throws -> URL {
        guard let ffmpeg = Tools.ffmpeg else { throw MusicLibraryError.ffmpegMissing }
        guard FileManager.default.fileExists(atPath: AppPaths.autoAddFolder.path) else {
            throw MusicLibraryError.autoAddFolderMissing
        }

        let tempOut = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).mp3")

        var args: [String] = ["-y", "-i", mp3Source]
        if let thumbnail { args += ["-i", thumbnail] }

        if thumbnail != nil {
            args += [
                "-map", "0:a",
                "-map", "1",
                "-c", "copy",
                "-id3v2_version", "3",
                "-metadata:s:v", "title=Album cover",
                "-metadata:s:v", "comment=Cover (front)"
            ]
        } else {
            args += ["-c", "copy", "-id3v2_version", "3"]
        }

        let resolvedAlbumArtist = albumArtist ?? artist
        args += [
            "-metadata", "title=\(title)",
            "-metadata", "artist=\(artist)",
            "-metadata", "album=\(album)",
            "-metadata", "album_artist=\(resolvedAlbumArtist)"
        ]

        if let trackNumber, let totalTracks {
            args += ["-metadata", "track=\(trackNumber)/\(totalTracks)"]
        } else if let trackNumber {
            args += ["-metadata", "track=\(trackNumber)"]
        }

        args.append(tempOut.path)

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
            throw MusicLibraryError.ffmpegFailed(String(msg.suffix(300)))
        }

        let baseName: String
        if let n = trackNumber {
            baseName = sanitize(String(format: "%02d - %@ - %@", n, artist, title))
        } else {
            baseName = sanitize("\(artist) - \(title)")
        }
        let dest = AppPaths.autoAddFolder.appendingPathComponent("\(baseName).mp3")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempOut, to: dest)
        return dest
    }

    static func revealAutoAddFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([AppPaths.autoAddFolder])
    }

    static func openMusicApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// 「ファイル → ライブラリ → クラウドミュージックライブラリを更新」を UI スクリプトで叩く。
    /// 初回は System Events への Automation 権限ダイアログが出る。
    /// 失敗時は throw、成功時は何も返さない（Music.app 側で進捗が表示される）。
    static func refreshCloudLibrary() throws {
        let script = """
        tell application "Music" to activate
        delay 0.4
        tell application "System Events"
            tell process "Music"
                set fileMenu to (first menu bar item of menu bar 1 whose name is in {"File", "ファイル"})
                click fileMenu
                delay 0.2
                set libraryItem to (first menu item of menu of fileMenu whose name is in {"Library", "ライブラリ"})
                click libraryItem
                delay 0.2
                set updateItem to (first menu item of menu of libraryItem whose name is in {"Update Cloud Library", "Update iCloud Music Library", "クラウドミュージックライブラリを更新", "iCloud ミュージックライブラリを更新"})
                click updateItem
            end tell
        end tell
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        let errPipe = Pipe()
        p.standardOutput = Pipe()
        p.standardError = errPipe
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw NSError(domain: "MusicLibrary.refreshCloudLibrary",
                          code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    private static func sanitize(_ s: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return s.components(separatedBy: invalid).joined(separator: "_")
    }
}
