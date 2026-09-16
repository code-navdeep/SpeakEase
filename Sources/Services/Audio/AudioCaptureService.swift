import Foundation
import AVFoundation
import os

/// Captures the microphone via `AVAudioEngine` and exposes the raw PCM buffers
/// as an `AsyncStream`. No files are written; the same buffers feed both the
/// transcriber and the waveform meter (via `level()`).
@MainActor
final class AudioCaptureService {
    private let engine = AVAudioEngine()
    private var continuation: AsyncStream<AudioBuffer>.Continuation?
    private var isRunning = false

    /// Most recent input level in dBFS (≈ -160…0), updated from the audio tap.
    private let levelStore = OSAllocatedUnfairLock<Float>(initialState: -160)

    /// Begin capturing. Returns a stream of microphone PCM buffers.
    func start() throws -> AsyncStream<AudioBuffer> {
        if isRunning { stop() }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw DictationError.audioEngineFailed("No usable input device.")
        }

        let (stream, continuation) = AsyncStream<AudioBuffer>.makeStream(
            bufferingPolicy: .bufferingNewest(16)
        )
        self.continuation = continuation

        // The tap block runs on a realtime audio thread. It must be explicitly
        // @Sendable so it does NOT inherit this class's @MainActor isolation —
        // otherwise the runtime injects a main-actor assertion that traps when
        // AVAudioEngine invokes the block off the main thread.
        let levelStore = self.levelStore
        let tapBlock: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { buffer, _ in
            let lvl = AudioCaptureService.level(of: buffer)
            levelStore.withLock { $0 = lvl }
            if let copy = buffer.deepCopy() {
                continuation.yield(AudioBuffer(pcm: copy))
            }
        }
        input.installTap(onBus: 0, bufferSize: 4096, format: format, block: tapBlock)

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            self.continuation = nil
            continuation.finish()
            throw DictationError.audioEngineFailed(error.localizedDescription)
        }

        isRunning = true
        Log.audio.info("Audio capture started @ \(format.sampleRate, privacy: .public) Hz")
        return stream
    }

    /// Stop capturing and finish the buffer stream.
    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        continuation?.finish()
        continuation = nil
        levelStore.withLock { $0 = -160 }
        isRunning = false
        Log.audio.info("Audio capture stopped")
    }

    /// Current input level in dBFS, safe to read from any thread.
    nonisolated func level() -> Float {
        levelStore.withLock { $0 }
    }

    /// RMS power of a buffer's first channel, in dBFS.
    private nonisolated static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return -160 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return -160 }
        var sum: Float = 0
        for i in 0..<frames {
            let sample = channel[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frames))
        return rms > 0 ? max(-160, 20 * log10(rms)) : -160
    }
}
