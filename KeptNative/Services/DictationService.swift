import AVFoundation
import Foundation
import Observation
import Speech

@MainActor
@Observable
final class DictationService {
    var transcript = ""
    var isRecording = false
    var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start(language: String) async {
        guard !isRecording else { return }
        let speechPermission = await SFSpeechRecognizer.requestAuthorization()
        guard speechPermission == .authorized else {
            errorMessage = "Speech recognition permission is required."
            return
        }
        guard await requestMicrophonePermission() else {
            errorMessage = "Microphone permission is required."
            return
        }

        let locale = language == "auto" ? Locale.current : Locale(identifier: language)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            errorMessage = "Speech recognition is unavailable."
            return
        }

        stop()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            transcript = ""
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result { self?.transcript = result.bestTranscription.formattedString }
                    if error != nil || result?.isFinal == true { self?.stop() }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            stop()
        }
    }

    func stop() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
        }
    }
}

private extension SFSpeechRecognizer {
    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            requestAuthorization { continuation.resume(returning: $0) }
        }
    }
}
