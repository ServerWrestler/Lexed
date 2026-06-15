import Foundation
import SwiftUI
import Combine

/// The session brain: subscribes to the live transcript and the glossary,
/// produces a highlighted `AttributedString`, and tracks which keywords have
/// been heard.
@MainActor
final class LexedViewModel: ObservableObject {

    let speech = SpeechRecognizer()
    let glossary: Glossary

    /// Transcript with keyword hits highlighted and linked (`lexed://term/<uuid>`).
    @Published private(set) var highlighted = AttributedString()
    /// Keywords heard this session, most-recent first.
    @Published private(set) var detected: [DetectedTerm] = []
    /// The keyword the user most recently clicked or that was just heard — drives
    /// the "current definition" card.
    @Published var focusedKeywordID: Keyword.ID?

    private let index = KeywordIndex()
    private var detectedByID: [Keyword.ID: DetectedTerm] = [:]
    private var cancellables = Set<AnyCancellable>()

    /// Wall-clock provider, injectable for tests.
    private let now: () -> Date

    init(glossary: Glossary = Glossary(), now: @escaping () -> Date = Date.init) {
        self.glossary = glossary
        self.now = now

        index.rebuild(with: glossary.keywords)

        // Rebuild the matcher only when the glossary itself changes.
        glossary.$keywords
            .sink { [weak self] keywords in
                guard let self else { return }
                self.index.rebuild(with: keywords)
                self.rebuildHighlight()
            }
            .store(in: &cancellables)

        // Re-highlight whenever the transcript advances (committed or live).
        speech.$finalizedText
            .combineLatest(speech.$volatileText)
            .sink { [weak self] _, _ in self?.rebuildHighlight() }
            .store(in: &cancellables)
    }

    // MARK: - Session controls

    func toggleListening() { speech.toggle() }

    func clearSession() {
        speech.clearTranscript()
        detected = []
        detectedByID = [:]
        focusedKeywordID = nil
        rebuildHighlight()
    }

    func keyword(for id: Keyword.ID) -> Keyword? {
        glossary.keywords.first { $0.id == id }
    }

    // MARK: - Highlighting

    private func rebuildHighlight() {
        let text = speech.fullText
        let matches = index.matches(in: text)
        highlighted = Self.attributed(text, matches: matches)
        recordDetections(matches)
    }

    /// Build the styled transcript: each keyword hit gets a soft highlight,
    /// bold weight, and a tappable `lexed://` link.
    private static func attributed(_ text: String, matches: [KeywordMatch]) -> AttributedString {
        var attr = AttributedString(text)
        for match in matches {
            guard let range = Range(match.range, in: attr) else { continue }
            attr[range].backgroundColor = Color.accentColor.opacity(0.18)
            attr[range].foregroundColor = .primary
            attr[range].inlinePresentationIntent = .stronglyEmphasized
            attr[range].underlineStyle = .single
            attr[range].link = URL(string: "lexed://term/\(match.keyword.id.uuidString)")
        }
        return attr
    }

    // MARK: - Detection history

    private func recordDetections(_ matches: [KeywordMatch]) {
        guard !matches.isEmpty else { return }
        let stamp = now()

        // Count occurrences in the current full transcript so a term repeated
        // across the meeting reflects its true tally.
        var counts: [Keyword.ID: (keyword: Keyword, count: Int)] = [:]
        for match in matches {
            counts[match.keyword.id, default: (match.keyword, 0)].count += 1
        }

        var newlyHeard = false
        for (id, info) in counts {
            if var existing = detectedByID[id] {
                if info.count != existing.count { existing.lastHeard = stamp }
                existing.count = info.count
                detectedByID[id] = existing
            } else {
                detectedByID[id] = DetectedTerm(
                    keyword: info.keyword,
                    firstHeard: stamp,
                    lastHeard: stamp,
                    count: info.count
                )
                newlyHeard = true
                // Auto-focus the latest unknown term so its definition pops up.
                focusedKeywordID = id
            }
        }

        detected = detectedByID.values.sorted { $0.lastHeard > $1.lastHeard }
        _ = newlyHeard
    }
}
