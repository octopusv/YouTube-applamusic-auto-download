import Foundation

/// ミュージック.app のライブラリ内のトラックを AppleScript 経由で編集する。
/// 初回実行時、macOS の Automation 権限ダイアログが出る。
enum MusicLibraryEditor {

    enum EditError: LocalizedError {
        case scriptFailed(String)
        case trackNotFound

        var errorDescription: String? {
            switch self {
            case .scriptFailed(let s): return "ミュージック.app の操作に失敗: \(s)"
            case .trackNotFound: return "ライブラリ内に該当する曲が見つかりませんでした。同期完了を待ってから再試行してください。"
            }
        }
    }

    /// 旧タイトル/アーティストで対象を見つけ、新しいメタデータを書き込む。
    /// アートワーク差し替えも同時に行う。
    static func update(
        oldTitle: String,
        oldArtist: String,
        newTitle: String,
        newArtist: String,
        newAlbum: String,
        newAlbumArtist: String?,
        newArtworkPath: String?
    ) throws {
        let albumArtistValue = newAlbumArtist ?? newArtist

        var script = """
        tell application "Music"
            try
                set t to (first track of library playlist 1 whose name is "\(escape(oldTitle))" and artist is "\(escape(oldArtist))")
            on error
                error "TRACK_NOT_FOUND"
            end try
            set name of t to "\(escape(newTitle))"
            set artist of t to "\(escape(newArtist))"
            set album of t to "\(escape(newAlbum))"
            set album artist of t to "\(escape(albumArtistValue))"
        """

        if let path = newArtworkPath, FileManager.default.fileExists(atPath: path) {
            script += """

            tell t
                try
                    delete artworks
                end try
                set artworkData to (read (POSIX file "\(escape(path))") as picture)
                set data of artwork 1 to artworkData
            end tell
            """
        }

        script += "\nend tell"

        do {
            try runAppleScript(script)
        } catch let EditError.scriptFailed(msg) where msg.contains("TRACK_NOT_FOUND") {
            throw EditError.trackNotFound
        }
    }

    @discardableResult
    private static func runAppleScript(_ source: String) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", source]
        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        try p.run()
        p.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let outStr = String(data: outData, encoding: .utf8) ?? ""

        if p.terminationStatus != 0 {
            let errStr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw EditError.scriptFailed(errStr.isEmpty ? outStr : errStr)
        }
        return outStr
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
