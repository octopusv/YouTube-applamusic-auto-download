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

enum DownloadKind: String, Codable, Hashable {
    case appleMusic
    case file
}

enum CookieBrowser: String, CaseIterable, Identifiable, Codable {
    case none, safari, chrome, firefox, edge, brave

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:    return "使わない"
        case .safari:  return "Safari"
        case .chrome:  return "Google Chrome"
        case .firefox: return "Firefox"
        case .edge:    return "Microsoft Edge"
        case .brave:   return "Brave"
        }
    }

    var ytDlpArgs: [String] {
        switch self {
        case .none: return []
        default:    return ["--cookies-from-browser", rawValue]
        }
    }
}

enum FileFormat: String, CaseIterable, Codable, Identifiable, Hashable {
    case mp4Best   = "mp4-best"
    case mp4_1080  = "mp4-1080"
    case mp4_720   = "mp4-720"
    case mp4_480   = "mp4-480"
    case mp3       = "mp3"
    case m4a       = "m4a"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mp4Best:  return "MP4 最高画質"
        case .mp4_1080: return "MP4 1080p"
        case .mp4_720:  return "MP4 720p"
        case .mp4_480:  return "MP4 480p"
        case .mp3:      return "MP3 (高音質)"
        case .m4a:      return "M4A (高音質)"
        }
    }

    var symbol: String {
        switch self {
        case .mp4Best, .mp4_1080, .mp4_720, .mp4_480: return "film"
        case .mp3, .m4a: return "music.note"
        }
    }

    var fileExtension: String {
        switch self {
        case .mp4Best, .mp4_1080, .mp4_720, .mp4_480: return "mp4"
        case .mp3: return "mp3"
        case .m4a: return "m4a"
        }
    }

    var ytDlpArgs: [String] {
        switch self {
        case .mp4Best:
            return ["-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
                    "--merge-output-format", "mp4"]
        case .mp4_1080:
            return ["-f", "bestvideo[ext=mp4][height<=1080]+bestaudio[ext=m4a]/best[ext=mp4][height<=1080]/best",
                    "--merge-output-format", "mp4"]
        case .mp4_720:
            return ["-f", "bestvideo[ext=mp4][height<=720]+bestaudio[ext=m4a]/best[ext=mp4][height<=720]/best",
                    "--merge-output-format", "mp4"]
        case .mp4_480:
            return ["-f", "bestvideo[ext=mp4][height<=480]+bestaudio[ext=m4a]/best[ext=mp4][height<=480]/best",
                    "--merge-output-format", "mp4"]
        case .mp3:
            return ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
        case .m4a:
            return ["-x", "--audio-format", "m4a", "--audio-quality", "0"]
        }
    }
}

struct HistoryItem: Codable, Identifiable, Hashable {
    let id: UUID
    let kind: DownloadKind
    let url: String
    let title: String
    let artist: String
    let album: String
    let savedAt: Date
    let thumbnailPath: String?
    let savedFilePath: String?
    let formatLabel: String?

    init(id: UUID,
         kind: DownloadKind = .appleMusic,
         url: String,
         title: String,
         artist: String,
         album: String,
         savedAt: Date,
         thumbnailPath: String?,
         savedFilePath: String?,
         formatLabel: String? = nil) {
        self.id = id
        self.kind = kind
        self.url = url
        self.title = title
        self.artist = artist
        self.album = album
        self.savedAt = savedAt
        self.thumbnailPath = thumbnailPath
        self.savedFilePath = savedFilePath
        self.formatLabel = formatLabel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = (try? c.decode(DownloadKind.self, forKey: .kind)) ?? .appleMusic
        url = try c.decode(String.self, forKey: .url)
        title = try c.decode(String.self, forKey: .title)
        artist = (try? c.decode(String.self, forKey: .artist)) ?? ""
        album = (try? c.decode(String.self, forKey: .album)) ?? ""
        savedAt = try c.decode(Date.self, forKey: .savedAt)
        thumbnailPath = try c.decodeIfPresent(String.self, forKey: .thumbnailPath)
        savedFilePath = try c.decodeIfPresent(String.self, forKey: .savedFilePath)
        formatLabel = try c.decodeIfPresent(String.self, forKey: .formatLabel)
    }
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

enum FileDownloadState: Equatable {
    case idle
    case working(stage: DownloadStage, status: String)
    case saved(HistoryItem)
    case error(String)
}

enum PlaylistDownloadState: Equatable {
    case idle
    case fetching
    case downloading(current: Int, total: Int, currentTitle: String, currentProgress: Double)
    case finished(succeeded: Int, failed: [String])
    case cancelled(succeeded: Int, total: Int)
    case error(String)
}

enum SidebarSelection: Hashable {
    case appleMusicDownload
    case fileDownload
    case playlistDownload
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
