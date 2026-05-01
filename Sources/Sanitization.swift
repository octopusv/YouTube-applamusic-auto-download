import Foundation

/// 外部入力（yt-dlp の info.json、ユーザー編集 UI、履歴 JSON 等）が
/// ffmpeg / AppleScript / ファイル名 / ID3 タグへ流れる前段で必ず通すサニタイザ群。
enum Sanitization {

    // MARK: - メタデータ文字列

    /// メタデータ文字列を ID3 タグ・AppleScript 値・UI 表示に流す前の正規化。
    /// 制御文字（改行・NUL 等）と U+2028/U+2029 を除去し、長さ上限で切り詰める。
    /// NFC 正規化も同時に行う。
    static func metadata(_ s: String, maxLength: Int = 256) -> String {
        var out = String.UnicodeScalarView()
        out.reserveCapacity(s.unicodeScalars.count)
        for scalar in s.unicodeScalars {
            if scalar.value < 0x20 && scalar != "\t" { continue }
            if scalar == "\u{007F}" { continue }
            if scalar == "\u{2028}" || scalar == "\u{2029}" { continue }
            out.append(scalar)
        }
        let cleaned = String(out).precomposedStringWithCanonicalMapping
        if cleaned.count <= maxLength { return cleaned }
        return String(cleaned.prefix(maxLength))
    }

    // MARK: - ファイル名

    /// ファイル名として安全な文字列を返す。空や `..` 単独になる場合は fallback を使う。
    /// HFS+/APFS の 255 byte 制限に収まるよう UTF-8 バイト長で切り詰める。
    static func filename(_ s: String, fallback: @autoclosure () -> String = UUID().uuidString) -> String {
        let invalid: Set<Character> = [
            "/", "\\", ":", "*", "?", "\"", "<", ">", "|",
            "\u{2044}", "\u{FF0F}"
        ]
        var cleaned = metadata(s, maxLength: 200)
        cleaned = String(cleaned.map { invalid.contains($0) ? "_" : $0 })
        while let first = cleaned.first, first == "." || first == "-" {
            cleaned.removeFirst()
        }
        while let last = cleaned.last, last == " " || last == "." {
            cleaned.removeLast()
        }
        if cleaned.isEmpty || cleaned == "." || cleaned == ".." {
            return fallback()
        }
        // grapheme 単位で末尾削減して 200 byte に収める（拡張子分の余白を残す）
        while cleaned.utf8.count > 200, !cleaned.isEmpty {
            cleaned.removeLast()
        }
        if cleaned.isEmpty { return fallback() }
        return cleaned
    }

    // MARK: - URL

    /// http(s) スキームかつホスト名のあるものだけ通す。
    /// 制御文字混入も除外（curl/yt-dlp の引数注入対策）。
    static func validateHTTPURL(_ s: String) -> URL? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for scalar in trimmed.unicodeScalars {
            if scalar.value < 0x20 || scalar.value == 0x7F { return nil }
        }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }

    // MARK: - 画像

    /// 先頭バイトで JPEG/PNG/WebP/GIF のいずれかであることを確認し、
    /// 同時にサイズ上限を満たすかも見る。サムネイル永続化前の検証用。
    static func isLikelyImage(at path: String, maxBytes: Int = 10 * 1024 * 1024) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? NSNumber else { return false }
        let bytes = size.intValue
        guard bytes > 0, bytes <= maxBytes else { return false }
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        defer { try? handle.close() }
        let head = handle.readData(ofLength: 12)
        guard head.count >= 4 else { return false }
        let b = [UInt8](head)
        // JPEG: FF D8 FF
        if b[0] == 0xFF, b[1] == 0xD8, b[2] == 0xFF { return true }
        // PNG: 89 50 4E 47
        if b[0] == 0x89, b[1] == 0x50, b[2] == 0x4E, b[3] == 0x47 { return true }
        // GIF: 47 49 46 38
        if b[0] == 0x47, b[1] == 0x49, b[2] == 0x46, b[3] == 0x38 { return true }
        // WebP: "RIFF"....."WEBP"
        if b.count >= 12,
           b[0] == 0x52, b[1] == 0x49, b[2] == 0x46, b[3] == 0x46,
           b[8] == 0x57, b[9] == 0x45, b[10] == 0x42, b[11] == 0x50 { return true }
        return false
    }

    // MARK: - パス境界

    /// 指定の base ディレクトリ配下に収まる絶対パスかを検証する（symlink 解決後）。
    /// HistoryStore の任意ファイル削除対策などで使う。
    static func isPath(_ path: String, within base: URL) -> Bool {
        let resolved = URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL.path
        let baseResolved = base
            .resolvingSymlinksInPath()
            .standardizedFileURL.path
        if resolved == baseResolved { return true }
        let prefix = baseResolved.hasSuffix("/") ? baseResolved : baseResolved + "/"
        return resolved.hasPrefix(prefix)
    }
}
