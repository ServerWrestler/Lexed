import Foundation

/// One keyword occurrence inside a transcript string.
struct KeywordMatch: Hashable {
    /// UTF-16 range (NSRange) of the hit within the source string.
    let range: NSRange
    let keyword: Keyword
}

/// Compiles the glossary into a single case-insensitive regular expression and
/// finds every keyword occurrence in a transcript.
///
/// Using one combined alternation (`\b(term a|term b|…)\b`) keeps matching fast
/// even for large glossaries: the work is one pass over the text regardless of
/// how many keywords there are.
final class KeywordIndex {

    private var regex: NSRegularExpression?
    /// Lowercased spoken form -> keyword, for resolving which alternative matched.
    private var formToKeyword: [String: Keyword] = [:]

    /// Rebuild the matcher. Call whenever the glossary changes (cheap; do not
    /// call on every transcript update).
    func rebuild(with keywords: [Keyword]) {
        formToKeyword.removeAll(keepingCapacity: true)

        // Collect (form, keyword) pairs. Longer forms first so that multi-word
        // terms win over any shorter term they contain.
        var forms: [String] = []
        for keyword in keywords {
            for form in keyword.matchForms {
                let key = form.lowercased()
                if formToKeyword[key] == nil {
                    formToKeyword[key] = keyword
                    forms.append(form)
                }
            }
        }
        forms.sort { $0.count > $1.count }

        guard !forms.isEmpty else {
            regex = nil
            return
        }

        let pattern = forms.map(Self.pattern(for:)).joined(separator: "|")
        regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    /// All keyword hits in `text`, left to right, with overlaps removed
    /// (longest / earliest match wins).
    func matches(in text: String) -> [KeywordMatch] {
        guard let regex, !text.isEmpty else { return [] }
        let ns = text as NSString
        let whole = NSRange(location: 0, length: ns.length)

        var result: [KeywordMatch] = []
        var claimed: [NSRange] = []

        for m in regex.matches(in: text, options: [], range: whole) {
            let hit = ns.substring(with: m.range).lowercased()
            guard let keyword = formToKeyword[hit] else { continue }
            if claimed.contains(where: { NSIntersectionRange($0, m.range).length > 0 }) {
                continue // overlaps an earlier (longer) match
            }
            claimed.append(m.range)
            result.append(KeywordMatch(range: m.range, keyword: keyword))
        }
        return result
    }

    /// Wrap a literal spoken form in word boundaries, but only where the edge
    /// character is alphanumeric (so terms like "C++" or ".NET" still match).
    private static func pattern(for form: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: form)
        let lead = form.first.map(isWordEdge) ?? false ? "\\b" : ""
        let trail = form.last.map(isWordEdge) ?? false ? "\\b" : ""
        return lead + escaped + trail
    }

    private static func isWordEdge(_ c: Character) -> Bool {
        c.isLetter || c.isNumber
    }
}
