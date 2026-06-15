import SwiftUI

@main
struct LexedApp: App {
    @StateObject private var model = LexedViewModel()

    var body: some Scene {
        WindowGroup("Lexed") {
            ContentView()
                .environmentObject(model)
                .environmentObject(model.glossary)
                .frame(minWidth: 760, minHeight: 480)
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(after: .toolbar) {
                Button(model.speech.isRunning ? "Stop Listening" : "Start Listening") {
                    model.toggleListening()
                }
                .keyboardShortcut("l", modifiers: [.command])

                Button("Clear Session") { model.clearSession() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
