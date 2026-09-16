import Foundation
import Observation
import os

/// The coordinator. Owns `DictationState` and runs the pipeline
/// (prepare → capture → transcribe → enhance? → inject) as one
/// structured-concurrency flow. Every UI surface renders purely from `state`.
@MainActor
@Observable
final class DictationEngine {
    private(set) var state: DictationState = .idle {
        didSet { syncCancelKey() }
    }
    /// Short transient status (e.g. an enhancement notice). Auto-expires.
    private(set) var statusMessage: String?
    /// Speech-asset download progress (0…1) while `.preparing`, else nil.
    private(set) var preparationProgress: Double?

    @ObservationIgnored private let audio: AudioCaptureService
    @ObservationIgnored private let transcription: any TranscriptionService
    @ObservationIgnored private let enhancement: any EnhancementService
    @ObservationIgnored private let injection: TextInjectionService
    @ObservationIgnored private let hotkey: HotkeyService
    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let history: HistoryStore
    @ObservationIgnored private let permissions: PermissionsService

    @ObservationIgnored private var recordingTask: Task<Void, Never>?
    @ObservationIgnored private var statusGeneration = 0

    // Last-applied values, so the settings observer only reacts to real changes.
    @ObservationIgnored private var observedHotkey: HotkeyBinding
    @ObservationIgnored private var observedHotkeyEnabled: Bool
    @ObservationIgnored private var observedLocale: String

    init(
        audio: AudioCaptureService,
        transcription: any TranscriptionService,
        enhancement: any EnhancementService,
        injection: TextInjectionService,
        hotkey: HotkeyService,
        settingsStore: SettingsStore,
        history: HistoryStore,
        permissions: PermissionsService
    ) {
        self.audio = audio
        self.transcription = transcription
        self.enhancement = enhancement
        self.injection = injection
        self.hotkey = hotkey
        self.settingsStore = settingsStore
        self.history = history
        self.permissions = permissions
        self.observedHotkey = settingsStore.settings.hotkey
        self.observedHotkeyEnabled = settingsStore.settings.hotkeyEnabled
        self.observedLocale = settingsStore.settings.localeIdentifier

        hotkey.onPress = { [weak self] in self?.handleHotkeyPress() }
        hotkey.onRelease = { [weak self] in self?.handleHotkeyRelease() }
        hotkey.onCancel = { [weak self] in self?.cancelRecording() }
        applyHotkeySettings()
        observeSettings()
        warmUp()
    }

    private var settings: AppSettings { settingsStore.settings }

    /// Current mic input level in dBFS, for the waveform.
    nonisolated func micLevel() -> Float { audio.level() }

    // MARK: - Public control

    func toggle() {
        if state.isRecording || state.isPreparing {
            stopRecording()
        } else if !state.isBusy {
            startRecording()
        }
    }

    /// Abort the current dictation entirely: nothing is transcribed or inserted.
    func cancelRecording() {
        guard state.isBusy else { return }
        recordingTask?.cancel()
        recordingTask = nil
        audio.stop()
        preparationProgress = nil
        state = .idle
    }

    /// Re-register the global hotkey from current settings.
    func applyHotkeySettings() {
        hotkey.update(binding: settings.hotkey, enabled: settings.hotkeyEnabled)
    }

    /// Dismiss a `.failed` state.
    func acknowledgeError() {
        if case .failed = state { state = .idle }
    }

    func enhancementAvailability() async -> EnhancementAvailability {
        await enhancement.availability()
    }

    /// Insert arbitrary text (e.g. a history item) into the frontmost app,
    /// honoring the clipboard settings.
    func insert(text: String) {
        do {
            let outcome = try injection.inject(
                text,
                pressEnter: false,
                autoClearDelay: settings.restoreClipboard ? nil : settings.clipboardAutoClear.seconds,
                restoreClipboard: settings.restoreClipboard
            )
            if case .copiedToClipboard(let reason) = outcome {
                setStatus("\(reason). Copied to clipboard — grant Accessibility to auto-paste.")
            }
        } catch {
            setStatus("Could not insert into the active app. Text is on the clipboard.")
        }
    }

    // MARK: - Hotkey handling (mode-aware)

    private func handleHotkeyPress() {
        switch settings.recordingMode {
        case .toggle:
            toggle()
        case .pushToTalk:
            if !state.isBusy { startRecording() }
        }
    }

    private func handleHotkeyRelease() {
        if settings.recordingMode == .pushToTalk, state.isRecording || state.isPreparing {
            stopRecording()
        }
    }

    /// Escape is captured globally only while a dictation is in flight.
    private func syncCancelKey() {
        if state.isBusy {
            hotkey.registerCancelKey()
        } else {
            hotkey.unregisterCancelKey()
        }
    }

    // MARK: - Recording lifecycle

    private func startRecording() {
        guard !state.isBusy else { return }
        permissions.refresh()
        guard permissions.microphoneGranted else {
            state = .failed(.microphonePermissionDenied)
            return
        }
        setStatus(nil)
        preparationProgress = nil
        state = .preparing
        let locale = settings.localeIdentifier

        recordingTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.transcription.prepare(localeIdentifier: locale, onProgress: { [weak self] fraction in
                    Task { @MainActor [weak self] in
                        guard let self, self.state.isPreparing else { return }
                        self.preparationProgress = fraction
                    }
                })
                // A stop during `.preparing` cancels this task; never start
                // the microphone after that.
                try Task.checkCancellation()
                let buffers = try self.audio.start()
                self.preparationProgress = nil
                self.state = .recording(transcript: "")
                var finalText = ""
                var volatileText = ""

                let updates = self.transcription.transcribe(buffers, localeIdentifier: locale)
                for try await update in updates {
                    if update.isFinal {
                        finalText += update.text
                        volatileText = ""
                    } else {
                        volatileText = update.text
                    }
                    if self.state.isRecording {
                        self.state = .recording(transcript: finalText + volatileText)
                    }
                }
                await self.finish(rawText: finalText)
            } catch is CancellationError {
                self.reset()
            } catch let error as DictationError {
                self.fail(error)
            } catch {
                self.fail(.transcriptionFailed(error.localizedDescription))
            }
        }
    }

    private func stopRecording() {
        switch state {
        case .preparing:
            // Nothing captured yet — cancel; the task's CancellationError
            // path resets to idle.
            recordingTask?.cancel()
        case .recording:
            state = .transcribing
            audio.stop() // finishes the buffer stream → transcription loop completes
        default:
            break
        }
    }

    /// Post-recording: vocabulary, optional enhancement, history, injection.
    private func finish(rawText: String) async {
        guard !Task.isCancelled else { return }
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            fail(.noSpeechDetected)
            return
        }
        let text = settings.vocabulary.apply(to: trimmed)

        var output = text
        var note: String?

        if let instructions = settings.activeInstructions {
            state = .enhancing
            do {
                output = try await enhancement.enhance(text: text, instructions: instructions)
            } catch let DictationError.modelUnavailable(reason) {
                output = text
                note = "\(reason) Inserted raw text."
            } catch {
                output = text
                note = "Enhancement failed; inserted raw text."
            }
        }

        // Cancelled mid-enhancement — insert nothing.
        guard !Task.isCancelled else { return }

        // Archive before attempting delivery so a failed injection never
        // loses the transcript.
        if settings.saveHistoryEnabled {
            history.add(text: output, source: .microphone)
            history.prune(olderThan: settings.historyExpiry)
        }

        state = .injecting
        let outcome: InjectionOutcome
        do {
            outcome = try injection.inject(
                output,
                pressEnter: settings.autoEnter,
                autoClearDelay: settings.restoreClipboard ? nil : settings.clipboardAutoClear.seconds,
                restoreClipboard: settings.restoreClipboard
            )
        } catch let error as DictationError {
            fail(error)
            return
        } catch {
            fail(.injectionFailed(error.localizedDescription))
            return
        }

        switch outcome {
        case .pasted:
            if let note { setStatus(note) }
        case .copiedToClipboard(let reason):
            setStatus("\(reason). Copied to clipboard — grant Accessibility to auto-paste.")
        }
        state = .idle
    }

    private func fail(_ error: DictationError) {
        Log.app.error("Pipeline failed: \(error.localizedDescription, privacy: .public)")
        recordingTask?.cancel()
        recordingTask = nil
        audio.stop()
        preparationProgress = nil
        state = .failed(error)
    }

    private func reset() {
        recordingTask = nil
        audio.stop()
        preparationProgress = nil
        state = .idle
    }

    // MARK: - Status

    /// Sets the transient status line; non-nil messages clear themselves after
    /// a few seconds unless a newer message replaced them.
    private func setStatus(_ message: String?) {
        statusMessage = message
        statusGeneration += 1
        guard message != nil else { return }
        let generation = statusGeneration
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, self.statusGeneration == generation else { return }
            self.statusMessage = nil
        }
    }

    // MARK: - File transcription

    func transcribeFile(at url: URL) async -> Result<String, DictationError> {
        do {
            try await transcription.prepare(localeIdentifier: settings.localeIdentifier)
            let raw = try await transcription.transcribeFile(at: url, localeIdentifier: settings.localeIdentifier)
            let text = settings.vocabulary.apply(to: raw)
            if settings.saveHistoryEnabled {
                history.add(text: text, source: .file, filename: url.lastPathComponent)
                history.prune(olderThan: settings.historyExpiry)
            }
            return .success(text)
        } catch let error as DictationError {
            return .failure(error)
        } catch {
            return .failure(.transcriptionFailed(error.localizedDescription))
        }
    }

    // MARK: - Settings observation

    /// React to settings edits from any UI surface (including Reset All
    /// Settings): re-register the hotkey and warm up a newly chosen locale.
    private func observeSettings() {
        withObservationTracking {
            _ = settingsStore.settings
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.settingsDidChange()
                self.observeSettings()
            }
        }
    }

    private func settingsDidChange() {
        let current = settings
        if current.hotkey != observedHotkey || current.hotkeyEnabled != observedHotkeyEnabled {
            observedHotkey = current.hotkey
            observedHotkeyEnabled = current.hotkeyEnabled
            applyHotkeySettings()
        }
        if current.localeIdentifier != observedLocale {
            observedLocale = current.localeIdentifier
            warmUp()
        }
    }

    // MARK: - Warm-up

    private func warmUp() {
        let locale = settings.localeIdentifier
        Task { [transcription] in
            try? await transcription.prepare(localeIdentifier: locale)
        }
    }
}
