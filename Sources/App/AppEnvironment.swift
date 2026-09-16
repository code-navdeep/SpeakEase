import Foundation
import AppKit
import Observation

/// Composition root. Builds every service once and wires the engine. Injected
/// into the SwiftUI environment; there are no global singletons.
@MainActor
@Observable
final class AppEnvironment {
    let settingsStore: SettingsStore
    let history: HistoryStore
    let permissions: PermissionsService
    let engine: DictationEngine

    @ObservationIgnored private let audio: AudioCaptureService
    @ObservationIgnored private let transcription: any TranscriptionService
    @ObservationIgnored private let enhancement: any EnhancementService
    @ObservationIgnored private let injection: TextInjectionService
    @ObservationIgnored private let hotkey: HotkeyService
    @ObservationIgnored private var hud: RecordingHUDController?

    init() {
        let settingsStore = SettingsStore()
        let history = HistoryStore()
        history.prune(olderThan: settingsStore.settings.historyExpiry)
        let permissions = PermissionsService()
        let audio = AudioCaptureService()
        let transcription = SpeechTranscriberService()
        let enhancement = FoundationModelEnhancer()
        let injection = TextInjectionService()
        let hotkey = HotkeyService()

        let engine = DictationEngine(
            audio: audio,
            transcription: transcription,
            enhancement: enhancement,
            injection: injection,
            hotkey: hotkey,
            settingsStore: settingsStore,
            history: history,
            permissions: permissions
        )

        self.settingsStore = settingsStore
        self.history = history
        self.permissions = permissions
        self.audio = audio
        self.transcription = transcription
        self.enhancement = enhancement
        self.injection = injection
        self.hotkey = hotkey
        self.engine = engine

        self.hud = RecordingHUDController(engine: engine, settingsStore: settingsStore)

        // Request both permissions once, proactively, at launch — no window
        // or hotkey dependency. Each call is a no-op if already decided.
        Task {
            await permissions.requestMicrophone()
            permissions.requestAccessibility()
        }
    }
}
