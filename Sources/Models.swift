import Foundation

struct VideoMetadata: Equatable {
    let url: String
    let videoID: String
    let originalTitle: String
    let uploader: String
    let duration: Int?
    let thumbnailPath: String?
    let mp3Path: String
}

struct HistoryItem: Codable, Identifiable, Hashable {
    let id: UUID
    let url: String
    let title: String
    let artist: String
    let album: String
    let savedAt: Date
    let thumbnailPath: String?
    let savedFilePath: String?
}

enum DownloadStage: Equatable {
    case idle
    case starting
    case fetchingInfo
    case downloading(progress: Double)
    case extractingAudio
    case embeddingMetadata
}

enum DownloadState: Equatable {
    case idle
    case working(stage: DownloadStage, status: String)
    case ready(VideoMetadata)
    case saving
    case saved(HistoryItem)
    case error(String)
}

enum SidebarSelection: Hashable {
    case newDownload
    case history(UUID)
}

enum Tools {
    static func find(_ name: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/opt/local/bin/\(name)"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    static var ytdlp: String? { find("yt-dlp") }
    static var ffmpeg: String? { find("ffmpeg") }
}

enum AppPaths {
    static var autoAddFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music/Music/Media.localized/Automatically Add to Music.localized")
    }

    static var appSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("YTtoMusic")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var thumbsDir: URL {
        let dir = appSupport.appendingPathComponent("thumbs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var historyFile: URL {
        appSupport.appendingPathComponent("history.json")
    }
}

enum DateGroup: String, CaseIterable {
    case today = "今日"
    case yesterday = "昨日"
    case thisWeek = "今週"
    case thisMonth = "今月"
    case earlier = "それ以前"

    static func group(for date: Date, now: Date = Date()) -> DateGroup {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return .today }
        if cal.isDateInYesterday(date) { return .yesterday }
        if cal.isDate(date, equalTo: now, toGranularity: .weekOfYear) { return .thisWeek }
        if cal.isDate(date, equalTo: now, toGranularity: .month) { return .thisMonth }
        return .earlier
    }
}

func formatDuration(_ seconds: Int?) -> String? {
    guard let s = seconds, s > 0 else { return nil }
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
    return String(format: "%d:%02d", m, sec)
}
