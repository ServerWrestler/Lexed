import Foundation
import AVFoundation
import Speech
import Combine

/// Real-time speech-to-text built on Apple's on-device `Speech` framework.
///
/// Audio flows: microphone → `AVAudioEngine` tap → `SFSpeechAudioBufferRecognitionRequest`
/// → `SFSpeechRecognitionTask`. Partial results stream in continuously and are
/// published as `volatileText`; when the recognizer finalizes a segment it is
/// appended to `finalizedText` and a fresh request is rotated in so transcription
/// continues indefinitely (SFSpeechRecognizer caps a single request at ~1 minute).
@MainActor
final class SpeechRecognizer: ObservableObject {

    // MARK: Published state

    /// Text the recognizer has committed (won't change anymore).
    @Published private(set) var finalizedText: String = ""
    /// The current in-flight hypothesis (updates several times per second).
    @Published private(set) var volatileText: String = ""
    @Published private(set) var isRunning = false
    @Published private(set) var authorization: Authorization = .notDetermined
    @Published private(set) var statusMessage = "Idle"

    /// Force on-device recognition (no audio leaves the Mac). Strongly recommended
    /// for private meetings; requires the locale's model to be installed.
    @Published var requireOnDevice = true
    @Published var localeIdentifier = "en-US"

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

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false

    /// Locales that have an installed on-device model, useful for a settings picker.
    static var supportedLocales: [Locale] {
        SFSpeechRecognizer.supportedLocales()
            .sorted { ($0.identifier) < ($1.identifier) }
    }

    // MARK: - Authorization

    /// Ask for Speech Recognition + Microphone permission. Returns true if both
    /// are granted.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        authorization = Self.map(speechStatus)
        guard authorization == .authorized else {
            statusMessage = "Speech recognition permission was not granted."
            return false
        }

        let micGranted = await requestMicrophoneAccess()
        if !micGranted {
            statusMessage = "Microphone permission was not granted."
            return false
        }
        return true
    }

    private func requestMicrophoneAccess() async -> Bool {
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

    private static func map(_ s: SFSpeechRecognizerAuthorizationStatus) -> Authorization {
        switch s {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
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

        if authorization != .authorized {
            guard await requestAuthorization() else { return }
        }

        let locale = Locale(identifier: localeIdentifier)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            statusMessage = "No recognizer available for \(localeIdentifier)."
            return
        }
        guard recognizer.isAvailable else {
            statusMessage = "Recognizer for \(localeIdentifier) is temporarily unavailable."
            return
        }
        if requireOnDevice && !recognizer.supportsOnDeviceRecognition {
            statusMessage = "On-device model for \(localeIdentifier) isn't installed. Add it in System Settings ▸ Keyboard ▸ Dictation, or turn off on-device mode."
            return
        }
        self.recognizer = recognizer

        do {
            try installTapIfNeeded()
            if !audioEngine.isRunning {
                audioEngine.prepare()
                try audioEngine.start()
            }
        } catch {
            statusMessage = "Couldn't start audio: \(error.localizedDescription)"
            teardownAudio()
            return
        }

        isRunning = true
        statusMessage = requireOnDevice ? "Listening (on-device)…" : "Listening…"
        startRequest()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        statusMessage = "Stopped"
        request?.endAudio()
        task?.finish()
        task = nil
        request = nil
        teardownAudio()
        // Fold any trailing hypothesis into the committed transcript.
        commitVolatile()
    }

    /// Clear the transcript without touching the listening state.
    func clearTranscript() {
        finalizedText = ""
        volatileText = ""
    }

    // MARK: - Audio plumbing

    private func installTapIfNeeded() throws {
        guard !tapInstalled else { return }
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            throw NSError(domain: "Lexed", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No audio input device is available."])
        }
        // The tap runs on a realtime audio thread; just forward buffers to whatever
        // request is currently active.
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        tapInstalled = true
    }

    private func teardownAudio() {
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }

    // MARK: - Recognition requests (rotated to allow unlimited duration)

    private func startRequest() {
        guard isRunning, let recognizer else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = requireOnDevice
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Recognition callbacks may arrive off the main actor.
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
                // Rotate to a new request so we keep transcribing past this segment.
                if isRunning { rotateRequest() }
            } else {
                volatileText = text
            }
        }

        if error != nil {
            // Errors here are usually the ~1-minute segment limit or a transient
            // audio hiccup. If we're meant to be listening, just rotate in a
            // fresh request and carry on.
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

    private func commitVolatile() {
        guard !volatileText.isEmpty else { return }
        appendFinalized(volatileText)
        volatileText = ""
    }

    private func appendFinalized(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if finalizedText.isEmpty {
            finalizedText = trimmed
        } else {
            finalizedText += " " + trimmed
        }
    }
}
