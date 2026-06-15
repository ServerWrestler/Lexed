import Foundation
import AVFoundation
import Speech
import CoreGraphics
import Combine

/// Real-time speech-to-text built on Apple's on-device `Speech` framework.
///
/// Audio comes from a pluggable `AudioCapture` backend — the microphone
/// (`AVAudioEngine`) or system audio (`ScreenCaptureKit`) — and is streamed into
/// an `SFSpeechAudioBufferRecognitionRequest`. Partial results stream in
/// continuously as `volatileText`; when the recognizer finalizes a segment it is
/// committed to `finalizedText` and a fresh request is rotated in (without
/// stopping capture), so transcription runs indefinitely. Recognition is
/// **on-device only** — audio never leaves the Mac.
@MainActor
final class SpeechRecognizer: ObservableObject {

    // MARK: Published state

    @Published private(set) var finalizedText = ""
    @Published private(set) var volatileText = ""
    @Published private(set) var isRunning = false
    @Published private(set) var authorization: Authorization = .notDetermined
    @Published private(set) var statusMessage = "Idle"

    /// Where to capture audio from. Persisted across launches.
    @Published var audioSourceKind: AudioSourceKind {
        didSet { UserDefaults.standard.set(audioSourceKind.rawValue, forKey: Keys.audioSource) }
    }
    /// Recognition language. Persisted across launches.
    @Published var localeIdentifier: String {
        didSet { UserDefaults.standard.set(localeIdentifier, forKey: Keys.locale) }
    }

    /// The full transcript to display: committed text plus the live hypothesis.
    var fullText: String {
        switch (finalizedText.isEmpty, volatileText.isEmpty) {
        case (true, true):   return ""
        case (false, true):  return finalizedText
        case (true, false):  return volatileText
        case (false, false): return finalizedText + " " + volatileText
        }
    }

    enum Authorization {
        case notDetermined, denied, restricted, authorized
    }

    // MARK: Private

    private enum Keys {
        static let audioSource = "audioSourceKind"
        static let locale = "localeIdentifier"
    }

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var capture: AudioCapture?

    /// Locales with an installed on-device model, for the settings picker.
    static var supportedLocales: [Locale] {
        SFSpeechRecognizer.supportedLocales().sorted { $0.identifier < $1.identifier }
    }

    init() {
        let defaults = UserDefaults.standard
        audioSourceKind = AudioSourceKind(rawValue: defaults.string(forKey: Keys.audioSource) ?? "")
            ?? .systemAudio
        localeIdentifier = defaults.string(forKey: Keys.locale) ?? "en-US"
    }

    // MARK: - Lifecycle

    func toggle() {
        if isRunning {
            stop()
        } else {
            Task { await start() }
        }
    }

    func start() async {
        guard !isRunning else { return }
        guard await ensureSpeechAuthorized() else { return }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
            statusMessage = "No recognizer available for \(localeIdentifier)."
            return
        }
        guard recognizer.isAvailable else {
            statusMessage = "Recognizer for \(localeIdentifier) is temporarily unavailable."
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            statusMessage = "On-device model for \(localeIdentifier) isn't installed. Add it in System Settings ▸ Keyboard ▸ Dictation, then pick this language in Settings."
            return
        }
        self.recognizer = recognizer

        // Build the capture backend, requesting its specific permission first.
        let capture: AudioCapture
        switch audioSourceKind {
        case .microphone:
            guard await ensureMicrophoneAuthorized() else {
                statusMessage = "Microphone permission is required (System Settings ▸ Privacy & Security ▸ Microphone)."
                return
            }
            capture = MicrophoneCapture { [weak self] buffer in
                self?.request?.append(buffer)
            }
        case .systemAudio:
            guard ensureScreenRecordingAuthorized() else {
                statusMessage = "Grant Screen Recording to Lexed (System Settings ▸ Privacy & Security ▸ Screen Recording), then start again."
                return
            }
            capture = SystemAudioCapture(
                onSampleBuffer: { [weak self] sample in
                    self?.request?.appendAudioSampleBuffer(sample)
                },
                onStop: { [weak self] error in
                    Task { @MainActor in self?.handleCaptureStopped(error) }
                }
            )
        }

        isRunning = true
        startRequest()

        do {
            try await capture.start()
            self.capture = capture
            statusMessage = audioSourceKind == .systemAudio
                ? "Listening to system audio (on-device)…"
                : "Listening to microphone (on-device)…"
        } catch {
            isRunning = false
            cancelRecognition()
            statusMessage = "Couldn't start capture: \(error.localizedDescription)"
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        statusMessage = "Stopped"
        capture?.stop()
        capture = nil
        cancelRecognition()
        commitVolatile()
    }

    /// Clear the transcript without touching the listening state.
    func clearTranscript() {
        finalizedText = ""
        volatileText = ""
    }

    private func handleCaptureStopped(_ error: Error?) {
        guard isRunning else { return }
        stop()
        if let error {
            statusMessage = "System audio capture stopped: \(error.localizedDescription)"
        }
    }

    // MARK: - Authorization

    private func ensureSpeechAuthorized() async -> Bool {
        if authorization == .authorized { return true }
        let status = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        authorization = Self.map(status)
        if authorization != .authorized {
            statusMessage = "Speech Recognition permission is required (System Settings ▸ Privacy & Security ▸ Speech Recognition)."
        }
        return authorization == .authorized
    }

    private func ensureMicrophoneAuthorized() async -> Bool {
        await withCheckedContinuation { cont in
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                cont.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
            default:
                cont.resume(returning: false)
            }
        }
    }

    /// Returns true if Screen Recording is already granted; otherwise prompts.
    /// (macOS may require relaunching Lexed after the grant the first time.)
    private func ensureScreenRecordingAuthorized() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        return CGRequestScreenCaptureAccess()
    }

    private static func map(_ s: SFSpeechRecognizerAuthorizationStatus) -> Authorization {
        switch s {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    // MARK: - Recognition requests (rotated for unlimited duration)

    private func startRequest() {
        guard isRunning, let recognizer else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true   // on-device only, always
        request.addsPunctuation = true
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                self?.handle(result: result, error: error)
            }
        }
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            let text = result.bestTranscription.formattedString
            if result.isFinal {
                appendFinalized(text)
                volatileText = ""
                if isRunning { rotateRequest() }
            } else {
                volatileText = text
            }
        }

        if error != nil {
            // Usually the ~1-minute segment limit or a transient hiccup. If we're
            // still meant to be listening, rotate in a fresh request and continue.
            commitVolatile()
            if isRunning { rotateRequest() }
        }
    }

    private func rotateRequest() {
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        startRequest()
    }

    private func cancelRecognition() {
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
    }

    private func commitVolatile() {
        guard !volatileText.isEmpty else { return }
        appendFinalized(volatileText)
        volatileText = ""
    }

    private func appendFinalized(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        finalizedText = finalizedText.isEmpty ? trimmed : finalizedText + " " + trimmed
    }
}
