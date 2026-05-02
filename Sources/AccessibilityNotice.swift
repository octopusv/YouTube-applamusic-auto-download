import Foundation
import AppKit
import Combine

/// Sparkle で更新されると署名ハッシュが変わってアクセシビリティ権限が
/// リセットされる（ad-hoc 署名アプリの宿命）。
/// 起動時にバージョン変化を検知して、案内バナーを 1 回だけ出す。
@MainActor
final class AccessibilityNotice: ObservableObject {
    @Published var isVisible: Bool = false

    private let key = "AccessibilityNoticeLastSeenVersion"

    init() {
        let current = Self.currentVersion
        let lastSeen = UserDefaults.standard.string(forKey: key)
        // 初回インストール (lastSeen == nil) でも、バージョンアップでも、
        // どちらでもアクセシビリティ権限が必要になるため案内する。
        if lastSeen != current {
            isVisible = true
        }
    }

    /// バナーを閉じて、現在のバージョンを記録する（次の更新まで再表示しない）。
    func dismiss() {
        UserDefaults.standard.set(Self.currentVersion, forKey: key)
        isVisible = false
    }

    /// システム設定の「プライバシーとセキュリティ → アクセシビリティ」を開く。
    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private static var currentVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return v ?? "0"
    }
}
