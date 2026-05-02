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
        if let path = item.thumbnailPath,
           Sanitization.isPath(path, within: AppPaths.thumbsDir) {
            try? FileManager.default.removeItem(atPath: path)
        }
        items.removeAll { $0.id == item.id }
        save()
    }

    func update(_ updated: HistoryItem) {
        guard let idx = items.firstIndex(where: { $0.id == updated.id }) else { return }
        let old = items[idx]
        if let oldThumb = old.thumbnailPath,
           oldThumb != updated.thumbnailPath,
           Sanitization.isPath(oldThumb, within: AppPaths.thumbsDir) {
            try? FileManager.default.removeItem(atPath: oldThumb)
        }
        items[idx] = updated
        save()
    }

    func item(id: UUID) -> HistoryItem? {
        items.first { $0.id == id }
    }

    /// Apple Music 取り込み済みでアルバム名を持つ曲だけを、アルバム名で束ねて返す。
    /// アルバム名昇順、各アルバム内は savedAt 昇順（取り込み順 = 元のトラック順を温存）。
    var albums: [AlbumGroup] {
        let appleMusicWithAlbum = items.filter { $0.kind == .appleMusic && !$0.album.isEmpty }
        let grouped = Dictionary(grouping: appleMusicWithAlbum) { $0.album }
        return grouped
            .map { name, items -> AlbumGroup in
                let sorted = items.sorted { $0.savedAt < $1.savedAt }
                return AlbumGroup(
                    name: name,
                    albumArtist: sorted.first?.artist ?? "",
                    items: sorted
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func album(named name: String) -> AlbumGroup? {
        albums.first { $0.name == name }
    }

    /// 同じ id を持つ既存アイテムを置き換える（複数件の一括反映）。
    func bulkUpdate(_ updates: [HistoryItem]) {
        let map = Dictionary(uniqueKeysWithValues: updates.map { ($0.id, $0) })
        items = items.map { map[$0.id] ?? $0 }
        save()
    }

    nonisolated static func persistThumbnail(from src: String?) -> String? {
        guard let src, Sanitization.isLikelyImage(at: src) else { return nil }
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
