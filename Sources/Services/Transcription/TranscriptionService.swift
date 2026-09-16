import Foundation
import AVFoundation

/// One transcription update from the engine.
struct TranscriptionUpdate: Equatable {
    /// The text for this update. For volatile updates this is the best-guess
    /// partial; for final updates it is the committed segment.
    let text: String
    /// True when this text is finalized (committed) rather than volatile.
    let isFinal: Bool
}

/// Abstraction over the speech-to-text engine. The concrete implementation is
/// Apple's `SpeechAnalyzer`/`SpeechTranscriber`, but the rest of the app only
/// depends on this protocol.
protocol TranscriptionService: Sendable {
    /// Ensure the model/assets for `localeIdentifier` are installed and ready.
    /// Throws `DictationError.localeUnsupported` if the locale isn't supported.
    /// `onProgress` reports asset-download progress (0…1) when a download is needed.
    func prepare(localeIdentifier: String, onProgress: (@Sendable (Double) -> Void)?) async throws

    /// Transcribe a live stream of microphone buffers, emitting volatile and
    /// final updates until the input stream finishes.
    func transcribe(
        _ buffers: AsyncStream<AudioBuffer>,
        localeIdentifier: String
    ) -> AsyncThrowingStream<TranscriptionUpdate, Error>

    /// Transcribe a complete audio file and return the full text.
    func transcribeFile(at url: URL, localeIdentifier: String) async throws -> String
}

extension TranscriptionService {
    /// `prepare` without progress reporting.
    func prepare(localeIdentifier: String) async throws {
        try await prepare(localeIdentifier: localeIdentifier, onProgress: nil)
    }
}
