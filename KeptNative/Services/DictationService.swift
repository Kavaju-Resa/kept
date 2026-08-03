// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

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
    private var hasInputTap = false
    private var startGeneration = 0
    private var isStarting = false

    func start(language: String) async {
        guard !isRecording, !isStarting else { return }
        isStarting = true
        startGeneration += 1
        let generation = startGeneration
        defer {
            if generation == startGeneration { isStarting = false }
        }

        let speechPermission = await SFSpeechRecognizer.requestAuthorization()
        guard generation == startGeneration else { return }
        guard speechPermission == .authorized else {
            errorMessage = "Speech recognition permission is required."
            return
        }
        guard await requestMicrophonePermission() else {
            guard generation == startGeneration else { return }
            errorMessage = "Microphone permission is required."
            return
        }
        guard generation == startGeneration else { return }

        let locale = language == "auto" ? Locale.current : Locale(identifier: language)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            errorMessage = "Speech recognition is unavailable."
            return
        }

        stopAudioSession()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            errorMessage = "No microphone input is available."
            stopAudioSession()
            return
        }
        let sink = AudioBufferSink(request: request)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
            sink.append(buffer)
        }
        hasInputTap = true
        task = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
            let transcript = result?.bestTranscription.formattedString
            let shouldStop = error != nil || result?.isFinal == true
            Task { @MainActor [weak self] in
                if let transcript { self?.transcript = transcript }
                if shouldStop { self?.stop() }
            }
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            transcript = ""
        } catch {
            errorMessage = error.localizedDescription
            stopAudioSession()
        }
    }

    func stop() {
        startGeneration += 1
        isStarting = false
        stopAudioSession()
    }

    private func stopAudioSession() {
        if audioEngine.isRunning { audioEngine.stop() }
        if hasInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
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

private final class AudioBufferSink: @unchecked Sendable {
    private let request: SFSpeechAudioBufferRecognitionRequest

    init(request: SFSpeechAudioBufferRecognitionRequest) {
        self.request = request
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request.append(buffer)
    }
}

private extension SFSpeechRecognizer {
    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            requestAuthorization { continuation.resume(returning: $0) }
        }
    }
}
