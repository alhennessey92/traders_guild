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
    private var hasInstalledInputTap = false
    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Init

    init(locale: Locale = .current) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        // Don't request auth on init — deferred to first toggleRecording() call
        // to avoid triggering audio session setup when view loads
        configureAudioSessionObservers()
    }

    deinit {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
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

        // Configure audio session.
        //
        // AVAudioSession does not exist on macOS: there is no system-wide audio
        // session to negotiate with, and AVAudioEngine drives the input device
        // directly. Recording works without any of this — the sandbox's
        // audio-input entitlement is what grants access there.
        #if canImport(UIKit)
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
        #endif

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
        hasInstalledInputTap = true

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
                    self.finishRecordingSession()
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
                self.cleanupInternal()
            }
        }
    }

    // MARK: - Stop Recording

    /// Stops audio capture and finalizes transcription
    func stopRecording() {
        finishRecordingSession()
    }

    // MARK: - Cleanup

    /// Full cleanup — call when the view disappears
    func cleanup() {
        cleanupInternal()
        transcribedText = ""
        errorMessage = nil
    }

    private func cleanupInternal() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledInputTap = false
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        deactivateAudioSession()
    }

    private func finishRecordingSession() {
        cleanupInternal()
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    private func deactivateAudioSession() {
        #if canImport(UIKit)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-critical — audio session will clean up eventually
        }
        #endif
    }

    private func configureAudioSessionObservers() {
        // Interruptions, route changes and media-services resets are all
        // AVAudioSession concepts. A Mac has no phone call to interrupt
        // recording, so there is nothing to observe.
        #if canImport(UIKit)

        let center = NotificationCenter.default

        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleAudioSessionInterruption(notification)
            }
        )

        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleAudioSessionRouteChange(notification)
            }
        )

        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleMediaServicesReset()
            }
        )
        #endif
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        #if canImport(UIKit)
        guard isRecording else { return }
        guard let userInfo = notification.userInfo,
              let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        if type == .began {
            errorMessage = nil
            finishRecordingSession()
        }
        #endif
    }

    private func handleAudioSessionRouteChange(_ notification: Notification) {
        #if canImport(UIKit)
        guard isRecording else { return }
        guard let userInfo = notification.userInfo,
              let rawReason = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable, .noSuitableRouteForCategory, .routeConfigurationChange:
            finishRecordingSession()
        default:
            break
        }
        #endif
    }

    private func handleMediaServicesReset() {
        guard isRecording else { return }
        finishRecordingSession()
    }
}
