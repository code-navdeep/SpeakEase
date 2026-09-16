import Foundation

/// Typed errors for the dictation pipeline. Replaces the previous mix of
/// `NSError` and bare `String`s passed through NotificationCenter.
enum DictationError: Error, Equatable, LocalizedError {
    case microphonePermissionDenied
    case accessibilityPermissionDenied
    case audioEngineFailed(String)
    case localeUnsupported(String)
    case modelUnavailable(String)
    case transcriptionFailed(String)
    case enhancementFailed(String)
    case injectionFailed(String)
    case noSpeechDetected
    case cancelled

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required. Grant it in System Settings → Privacy & Security → Microphone."
        case .accessibilityPermissionDenied:
            return "Accessibility access is required for the global hotkey and pasting. Grant it in System Settings → Privacy & Security → Accessibility."
        case .audioEngineFailed(let detail):
            return "Could not start audio capture. \(detail)"
        case .localeUnsupported(let locale):
            return "Speech transcription is not available for \(locale) on this device."
        case .modelUnavailable(let reason):
            return reason
        case .transcriptionFailed(let detail):
            return "Transcription failed. \(detail)"
        case .enhancementFailed(let detail):
            return "Text enhancement failed. \(detail)"
        case .injectionFailed(let detail):
            return "Could not insert text into the active app. \(detail)"
        case .noSpeechDetected:
            return "No speech was detected."
        case .cancelled:
            return "Cancelled."
        }
    }
}
