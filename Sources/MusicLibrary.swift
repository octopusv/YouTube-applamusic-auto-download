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

    /// 「ファイル → ライブラリ → クラウドライブラリをアップデート」を UI スクリプトで叩く。
    /// 初回は System Events への Automation 権限ダイアログが出る。
    /// 失敗時は throw、成功時は何も返さない（Music.app 側で進捗が表示される）。
    static func refreshCloudLibrary() throws {
        let script = #"""
        tell application "Music" to activate
        delay 0.4
        tell application "System Events"
            tell process "Music"
                -- ファイル メニュー
                set fileMenu to missing value
                try
                    set fileMenu to menu bar item "ファイル" of menu bar 1
                end try
                if fileMenu is missing value then
                    set fileMenu to menu bar item "File" of menu bar 1
                end if
                click fileMenu
                delay 0.2

                -- ライブラリ サブメニュー
                set libraryItem to missing value
                try
                    set libraryItem to menu item "ライブラリ" of menu 1 of fileMenu
                end try
                if libraryItem is missing value then
                    set libraryItem to menu item "Library" of menu 1 of fileMenu
                end if
                click libraryItem
                delay 0.2

                -- クラウドライブラリをアップデート
                set candidates to {"クラウドライブラリをアップデート", "クラウドミュージックライブラリを更新", "iCloud ミュージックライブラリを更新", "Update Cloud Library", "Update iCloud Music Library"}
                set updateItem to missing value
                repeat with c in candidates
                    try
                        set updateItem to menu item (c as string) of menu 1 of libraryItem
                        exit repeat
                    end try
                end repeat
                if updateItem is missing value then
                    error "クラウドライブラリ更新メニューが見つかりません"
                end if
                click updateItem
            end tell
        end tell
        """#
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
