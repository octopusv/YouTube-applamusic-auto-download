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

    /// アルバム単位の一括書き換え。oldAlbum 名を持つ全トラックの album / album artist を
    /// 新しい値に置き換え、（指定があれば）アートワークも全トラックに同じ画像を適用する。
    /// - Returns: (成功件数, 見つからなかった/失敗したトラック数)
    @discardableResult
    static func updateAlbum(
        oldAlbum: String,
        newAlbum: String,
        newAlbumArtist: String?,
        newArtworkPath: String?
    ) throws -> (succeeded: Int, failed: Int) {
        let trimmedNewAlbum = newAlbum.trimmingCharacters(in: .whitespaces)
        guard !trimmedNewAlbum.isEmpty else { throw EditError.scriptFailed("アルバム名が空です") }

        var script = """
        tell application "Music"
            set theTracks to (every track of library playlist 1 whose album is "\(escape(oldAlbum))")
            set okCount to 0
            set ngCount to 0
            repeat with t in theTracks
                try
                    set album of t to "\(escape(trimmedNewAlbum))"
        """
        if let artist = newAlbumArtist, !artist.trimmingCharacters(in: .whitespaces).isEmpty {
            script += "\n            set album artist of t to \"\(escape(artist))\""
        }
        script += """

                    set okCount to okCount + 1
                on error
                    set ngCount to ngCount + 1
                end try
            end repeat
        """

        if let path = newArtworkPath, FileManager.default.fileExists(atPath: path) {
            script += """

            try
                set artData to (read (POSIX file "\(escape(path))") as picture)
                repeat with t in theTracks
                    try
                        tell t
                            try
                                delete artworks
                            end try
                            set data of artwork 1 to artData
                        end tell
                    end try
                end repeat
            end try
            """
        }

        script += "\n            return (okCount as string) & \",\" & (ngCount as string)\nend tell"

        let out = try runAppleScript(script).trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = out.split(separator: ",")
        let ok = (parts.count > 0 ? Int(parts[0]) : nil) ?? 0
        let ng = (parts.count > 1 ? Int(parts[1]) : nil) ?? 0
        if ok == 0 && ng == 0 { throw EditError.trackNotFound }
        return (ok, ng)
    }

    /// 任意のトラック群（旧 タイトル + アーティスト で識別）に対して、
    /// album / album artist / track number を一括設定する。
    /// 配列順で 1..N の track number を採番、各トラックの artwork も指定があれば差し替える。
    /// 既に該当 album に属するトラックがある場合は、その既存トラックには触れない（呼び出し側の責任）。
    @discardableResult
    static func assignToAlbum(
        tracks: [(oldTitle: String, oldArtist: String)],
        album: String,
        albumArtist: String?,
        artworkPath: String?,
        startTrackNumber: Int = 1,
        totalTracks: Int? = nil
    ) throws -> (succeeded: Int, failed: [String]) {
        guard !tracks.isEmpty else { return (0, []) }
        let total = totalTracks ?? (startTrackNumber - 1 + tracks.count)
        let trimmedAlbum = album.trimmingCharacters(in: .whitespaces)
        guard !trimmedAlbum.isEmpty else { throw EditError.scriptFailed("アルバム名が空です") }

        let resolvedAlbumArtist = albumArtist?.trimmingCharacters(in: .whitespaces).isEmpty == false
            ? albumArtist!
            : ""

        var lines = ["tell application \"Music\"", "    set failures to {}"]

        // アートワークは一度だけ読み込んで使い回す
        let useArtwork = artworkPath.map { FileManager.default.fileExists(atPath: $0) } ?? false
        if useArtwork, let p = artworkPath {
            lines.append("    set artData to (read (POSIX file \"\(escape(p))\") as picture)")
        }

        for (i, track) in tracks.enumerated() {
            let trackNumber = startTrackNumber + i
            lines.append("    try")
            lines.append("        set t to (first track of library playlist 1 whose name is \"\(escape(track.oldTitle))\" and artist is \"\(escape(track.oldArtist))\")")
            lines.append("        set album of t to \"\(escape(trimmedAlbum))\"")
            if !resolvedAlbumArtist.isEmpty {
                lines.append("        set album artist of t to \"\(escape(resolvedAlbumArtist))\"")
            }
            lines.append("        set track number of t to \(trackNumber)")
            lines.append("        set track count of t to \(total)")
            if useArtwork {
                lines.append("        try")
                lines.append("            tell t")
                lines.append("                try")
                lines.append("                    delete artworks")
                lines.append("                end try")
                lines.append("                set data of artwork 1 to artData")
                lines.append("            end tell")
                lines.append("        end try")
            }
            lines.append("    on error")
            lines.append("        set end of failures to \"\(escape(track.oldTitle))\"")
            lines.append("    end try")
        }

        lines.append("    set AppleScript's text item delimiters to \"\\n\"")
        lines.append("    set failureText to failures as string")
        lines.append("    set AppleScript's text item delimiters to \"\"")
        lines.append("    return failureText")
        lines.append("end tell")

        let out = try runAppleScript(lines.joined(separator: "\n"))
        let failedTitles = out
            .split(whereSeparator: { $0 == "\n" })
            .map { String($0) }
            .filter { !$0.isEmpty }
        let succeeded = tracks.count - failedTitles.count
        return (succeeded, failedTitles)
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

    /// AppleScript の `"..."` 文字列リテラルへ安全に埋め込むためのエスケープ。
    /// `\` `"` をエスケープし、改行/タブは AppleScript のエスケープ表記へ、
    /// その他の制御文字（NUL 含む）と U+2028/U+2029 は除去する。
    /// Sanitization.metadata で先に NFC 正規化と長さ上限を適用する。
    private static func escape(_ s: String) -> String {
        let normalized = Sanitization.metadata(s)
        var out = ""
        out.reserveCapacity(normalized.count)
        for scalar in normalized.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 || scalar.value == 0x7F { continue }
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }
}
