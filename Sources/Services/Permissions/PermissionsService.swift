import AppKit
import AVFoundation
import ApplicationServices
import Observation
import os

/// Tracks and requests the two permissions the app actually needs:
/// microphone and accessibility. (Speech assets are handled by the OS via
/// `AssetInventory` in the transcription service.)
@MainActor
@Observable
final class PermissionsService {
    private(set) var microphoneGranted = false
    private(set) var accessibilityGranted = false

    var allGranted: Bool { microphoneGranted && accessibilityGranted }

    init() {
        refresh()
    }

    func refresh() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
    }

    /// Prompt for microphone access (system dialog on first ask). Activates
    /// the app first — this is a menu-bar agent with no Dock icon, and the
    /// system prompt needs the app frontmost to reliably surface.
    func requestMicrophone() async {
        NSApp.activate(ignoringOtherApps: true)
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneGranted = granted
        Log.permissions.info("Microphone granted: \(granted, privacy: .public)")
    }

    /// Trigger the accessibility prompt and open the relevant settings pane.
    /// Granting it requires a user toggle in System Settings; `refresh()` is
    /// called when the menu opens and before each recording, which picks up
    /// the change.
    func requestAccessibility() {
        // The literal key avoids referencing the non-concurrency-safe global
        // `kAXTrustedCheckOptionPrompt` (its value is this string).
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }
}
