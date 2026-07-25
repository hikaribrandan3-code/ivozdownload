import Foundation

// MARK: - Persistence helper

enum AppStorageDirectory {
    static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HikariYaps", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func load<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        let url = url.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to filename: String) {
        let url = url.appendingPathComponent(filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// MARK: - Vocabulary

struct VocabEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var word: String
    var dateAdded = Date()
}

/// Custom words and names that bias Whisper's decoding via prompt conditioning.
@MainActor
final class VocabularyStore: ObservableObject {
    @Published private(set) var entries: [VocabEntry] = [] {
        didSet { AppStorageDirectory.save(entries, to: "vocabulary.json") }
    }

    init() {
        entries = AppStorageDirectory.load([VocabEntry].self, from: "vocabulary.json") ?? []
    }

    var words: [String] { entries.map(\.word) }

    func add(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !entries.contains(where: { $0.word.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        entries.insert(VocabEntry(word: trimmed), at: 0)
    }

    func remove(_ entry: VocabEntry) {
        entries.removeAll { $0.id == entry.id }
    }
}

// MARK: - Snippets

struct Snippet: Identifiable, Codable, Hashable {
    var id = UUID()
    var trigger: String
    var content: String
    var dateAdded = Date()
}

/// Reusable text blocks. Saying a snippet's trigger phrase injects its content.
@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var snippets: [Snippet] = [] {
        didSet { AppStorageDirectory.save(snippets, to: "snippets.json") }
    }

    init() {
        snippets = AppStorageDirectory.load([Snippet].self, from: "snippets.json") ?? []
    }

    func add(trigger: String, content: String) {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrigger.isEmpty, !trimmedContent.isEmpty else { return }
        snippets.insert(Snippet(trigger: trimmedTrigger, content: trimmedContent), at: 0)
    }

    func update(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
        }
    }

    func remove(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
    }

    /// Replaces spoken trigger phrases with snippet content. A trigger spoken
    /// as the entire utterance replaces the whole text; a trigger spoken
    /// mid-sentence is replaced inline.
    func expand(_ text: String) -> String {
        var result = text
        for snippet in snippets {
            let normalizedTrigger = Self.normalize(snippet.trigger)
            guard !normalizedTrigger.isEmpty else { continue }

            if Self.normalize(result) == normalizedTrigger {
                return snippet.content
            }

            // Inline: build a pattern tolerant of punctuation between words.
            let words = normalizedTrigger.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }
            guard !words.isEmpty else { continue }
            let pattern = "\\b" + words.joined(separator: "[\\s,]+") + "\\b[,.]?"
            result = result.replacing(pattern: pattern, with: NSRegularExpression.escapedTemplate(for: snippet.content), options: [.caseInsensitive])
        }
        return result
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined()
            .replacing(pattern: #"\s+"#, with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
