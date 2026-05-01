import Foundation
import Combine

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [HistoryItem] = []
    @Published var searchText: String = ""

    init() { load() }

    var filtered: [HistoryItem] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { item in
            item.title.lowercased().contains(q) ||
            item.artist.lowercased().contains(q) ||
            item.album.lowercased().contains(q)
        }
    }

    var grouped: [(group: DateGroup, items: [HistoryItem])] {
        let now = Date()
        let dict = Dictionary(grouping: filtered) { DateGroup.group(for: $0.savedAt, now: now) }
        return DateGroup.allCases.compactMap { g in
            guard let arr = dict[g], !arr.isEmpty else { return nil }
            return (g, arr.sorted { $0.savedAt > $1.savedAt })
        }
    }

    func add(_ item: HistoryItem) {
        items.insert(item, at: 0)
        save()
    }

    func delete(_ item: HistoryItem) {
        if let path = item.thumbnailPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        items.removeAll { $0.id == item.id }
        save()
    }

    func item(id: UUID) -> HistoryItem? {
        items.first { $0.id == id }
    }

    nonisolated static func persistThumbnail(from src: String?) -> String? {
        guard let src else { return nil }
        let dest = AppPaths.thumbsDir.appendingPathComponent("\(UUID().uuidString).jpg")
        do {
            try FileManager.default.copyItem(atPath: src, toPath: dest.path)
            return dest.path
        } catch {
            return nil
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: AppPaths.historyFile) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([HistoryItem].self, from: data) {
            items = decoded
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: AppPaths.historyFile, options: .atomic)
    }
}
