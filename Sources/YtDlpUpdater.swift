import Foundation
import Combine

@MainActor
final class YtDlpUpdater: ObservableObject {
    enum UpdateState: Equatable {
        case unknown
        case checking
        case current(version: String)
        case available(current: String, latest: String)
        case updating(output: String)
        case justUpdated(version: String)
        case failed(String)
    }

    @Published var state: UpdateState = .unknown

    private var hasCheckedThisLaunch = false

    func checkOnLaunch() {
        guard !hasCheckedThisLaunch else { return }
        hasCheckedThisLaunch = true
        Task { await check() }
    }

    func check() async {
        guard let ytdlp = Tools.ytdlp else {
            state = .failed("yt-dlp が見つかりません")
            return
        }
        state = .checking

        guard let current = await runVersion(ytdlp: ytdlp) else {
            state = .failed("yt-dlp のバージョン取得に失敗")
            return
        }

        guard let latest = await fetchLatestVersion() else {
            state = .current(version: current)
            return
        }

        if compareVersions(current, latest) < 0 {
            state = .available(current: current, latest: latest)
        } else {
            state = .current(version: current)
        }
    }

    func update() async {
        let brew = Tools.find("brew")
        guard let brew else {
            state = .failed("Homebrew が見つかりません。手動で `brew upgrade yt-dlp` を実行してください")
            return
        }

        state = .updating(output: "")

        let p = Process()
        p.executableURL = URL(fileURLWithPath: brew)
        p.arguments = ["upgrade", "yt-dlp"]

        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe

        let buffer = OutputBuffer()

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            let snapshot = buffer.append(s)
            Task { @MainActor [weak self] in
                if case .updating = self?.state {
                    self?.state = .updating(output: String(snapshot.suffix(800)))
                }
            }
        }

        do {
            try p.run()
        } catch {
            state = .failed("更新の起動に失敗: \(error.localizedDescription)")
            return
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().async {
                p.waitUntilExit()
                cont.resume()
            }
        }
        pipe.fileHandleForReading.readabilityHandler = nil

        if p.terminationStatus == 0 {
            if let ytdlp = Tools.ytdlp, let v = await runVersion(ytdlp: ytdlp) {
                state = .justUpdated(version: v)
            } else {
                state = .justUpdated(version: "?")
            }
        } else {
            let tail = String(buffer.snapshot().suffix(400))
            state = .failed("更新に失敗 (exit \(p.terminationStatus))\n\(tail)")
        }
    }

    private final class OutputBuffer: @unchecked Sendable {
        private var value = ""
        private let lock = NSLock()
        func append(_ s: String) -> String {
            lock.lock(); defer { lock.unlock() }
            value += s
            return value
        }
        func snapshot() -> String {
            lock.lock(); defer { lock.unlock() }
            return value
        }
    }

    private func runVersion(ytdlp: String) async -> String? {
        await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            DispatchQueue.global().async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: ytdlp)
                p.arguments = ["--version"]
                let pipe = Pipe()
                p.standardOutput = pipe
                p.standardError = Pipe()
                do {
                    try p.run()
                    p.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let s = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    cont.resume(returning: s?.isEmpty == false ? s : nil)
                } catch {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    private func fetchLatestVersion() async -> String? {
        let url = URL(string: "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest")!
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("YTtoMusic", forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tag = json["tag_name"] as? String {
                return tag
            }
        } catch {
            return nil
        }
        return nil
    }

    private func compareVersions(_ a: String, _ b: String) -> Int {
        let normalize: (String) -> [Int] = { s in
            s.split { !$0.isNumber && $0 != "." }
                .joined(separator: ".")
                .split(separator: ".")
                .compactMap { Int($0) }
        }
        let ap = normalize(a)
        let bp = normalize(b)
        let n = max(ap.count, bp.count)
        for i in 0..<n {
            let ai = i < ap.count ? ap[i] : 0
            let bi = i < bp.count ? bp[i] : 0
            if ai != bi { return ai < bi ? -1 : 1 }
        }
        return 0
    }
}
