import Foundation
import Combine

/// Owns the user's keyword list and persists it as JSON in Application Support.
///
/// On first launch the bundled starter glossary (`Resources/keywords.json`) is
/// copied into the user's own editable file so changes survive app updates.
final class Glossary: ObservableObject {

    @Published private(set) var keywords: [Keyword] = []

    /// `~/Library/Application Support/Lexed/keywords.json`
    private let fileURL: URL

    init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Lexed", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        fileURL = support.appendingPathComponent("keywords.json")
        load()
    }

    // MARK: - Loading / saving

    func load() {
        if let user = decode(from: fileURL) {
            keywords = sorted(user)
            return
        }
        // First run (or corrupted file): seed from the bundled starter set.
        if let bundled = Bundle.module.url(forResource: "keywords", withExtension: "json"),
           let seed = decode(from: bundled) {
            keywords = sorted(seed)
            save()
        } else {
            keywords = []
        }
    }

    private func decode(from url: URL) -> [Keyword]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Keyword].self, from: data)
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(keywords) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func sorted(_ list: [Keyword]) -> [Keyword] {
        list.sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
    }

    // MARK: - Mutations

    func add(_ keyword: Keyword) {
        keywords = sorted(keywords + [keyword])
        save()
    }

    func update(_ keyword: Keyword) {
        guard let i = keywords.firstIndex(where: { $0.id == keyword.id }) else { return }
        keywords[i] = keyword
        keywords = sorted(keywords)
        save()
    }

    func remove(_ keyword: Keyword) {
        keywords.removeAll { $0.id == keyword.id }
        save()
    }

    func remove(at offsets: IndexSet) {
        keywords.remove(atOffsets: offsets)
        save()
    }

    /// Replace the whole glossary, e.g. after importing a file.
    func replaceAll(with list: [Keyword]) {
        keywords = sorted(list)
        save()
    }

    // MARK: - Import / export

    /// Merge keywords from an external JSON file. Entries whose term already
    /// exists (case-insensitive) are skipped. Returns the number imported.
    @discardableResult
    func importJSON(from url: URL) throws -> Int {
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

        guard let incoming = decode(from: url) else {
            throw GlossaryError.unreadable
        }
        let existing = Set(keywords.map { $0.term.lowercased() })
        let fresh = incoming.filter { !existing.contains($0.term.lowercased()) }
        guard !fresh.isEmpty else { return 0 }
        keywords = sorted(keywords + fresh)
        save()
        return fresh.count
    }

    func exportJSON(to url: URL) throws {
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(keywords)
        try data.write(to: url, options: .atomic)
    }

    enum GlossaryError: LocalizedError {
        case unreadable
        var errorDescription: String? {
            switch self {
            case .unreadable: return "That file isn't a valid Lexed glossary (expected a JSON array of keywords)."
            }
        }
    }
}
