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
    private var onDeviceBinding: Binding<Bool> {
        Binding(get: { model.speech.requireOnDevice },
                set: { model.speech.requireOnDevice = $0 })
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

                Toggle("On-device only (recommended)", isOn: onDeviceBinding)
                    .disabled(model.speech.isRunning)

                Text(model.speech.requireOnDevice
                     ? "Audio never leaves your Mac. Requires the language's on-device model (System Settings ▸ Keyboard ▸ Dictation ▸ add language)."
                     : "May send audio to Apple for recognition. Not recommended for confidential meetings.")
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
