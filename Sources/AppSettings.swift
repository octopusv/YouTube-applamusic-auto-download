import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let folder = "defaultDownloadFolder"
        static let format = "defaultFormat"
        static let rememberLastFormat = "rememberLastFormat"
    }

    @Published var defaultFolder: URL {
        didSet { UserDefaults.standard.set(defaultFolder.path, forKey: Keys.folder) }
    }
    @Published var defaultFormat: FileFormat {
        didSet { UserDefaults.standard.set(defaultFormat.rawValue, forKey: Keys.format) }
    }
    @Published var rememberLastFormat: Bool {
        didSet { UserDefaults.standard.set(rememberLastFormat, forKey: Keys.rememberLastFormat) }
    }

    init() {
        let path = UserDefaults.standard.string(forKey: Keys.folder) ?? ""
        if !path.isEmpty, FileManager.default.fileExists(atPath: path) {
            self.defaultFolder = URL(fileURLWithPath: path)
        } else {
            self.defaultFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        }

        let fmtRaw = UserDefaults.standard.string(forKey: Keys.format) ?? FileFormat.mp4_1080.rawValue
        self.defaultFormat = FileFormat(rawValue: fmtRaw) ?? .mp4_1080

        if UserDefaults.standard.object(forKey: Keys.rememberLastFormat) == nil {
            self.rememberLastFormat = true
        } else {
            self.rememberLastFormat = UserDefaults.standard.bool(forKey: Keys.rememberLastFormat)
        }
    }
}
