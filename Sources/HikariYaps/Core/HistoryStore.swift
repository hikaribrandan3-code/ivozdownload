import Foundation
import AppKit

struct HistoryEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var text: String
    var rawText: String
    var wordCount: Int
    var duration: TimeInterval
    var appName: String?
}

struct DictationStats {
    var wordsToday = 0
    var sessionsToday = 0
    var averageWPM = 0
    var allTimeWords = 0
    var minutesSaved = 0
    /// Words per weekday for the current week, Monday-first.
    var weeklyWords: [Int] = Array(repeating: 0, count: 7)
}

/// Transcription log, persisted as JSON in Application Support.
///
/// Disk writes are debounced (coalesced onto a background queue, fired ~2s
/// after the last change) so rapid dictations don't block the main thread
/// serializing the whole history on every single entry. A save is also
/// forced on app termination so nothing is lost on quit. Stats are cached
/// and only recomputed when entries actually change — HomeView reads
/// `stats` on every render, and the old version re-scanned the entire
/// history array twice per read.
@MainActor
final class HistoryStore: ObservableObject {
    private static let maxEntries = 2000
    private static let saveDebounce: TimeInterval = 2.0

    @Published private(set) var entries: [HistoryEntry] = [] {
        didSet {
            statsCache = nil
            scheduleSave()
        }
    }

    private var saveWorkItem: DispatchWorkItem?
    private var statsCache: DictationStats?

    init() {
        entries = AppStorageDirectory.load([HistoryEntry].self, from: "history.json") ?? []
        NotificationCenter.default.addObserver(
            self, selector: #selector(flushSave),
            name: NSApplication.willTerminateNotification, object: nil
        )
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = entries
        let item = DispatchWorkItem {
            AppStorageDirectory.save(snapshot, to: "history.json")
        }
        saveWorkItem = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + Self.saveDebounce, execute: item)
    }

    @objc private func flushSave() {
        saveWorkItem?.cancel()
        AppStorageDirectory.save(entries, to: "history.json")
    }

    func add(text: String, rawText: String, duration: TimeInterval, appName: String?) {
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        let entry = HistoryEntry(
            date: Date(),
            text: text,
            rawText: rawText,
            wordCount: words,
            duration: duration,
            appName: appName
        )
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
    }

    func remove(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func clear() {
        entries.removeAll()
    }

    // MARK: - Stats

    var stats: DictationStats {
        if let statsCache { return statsCache }
        let computed = computeStats()
        statsCache = computed
        return computed
    }

    private func computeStats() -> DictationStats {
        var stats = DictationStats()
        let calendar = Calendar.current
        let now = Date()

        var totalWords = 0
        var totalDuration: TimeInterval = 0

        for entry in entries {
            totalWords += entry.wordCount
            totalDuration += entry.duration
            if calendar.isDateInToday(entry.date) {
                stats.wordsToday += entry.wordCount
                stats.sessionsToday += 1
            }
        }

        stats.allTimeWords = totalWords
        if totalDuration > 1 {
            stats.averageWPM = Int((Double(totalWords) / totalDuration * 60).rounded())
        }
        // Speaking ≈150 wpm vs typing ≈40 wpm.
        stats.minutesSaved = Int((Double(totalWords) * (1.0 / 40.0 - 1.0 / 150.0)).rounded())

        // Current week, Monday-first.
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2
        if let weekStart = weekCalendar.dateInterval(of: .weekOfYear, for: now)?.start {
            for entry in entries {
                guard entry.date >= weekStart else { break }
                let dayIndex = weekCalendar.dateComponents([.day], from: weekStart, to: entry.date).day ?? 0
                if (0..<7).contains(dayIndex) {
                    stats.weeklyWords[dayIndex] += entry.wordCount
                }
            }
        }
        return stats
    }

    // MARK: - Search & grouping

    func filtered(query: String) -> [HistoryEntry] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return entries }
        return entries.filter {
            $0.text.localizedCaseInsensitiveContains(query) ||
            ($0.appName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    /// Groups entries by calendar day, newest day first.
    func grouped(query: String) -> [(day: Date, entries: [HistoryEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filtered(query: query)) {
            calendar.startOfDay(for: $0.date)
        }
        return groups
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, entries: $0.value) }
    }

    // MARK: - Export

    func exportText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return entries.reversed().map { entry in
            "[\(formatter.string(from: entry.date))]\(entry.appName.map { " (\($0))" } ?? "")\n\(entry.text)\n"
        }.joined(separator: "\n")
    }

    func exportJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(entries)
    }
}
