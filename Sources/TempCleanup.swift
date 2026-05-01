import Foundation

/// 起動時に前回のセッションが残した temp ディレクトリを掃除する。
/// `FileManager.default.temporaryDirectory` 配下の `yttomusic-*` を全削除。
enum TempCleanup {
    static func sweepStaleSessions() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        var freedBytes: Int64 = 0
        var removed = 0
        for url in entries {
            let name = url.lastPathComponent
            guard name.hasPrefix("yttomusic-") || name.hasPrefix("yttomusic-file-") || name.hasPrefix("yttomusic-pl-") else {
                continue
            }
            if let size = directorySize(url) { freedBytes += size }
            do {
                try FileManager.default.removeItem(at: url)
                removed += 1
            } catch {
                // 失敗しても致命ではない、無視
            }
        }
        if removed > 0 {
            let mb = Double(freedBytes) / 1_048_576
            print("TempCleanup: removed \(removed) stale dir(s), freed \(String(format: "%.1f", mb)) MB")
        }
    }

    private static func directorySize(_ url: URL) -> Int64? {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return nil }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let v = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  v.isRegularFile == true else { continue }
            total += Int64(v.fileSize ?? 0)
        }
        return total
    }
}
