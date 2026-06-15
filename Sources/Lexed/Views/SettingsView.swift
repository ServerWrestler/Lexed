import SwiftUI

/// Preferences: recognition language and on-device privacy mode.
struct SettingsView: View {
    @EnvironmentObject private var model: LexedViewModel

    private var locales: [Locale] { SpeechRecognizer.supportedLocales }

    // Bind through the nested SpeechRecognizer explicitly (a projected binding
    // can't be formed through the view model's `let speech` property).
    private var localeBinding: Binding<String> {
        Binding(get: { model.speech.localeIdentifier },
                set: { model.speech.localeIdentifier = $0 })
    }

    var body: some View {
        Form {
            Section("Recognition") {
                Picker("Language", selection: localeBinding) {
                    ForEach(locales, id: \.identifier) { locale in
                        Text(displayName(for: locale)).tag(locale.identifier)
                    }
                }
                .disabled(model.speech.isRunning)

                Label("On-device only — audio never leaves your Mac.",
                      systemImage: "lock.shield")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("Requires the language's on-device dictation model. If it isn't installed, add it in System Settings ▸ Keyboard ▸ Dictation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.speech.isRunning {
                Text("Stop listening to change these settings.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
    }

    private func displayName(for locale: Locale) -> String {
        let current = Locale.current
        let name = current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        return "\(name) (\(locale.identifier))"
    }
}
