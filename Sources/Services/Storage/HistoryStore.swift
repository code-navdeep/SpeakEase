import Foundation
import Observation

/// Observable rolling history of transcriptions, persisted as one JSON file in
/// Application Support (excluded from backups — transcripts can contain
/// sensitive dictated content and shouldn't ride along in iCloud/Time Machine).
@MainActor
@Observable
final class HistoryStore {
    private let fileURL: URL
    private let maxItems = 100

    private(set) var items: [HistoryItem]

    init(directory: URL = HistoryStore.defaultDirectory()) {
        self.fileURL = directory.appendingPathComponent("history.json")
        HistoryStore.excludeFromBackup(directory)
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            self.items = decoded
        } else {
            self.items = []
        }
    }

    func add(text: String, source: TranscriptionSource, filename: String? = nil) {
        add(item: HistoryItem(text: text, source: source, filename: filename))
    }

    func add(item: HistoryItem) {
        items.insert(item, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        persist()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }

    /// Drop items older than `expiry`'s retention window. No-op for `.never`.
    func prune(olderThan expiry: HistoryExpiry) {
        guard let days = expiry.days,
              let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }
        let before = items.count
        items.removeAll { $0.date < cutoff }
        if items.count != before { persist() }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Storage location

    static func defaultDirectory() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("SpeakEase", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func excludeFromBackup(_ directory: URL) {
        var directory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
    }
}
