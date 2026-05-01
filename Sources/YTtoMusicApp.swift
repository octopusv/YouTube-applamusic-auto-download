import SwiftUI

@main
struct YTtoMusicApp: App {
    @StateObject private var downloader = DownloadManager()
    @StateObject private var fileDownloader = FileDownloadManager()
    @StateObject private var playlistManager = PlaylistDownloadManager()
    @StateObject private var history = HistoryStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var updater = YtDlpUpdater()
    @StateObject private var appUpdater = AppUpdater()

    var body: some Scene {
        Window("YT to Music", id: "main") {
            ContentView()
                .environmentObject(downloader)
                .environmentObject(fileDownloader)
                .environmentObject(playlistManager)
                .environmentObject(history)
                .environmentObject(settings)
                .environmentObject(updater)
                .frame(minWidth: 880, minHeight: 580)
                .task {
                    updater.checkOnLaunch()
                    Task.detached { TempCleanup.sweepStaleSessions() }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1040, height: 680)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("アップデートを確認…") {
                    appUpdater.checkForUpdates()
                }
                .disabled(!appUpdater.canCheckForUpdates)
            }
            CommandGroup(replacing: .newItem) {
                Button("Apple Music に追加") {
                    NotificationCenter.default.post(name: .newDownload, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                Button("ファイルとして保存") {
                    NotificationCenter.default.post(name: .newFileDownload, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("プレイリスト → アルバム") {
                    NotificationCenter.default.post(name: .newPlaylist, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
            }
            CommandGroup(after: .pasteboard) {
                Button("URL をペーストして開始") {
                    NotificationCenter.default.post(name: .pasteAndStart, object: nil)
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
            CommandMenu("ミュージック") {
                Button("クラウドミュージックライブラリを更新") {
                    try? MusicLibrary.refreshCloudLibrary()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("ミュージック.app を開く") {
                    MusicLibrary.openMusicApp()
                }
                Button("自動取り込みフォルダを Finder で表示") {
                    MusicLibrary.revealAutoAddFolder()
                }
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
    static let newPlaylist = Notification.Name("YTtoMusic.newPlaylist")
    static let pasteAndStart = Notification.Name("YTtoMusic.pasteAndStart")
}
