import SwiftUI

/// The main window: a toolbar of session controls, the live transcript on the
/// left, and the running list of heard-and-defined keywords on the right.
struct ContentView: View {
    @EnvironmentObject private var model: LexedViewModel
    @State private var showingGlossary = false

    var body: some View {
        HSplitView {
            TranscriptView()
                .frame(minWidth: 420)

            DefinitionsSidebar()
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 460)
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingGlossary) {
            GlossaryEditor()
                .environmentObject(model.glossary)
                .frame(minWidth: 560, minHeight: 460)
        }
        // Clicking a highlighted keyword opens a `lexed://term/<uuid>` link.
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "lexed",
                  let id = UUID(uuidString: url.lastPathComponent) else {
                return .systemAction
            }
            model.focusedKeywordID = id
            return .handled
        })
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: model.toggleListening) {
                Label(model.speech.isRunning ? "Stop" : "Listen",
                      systemImage: model.speech.isRunning ? "stop.circle.fill" : "mic.circle.fill")
            }
            .help(model.speech.isRunning ? "Stop transcribing (⌘L)" : "Start transcribing (⌘L)")
            .tint(model.speech.isRunning ? .red : .accentColor)
        }

        ToolbarItem(placement: .principal) {
            StatusPill()
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: model.clearSession) {
                Label("Clear", systemImage: "eraser")
            }
            .help("Clear the transcript and heard terms (⇧⌘K)")

            Button { showingGlossary = true } label: {
                Label("Keywords", systemImage: "character.book.closed")
            }
            .help("Edit the keyword glossary")
        }
    }
}

/// Small status indicator that animates while listening.
private struct StatusPill: View {
    @EnvironmentObject private var model: LexedViewModel
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.speech.isRunning ? Color.red : Color.secondary)
                .frame(width: 8, height: 8)
                .opacity(model.speech.isRunning && pulse ? 0.3 : 1)
                .animation(model.speech.isRunning
                           ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                           : .default,
                           value: pulse)
            Text(model.speech.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .onAppear { pulse = true }
    }
}
