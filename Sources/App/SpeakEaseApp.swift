import SwiftUI
import AppKit

@main
struct SpeakEaseApp: App {
    @State private var env = AppEnvironment()

    var body: some Scene {
        // Menu-bar–resident control surface.
        MenuBarExtra {
            MenuBarContent()
                .environment(env)
                .environment(env.engine)
                .environment(env.settingsStore)
                .environment(env.history)
        } label: {
            Image(systemName: env.engine.state.isRecording ? "waveform.circle.fill" : "waveform")
        }
        .menuBarExtraStyle(.menu)

        Window("About SpeakEase", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)

        // Main utility window (History, File transcription, Prompts).
        Window("SpeakEase", id: "main") {
            MainWindow()
                .environment(env)
                .environment(env.engine)
                .environment(env.settingsStore)
                .environment(env.history)
                .frame(minWidth: 720, minHeight: 520)
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environment(env)
                .environment(env.engine)
                .environment(env.settingsStore)
        }
    }
}
