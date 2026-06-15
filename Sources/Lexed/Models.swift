import Foundation

/// A single glossary entry: the term the user wants to catch in conversation,
/// plus the definition Lexed should surface when it hears it.
struct Keyword: Identifiable, Codable, Hashable {
    var id: UUID
    /// The canonical term, e.g. "SLA" or "Kubernetes".
    var term: String
    /// Plain-language definition shown to the user.
    var definition: String
    /// Alternate spellings / spoken forms that should also match, e.g.
    /// ["service level agreement"] for "SLA", or ["k8s"] for "Kubernetes".
    var aliases: [String]
    /// Optional grouping label, e.g. "DevOps", "Finance", "Legal".
    var category: String?
    /// Optional reference link for "learn more".
    var source: String?

    init(
        id: UUID = UUID(),
        term: String,
        definition: String,
        aliases: [String] = [],
        category: String? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.term = term
        self.definition = definition
        self.aliases = aliases
        self.category = category
        self.source = source
    }

    /// Every spoken form Lexed should listen for (canonical term + aliases),
    /// de-duplicated and stripped of blanks.
    var matchForms: [String] {
        var forms = [term] + aliases
        forms = forms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        // Stable de-dup, case-insensitive.
        var seen = Set<String>()
        return forms.filter { seen.insert($0.lowercased()).inserted }
    }

    enum CodingKeys: String, CodingKey {
        case id, term, definition, aliases, category, source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // `id` is optional in authored JSON; mint one when it's absent.
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        term = try c.decode(String.self, forKey: .term)
        definition = try c.decode(String.self, forKey: .definition)
        aliases = (try? c.decode([String].self, forKey: .aliases)) ?? []
        category = try? c.decodeIfPresent(String.self, forKey: .category)
        source = try? c.decodeIfPresent(String.self, forKey: .source)
    }
}

/// A keyword that has actually been heard during the current session, with
/// when it was last spoken and how many times it has come up.
struct DetectedTerm: Identifiable, Hashable {
    let keyword: Keyword
    var firstHeard: Date
    var lastHeard: Date
    var count: Int

    var id: Keyword.ID { keyword.id }
}
