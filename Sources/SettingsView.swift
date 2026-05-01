import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("一般", systemImage: "gearshape") }
            aboutTab
                .tabItem { Label("情報", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 320)
    }

    private var generalTab: some View {
        Form {
            Section("ファイルとして保存") {
                LabeledContent("デフォルトの保存先") {
                    HStack {
                        Text(settings.defaultFolder.path)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("変更…") {
                            pickFolder()
                        }
                    }
                }
                Picker("デフォルトのフォーマット", selection: $settings.defaultFormat) {
                    ForEach(FileFormat.allCases) { fmt in
                        Label(fmt.displayName, systemImage: fmt.symbol).tag(fmt)
                    }
                }
                Toggle("最後に使ったフォーマットを記憶", isOn: $settings.rememberLastFormat)
            }

            Section {
                Picker("ブラウザの Cookie を使う", selection: $settings.cookieBrowser) {
                    ForEach(CookieBrowser.allCases) { b in
                        Text(b.displayName).tag(b)
                    }
                }
            } header: {
                Text("YouTube 認証")
            } footer: {
                Text("「Sign in to confirm you're not a bot」エラーが出る場合、ログイン中のブラウザを選んでください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var aboutTab: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("YTtoMusic").font(.title2.weight(.semibold))
            Text("YouTube から Apple Music へ、または任意のフォーマットで保存。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Link("GitHub", destination: URL(string: "https://github.com/octopusv/YouTube-applamusic-auto-download")!)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.defaultFolder
        panel.prompt = "選択"
        if panel.runModal() == .OK, let url = panel.url {
            settings.defaultFolder = url
        }
    }
}
