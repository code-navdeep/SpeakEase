import Foundation

/// The single source of truth for what the dictation pipeline is doing.
/// Every UI surface renders purely from this; nothing else holds pipeline state.
enum DictationState: Equatable {
    /// Nothing happening; ready to record.
    case idle
    /// Provisioning the transcriber (locale check, possible asset download) and
    /// starting audio capture. The microphone is NOT yet live.
    case preparing
    /// Capturing the microphone. `transcript` is the live (volatile) partial text.
    case recording(transcript: String)
    /// Recording stopped; finalizing the transcript.
    case transcribing
    /// Rewriting the finalized transcript with Foundation Models (only when a prompt is active).
    case enhancing
    /// Inserting the final text into the frontmost app.
    case injecting
    /// Something went wrong. Returns to `.idle` on the next user action.
    case failed(DictationError)

    var isBusy: Bool {
        switch self {
        case .idle, .failed: return false
        case .preparing, .recording, .transcribing, .enhancing, .injecting: return true
        }
    }

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isPreparing: Bool {
        if case .preparing = self { return true }
        return false
    }

    /// Live partial transcript while recording, otherwise nil.
    var liveTranscript: String? {
        if case .recording(let t) = self { return t }
        return nil
    }
}
