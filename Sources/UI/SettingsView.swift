import SwiftUI
import AppKit
import Carbon.HIToolbox
import Speech
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gear") }
            HotkeySettings()
                .tabItem { Label("Hotkey", systemImage: "keyboard") }
        }
        .frame(width: 480, height: 420)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var locales: [(id: String, name: String)] = []
    @State private var launchAtLogin = false
    @State private var launchAtLoginError: String?

    var body: some View {
        @Bindable var store = settingsStore

        Form {
            Section("Language") {
                Picker("Transcription language", selection: $store.settings.localeIdentifier) {
                    ForEach(locales, id: \.id) { locale in
                        Text(locale.name).tag(locale.id)
                    }
                }
            }

            Section("Startup") {
                // Registration only takes effect for the bundled .app
                // (SMAppService needs a real bundle), not `swift run`.
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { applyLaunchAtLogin() }
                if let launchAtLoginError {
                    Text(launchAtLoginError).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Insertion") {
                Toggle("Press Return after inserting", isOn: $store.settings.autoEnter)
            }

            Section("Recording Overlay") {
                Toggle("Show overlay while recording", isOn: $store.settings.showHUD)
                if store.settings.showHUD {
                    Picker("Position", selection: $store.settings.hudPosition) {
                        ForEach(HUDPosition.allCases, id: \.self) { position in
                            Text(position.displayName).tag(position)
                        }
                    }
                }
            }

            Section("History") {
                Toggle("Save transcriptions to history", isOn: $store.settings.saveHistoryEnabled)
                if store.settings.saveHistoryEnabled {
                    Picker("Keep history for", selection: $store.settings.historyExpiry) {
                        ForEach(HistoryExpiry.allCases, id: \.self) { expiry in
                            Text(expiry.displayName).tag(expiry)
                        }
                    }
                    Picker("Show in menu", selection: $store.settings.menuHistoryCount) {
                        ForEach(MenuHistoryCount.allCases, id: \.self) { count in
                            Text(count.displayName).tag(count)
                        }
                    }
                }
            }

            Section("Clipboard") {
                Toggle("Restore previous clipboard after inserting", isOn: $store.settings.restoreClipboard)
                    .disabled(store.settings.clipboardAutoClear != .off)
                Picker("Clear clipboard after inserting", selection: $store.settings.clipboardAutoClear) {
                    ForEach(ClipboardAutoClear.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .disabled(store.settings.restoreClipboard)
            }

            Section {
                Button("Reset All Settings", role: .destructive) {
                    settingsStore.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .task {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            let supported = await SpeechTranscriber.supportedLocales
            locales = supported
                .map { ($0.identifier(.bcp47), $0.localizedString(forIdentifier: $0.identifier) ?? $0.identifier) }
                .sorted { $0.name < $1.name }
            if locales.isEmpty {
                let current = Locale.current.identifier(.bcp47)
                locales = [(current, current)]
            }
        }
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                guard SMAppService.mainApp.status != .enabled else { return }
                try SMAppService.mainApp.register()
            } else {
                guard SMAppService.mainApp.status == .enabled else { return }
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Hotkey

private struct HotkeySettings: View {
    @Environment(SettingsStore.self) private var settingsStore

    @State private var isCapturing = false
    @State private var monitor: Any?
    @State private var note: String?

    var body: some View {
        @Bindable var store = settingsStore

        Form {
            Section {
                Toggle("Enable global hotkey", isOn: $store.settings.hotkeyEnabled)
            }

            if store.settings.hotkeyEnabled {
                Section("Binding") {
                    HStack {
                        Text("Shortcut")
                        Spacer()
                        Button(isCapturing ? "Press shortcut… (Esc cancels)" : KeyNames.describe(store.settings.hotkey)) {
                            isCapturing ? stopCapture() : startCapture()
                        }
                    }
                    if let note {
                        Text(note).font(.caption).foregroundStyle(.orange)
                    }
                }

                Section("Mode") {
                    Picker("Recording mode", selection: $store.settings.recordingMode) {
                        ForEach(RecordingMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.radioGroup)
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear { stopCapture() }
    }

    private func startCapture() {
        note = nil
        isCapturing = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                handle(event)
            }
            return nil // swallow keystrokes while capturing
        }
    }

    private func stopCapture() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isCapturing = false
    }

    private func handle(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == UInt16(kVK_Escape), mods.isEmpty {
            stopCapture()
            return
        }
        // A bare character key would fire on every unmodified press; only
        // F-keys are safe without a modifier.
        guard !mods.isEmpty || KeyNames.isFunctionKey(event.keyCode) else {
            note = "Use at least one modifier (⌘ ⌥ ⌃ ⇧), or an F-key."
            return
        }
        settingsStore.settings.hotkey = HotkeyBinding(keyCode: event.keyCode, modifierFlags: mods.rawValue)
        note = nil
        stopCapture()
    }
}
