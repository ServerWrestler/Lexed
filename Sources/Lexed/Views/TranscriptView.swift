import SwiftUI

/// The live captions panel. Large, readable text that auto-scrolls to follow the
/// speaker, with keyword hits highlighted inline.
struct TranscriptView: View {
    @EnvironmentObject private var model: LexedViewModel
    @AppStorage("transcriptFontSize") private var fontSize: Double = 22

    private let bottomAnchor = "transcript-bottom"

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if model.highlighted.characters.isEmpty {
                            emptyState
                        } else {
                            Text(model.highlighted)
                                .font(.system(size: fontSize, weight: .regular, design: .rounded))
                                .lineSpacing(6)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(24)

                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .onChange(of: model.highlighted) { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(bottomAnchor, anchor: .bottom)
                    }
                }
            }

            Divider()
            fontControls
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Press **Listen** to start live captions.")
                .foregroundStyle(.secondary)
            Text("Spoken keywords from your glossary get highlighted and defined as you hear them.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private var fontControls: some View {
        HStack(spacing: 12) {
            Image(systemName: "textformat.size.smaller")
                .foregroundStyle(.secondary)
            Slider(value: $fontSize, in: 14...40)
                .frame(maxWidth: 220)
            Image(systemName: "textformat.size.larger")
                .foregroundStyle(.secondary)
            Spacer()
            if !model.detected.isEmpty {
                Label("\(model.detected.count) defined", systemImage: "sparkles")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
