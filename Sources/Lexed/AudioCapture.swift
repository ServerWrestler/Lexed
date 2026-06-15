import Foundation
import AVFoundation
import CoreMedia
import ScreenCaptureKit

/// Where Lexed gets the audio it transcribes.
enum AudioSourceKind: String, CaseIterable, Identifiable, Codable {
    /// ScreenCaptureKit — captures whatever you *hear*: Zoom, Google Meet, Teams,
    /// Slack huddles, any app playing audio. Requires Screen Recording permission.
    case systemAudio
    /// AVAudioEngine — the selected microphone, for in-person conversations.
    case microphone

    var id: String { rawValue }

    var label: String {
        switch self {
        case .systemAudio: return "System audio (apps & calls)"
        case .microphone:  return "Microphone (in person)"
        }
    }

    var help: String {
        switch self {
        case .systemAudio:
            return "Transcribes any audio playing on your Mac — Zoom, Meet, Teams, Slack huddles. Requires Screen Recording permission."
        case .microphone:
            return "Transcribes the microphone. Best for in-person meetings."
        }
    }
}

/// A backend that captures audio and hands each chunk to the recognizer.
protocol AudioCapture: AnyObject {
    func start() async throws
    func stop()
}

enum CaptureError: LocalizedError {
    case noInputDevice
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .noInputDevice: return "No audio input device is available."
        case .noDisplay:     return "No display is available to capture system audio from."
        }
    }
}

// MARK: - Microphone

/// Captures the default input device with `AVAudioEngine` and forwards PCM
/// buffers. Used for in-person meetings.
final class MicrophoneCapture: AudioCapture {
    private let engine = AVAudioEngine()
    private let onBuffer: (AVAudioPCMBuffer) -> Void
    private var tapInstalled = false

    init(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) {
        self.onBuffer = onBuffer
    }

    func start() async throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { throw CaptureError.noInputDevice }

        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [onBuffer] buffer, _ in
            onBuffer(buffer)
        }
        tapInstalled = true
        engine.prepare()
        try engine.start()
    }

    func stop() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if engine.isRunning { engine.stop() }
    }
}

// MARK: - System audio

/// Captures system audio with ScreenCaptureKit and forwards the audio sample
/// buffers. This is what lets Lexed caption the far side of a Zoom/Meet/Teams
/// call or a Slack huddle without any virtual audio device.
///
/// Only an `.audio` stream output is added, so no video frames are ever
/// processed — the tiny video dimensions in the configuration exist solely to
/// satisfy the API.
final class SystemAudioCapture: NSObject, AudioCapture, SCStreamOutput, SCStreamDelegate {
    private let onSampleBuffer: (CMSampleBuffer) -> Void
    private let onStop: (Error?) -> Void
    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "app.lexed.system-audio")

    init(onSampleBuffer: @escaping (CMSampleBuffer) -> Void,
         onStop: @escaping (Error?) -> Void = { _ in }) {
        self.onSampleBuffer = onSampleBuffer
        self.onStop = onStop
    }

    func start() async throws {
        // This is the call that triggers / requires the Screen Recording grant.
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else { throw CaptureError.noDisplay }

        let filter = SCContentFilter(display: display,
                                     excludingApplications: [],
                                     exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true   // don't transcribe Lexed's own output
        config.sampleRate = 48_000
        config.channelCount = 1
        // Audio-only: keep the (mandatory) video plane minimal and idle.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() {
        let stopping = stream
        stream = nil
        Task { try? await stopping?.stopCapture() }
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .audio, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        onSampleBuffer(sampleBuffer)
    }

    // MARK: SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        self.stream = nil
        onStop(error)
    }
}
