import Foundation
import AVFoundation
import Speech
import os

/// `TranscriptionService` backed by Apple's on-device `SpeechAnalyzer` /
/// `SpeechTranscriber` (macOS 26+). Models are managed by the OS via
/// `AssetInventory`; nothing is bundled or downloaded by the app.
///
/// Holds no mutable state — every call builds its own analyzer/transcriber from
/// locals — so it is a plain `Sendable` class rather than an actor.
final class SpeechTranscriberService: TranscriptionService {

    // MARK: - Locale readiness

    func prepare(localeIdentifier: String, onProgress: (@Sendable (Double) -> Void)?) async throws {
        let locale = Locale(identifier: localeIdentifier)

        let supported = await SpeechTranscriber.supportedLocales
        guard Self.contains(supported, locale) else {
            throw DictationError.localeUnsupported(localeIdentifier)
        }

        let installed = await SpeechTranscriber.installedLocales
        if Self.contains(installed, locale) { return }

        // Supported but not yet installed → ask the OS to provision the assets.
        let transcriber = makeTranscriber(locale: locale)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            Log.transcription.info("Installing speech assets for \(localeIdentifier, privacy: .public)")
            let poller: Task<Void, Never>? = onProgress.map { report in
                let progress = request.progress
                return Task {
                    while !Task.isCancelled {
                        report(progress.fractionCompleted)
                        try? await Task.sleep(for: .milliseconds(300))
                    }
                }
            }
            defer { poller?.cancel() }
            try await request.downloadAndInstall()
        }
    }

    // MARK: - Live transcription

    func transcribe(
        _ buffers: AsyncStream<AudioBuffer>,
        localeIdentifier: String
    ) -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let locale = Locale(identifier: localeIdentifier)
                let transcriber = self.makeTranscriber(locale: locale)
                let analyzer = SpeechAnalyzer(modules: [transcriber])
                var resultsTask: Task<Void, Error>?
                do {
                    guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                        compatibleWith: [transcriber]
                    ) else {
                        throw DictationError.transcriptionFailed("No compatible audio format.")
                    }

                    let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
                    try await analyzer.start(inputSequence: inputSequence)

                    // Drain recognizer results concurrently with feeding audio.
                    let drain = Task {
                        for try await result in transcriber.results {
                            let text = String(result.text.characters)
                            continuation.yield(TranscriptionUpdate(text: text, isFinal: result.isFinal))
                        }
                    }
                    resultsTask = drain

                    let converter = BufferConverter()
                    for await item in buffers {
                        let converted = try converter.convert(item.pcm, to: analyzerFormat)
                        inputBuilder.yield(AnalyzerInput(buffer: converted))
                    }

                    inputBuilder.finish()
                    try await analyzer.finalizeAndFinishThroughEndOfInput()
                    try await drain.value
                    continuation.finish()
                } catch is CancellationError {
                    resultsTask?.cancel()
                    await analyzer.cancelAndFinishNow()
                    continuation.finish(throwing: DictationError.cancelled)
                } catch {
                    resultsTask?.cancel()
                    await analyzer.cancelAndFinishNow()
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - File transcription

    func transcribeFile(at url: URL, localeIdentifier: String) async throws -> String {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(min(file.length, 4096))

        // Stream the file's frames through the same path the microphone uses.
        let (stream, continuation) = AsyncStream<AudioBuffer>.makeStream()
        let reader = Task {
            defer { continuation.finish() }
            while true {
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { break }
                try file.read(into: buffer)
                if buffer.frameLength == 0 { break }
                if let copy = buffer.deepCopy() {
                    continuation.yield(AudioBuffer(pcm: copy))
                }
            }
        }

        var finalText = ""
        for try await update in transcribe(stream, localeIdentifier: localeIdentifier) where update.isFinal {
            finalText += update.text
        }
        _ = try await reader.value

        let trimmed = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DictationError.noSpeechDetected }
        return trimmed
    }

    // MARK: - Helpers

    private func makeTranscriber(locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
    }

    private static func contains(_ locales: [Locale], _ locale: Locale) -> Bool {
        let target = locale.identifier(.bcp47)
        return locales.contains { $0.identifier(.bcp47) == target }
    }
}
