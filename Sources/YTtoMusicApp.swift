import SwiftUI

@main
struct YTtoMusicApp: App {
    @StateObject private var downloader = DownloadManager()
    @StateObject private var fileDownloader = FileDownloadManager()
    @StateObject private var history = HistoryStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        Window("YT to Music", id: "main") {
            ContentView()
                .environmentObject(downloader)
                .environmentObject(fileDownloader)
                .environmentObject(history)
                .environmentObject(settings)
                .frame(minWidth: 880, minHeight: 580)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1040, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Apple Music に追加") {
                    NotificationCenter.default.post(name: .newDownload, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                Button("ファイルとして保存") {
                    NotificationCenter.default.post(name: .newFileDownload, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandGroup(after: .pasteboard) {
                Button("URL をペーストして開始") {
                    NotificationCenter.default.post(name: .pasteAndStart, object: nil)
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

extension Notification.Name {
    static let newDownload = Notification.Name("YTtoMusic.newDownload")
    static let newFileDownload = Notification.Name("YTtoMusic.newFileDownload")
    static let pasteAndStart = Notification.Name("YTtoMusic.pasteAndStart")
}
