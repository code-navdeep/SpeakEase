import SwiftUI
import AppKit

/// The menu shown from the status-bar item.
struct MenuBarContent: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(DictationEngine.self) private var engine
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(HistoryStore.self) private var history
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Only surfaced while actionable; once granted they disappear.
        if !env.permissions.microphoneGranted {
            Button("Grant Microphone Access…") { openPrivacyPane("Privacy_Microphone") }
        }
        if !env.permissions.accessibilityGranted {
            Button("Grant Accessibility Access…") { openPrivacyPane("Privacy_Accessibility") }
        }

        recordItem
            .onAppear { env.permissions.refresh() }

        if engine.state.isBusy {
            Button("Cancel") { engine.cancelRecording() }
        }

        if case .failed(let error) = engine.state {
            // Click dismisses the error.
            Button(error.errorDescription ?? "Error") { engine.acknowledgeError() }
        }

        if let message = engine.statusMessage, !engine.state.isBusy {
            Text(message).font(.caption)
        }

        Divider()

        if settingsStore.settings.saveHistoryEnabled, !history.items.isEmpty {
            Menu("Recent History") {
                ForEach(history.items.prefix(settingsStore.settings.menuHistoryCount.rawValue)) { item in
                    Button(Self.menuTitle(for: item.text)) { copy(item.text) }
                }
            }
        }

        Button("Open SpeakEase") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        SettingsLink {
            Text("Settings…")
        }

        Divider()

        Button("About SpeakEase") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "about")
        }
        Button("Quit SpeakEase") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// One state-aware item: the action label carries the pipeline stage, with
    /// the global shortcut appended.
    @ViewBuilder
    private var recordItem: some View {
        switch engine.state {
        case .idle, .failed:
            Button("Start Recording\(shortcutSuffix)") { engine.toggle() }
        case .preparing:
            // Click cancels — nothing has been captured yet.
            Button(preparingLabel) { engine.toggle() }
        case .recording:
            Button("Stop Recording\(shortcutSuffix)") { engine.toggle() }
        case .transcribing:
            Button("Transcribing…") {}.disabled(true)
        case .enhancing:
            Button("Enhancing…") {}.disabled(true)
        case .injecting:
            Button("Inserting…") {}.disabled(true)
        }
    }

    private var shortcutSuffix: String {
        guard settingsStore.settings.hotkeyEnabled else { return "" }
        return " (\(KeyNames.describe(settingsStore.settings.hotkey)))"
    }

    private var preparingLabel: String {
        if let progress = engine.preparationProgress, progress > 0 {
            return "Preparing… \(Int(progress * 100))%"
        }
        return "Preparing…"
    }

    private static func menuTitle(for text: String) -> String {
        let oneLine = text.replacingOccurrences(of: "\n", with: " ")
        return oneLine.count > 40 ? String(oneLine.prefix(40)) + "…" : oneLine
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func openPrivacyPane(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
