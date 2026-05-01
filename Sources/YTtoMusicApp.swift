import SwiftUI

@main
struct YTtoMusicApp: App {
    @StateObject private var downloader = DownloadManager()
    @StateObject private var history = HistoryStore()

    var body: some Scene {
        Window("YT to Music", id: "main") {
            ContentView()
                .environmentObject(downloader)
                .environmentObject(history)
                .frame(minWidth: 880, minHeight: 580)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1040, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新規ダウンロード") {
                    NotificationCenter.default.post(name: .newDownload, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .pasteboard) {
                Button("URL をペーストして開始") {
                    NotificationCenter.default.post(name: .pasteAndStart, object: nil)
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let newDownload = Notification.Name("YTtoMusic.newDownload")
    static let pasteAndStart = Notification.Name("YTtoMusic.pasteAndStart")
}
