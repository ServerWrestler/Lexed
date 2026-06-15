import SwiftUI

/// Right-hand panel: the most recently heard keyword shown large as a "current
/// definition" card, followed by the full list of terms heard this session.
struct DefinitionsSidebar: View {
    @EnvironmentObject private var model: LexedViewModel

    private var focused: DetectedTerm? {
        if let id = model.focusedKeywordID,
           let term = model.detected.first(where: { $0.id == id }) {
            return term
        }
        return model.detected.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if let focused {
                CurrentDefinitionCard(term: focused)
                    .padding(16)
                Divider()
                historyList
            } else {
                Spacer()
                Text("Heard terms will appear here.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .background(.background)
    }

    private var header: some View {
        HStack {
            Label("Definitions", systemImage: "book")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(model.detected) { term in
                    Button {
                        model.focusedKeywordID = term.id
                    } label: {
                        DetectedRow(term: term, isFocused: term.id == model.focusedKeywordID)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }
}

/// The big, glanceable card for the term currently in focus.
private struct CurrentDefinitionCard: View {
    let term: DetectedTerm

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(term.keyword.term)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Spacer()
                if let category = term.keyword.category {
                    Text(category)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
            }

            Text(term.keyword.definition)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            if let source = term.keyword.source, let url = URL(string: source) {
                Link(destination: url) {
                    Label("Learn more", systemImage: "arrow.up.right.square")
                        .font(.callout)
                }
            }

            HStack(spacing: 12) {
                Label("\(term.count)×", systemImage: "repeat")
                Label(term.lastHeard.formatted(date: .omitted, time: .standard),
                      systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }
}

/// A compact row in the session history list.
private struct DetectedRow: View {
    let term: DetectedTerm
    let isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(term.keyword.term)
                    .font(.headline)
                Spacer()
                Text("\(term.count)×")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(term.keyword.definition)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isFocused ? Color.accentColor.opacity(0.08) : .clear)
        .contentShape(Rectangle())
    }
}
