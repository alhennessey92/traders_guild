import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - ================================================================================================
// MARK: - SPEECH RECOGNITION SERVICE
// MARK: - ================================================================================================

/// Self-contained service for speech-to-text dictation using Apple's Speech framework.
/// Used by ChatInputFooter for microphone dictation across all chat contexts.
final class SpeechRecognitionService: ObservableObject {

    // MARK: - Published State

    @Published var isRecording = false
    @Published var isAuthorized = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Init

    init(locale: Locale = .current) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        // Don't request auth on init — deferred to first toggleRecording() call
        // to avoid triggering audio session setup when view loads
    }

    // MARK: - Authorization

    /// Checks current authorization status for speech recognition and microphone access
    func checkAuthorizationStatus() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.isAuthorized = true
                    self?.errorMessage = nil
                case .denied:
                    self?.isAuthorized = false
                    self?.errorMessage = "Speech recognition access denied. Please enable in Settings."
                case .restricted:
                    self?.isAuthorized = false
                    self?.errorMessage = "Speech recognition is restricted on this device."
                case .notDetermined:
                    self?.isAuthorized = false
                    self?.errorMessage = nil
                @unknown default:
                    self?.isAuthorized = false
                    self?.errorMessage = "Unknown authorization status."
                }
            }
        }
    }

    // MARK: - Toggle Recording

    /// Toggles recording on/off. Call this from the mic button action.
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Start Recording

    /// Begins audio capture and live speech recognition
    func startRecording() {
        // Cancel any in-progress task
        recognitionTask?.cancel()
        recognitionTask = nil

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available."
            return
        }

        guard isAuthorized else {
            checkAuthorizationStatus()
            return
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.mixWithOthers, .allowBluetoothHFP]
            )
            try audioSession.setActive(true)
        } catch {
            errorMessage = "Failed to configure audio session."
            return
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create recognition request."
            deactivateAudioSession()
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        // Install audio tap on input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            var isFinal = false

            if let result = result {
                let bestTranscription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcribedText = bestTranscription
                }
                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                DispatchQueue.main.async {
                    self.stopRecording()
                }
            }
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isRecording = true
                self.transcribedText = ""
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Audio engine failed to start."
                self.cleanup()
            }
        }
    }

    // MARK: - Stop Recording

    /// Stops audio capture and finalizes transcription
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        deactivateAudioSession()

        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    // MARK: - Cleanup

    /// Full cleanup — call when the view disappears
    func cleanup() {
        stopRecording()
        transcribedText = ""
        errorMessage = nil
    }

    private func cleanupInternal() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-critical — audio session will clean up eventually
        }
    }
}
