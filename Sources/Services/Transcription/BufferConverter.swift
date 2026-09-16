import Foundation
@preconcurrency import AVFoundation
import os

/// Converts microphone PCM buffers to the format the speech analyzer requires.
/// Reused across buffers; recreates the underlying converter only if a format
/// changes. Not `Sendable` — used within a single transcription task.
final class BufferConverter {
    private var converter: AVAudioConverter?

    func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        if inputFormat == format { return buffer }

        if converter == nil || converter?.inputFormat != inputFormat || converter?.outputFormat != format {
            converter = AVAudioConverter(from: inputFormat, to: format)
            converter?.primeMethod = .none
        }
        guard let converter else {
            throw DictationError.transcriptionFailed("Could not create audio converter.")
        }

        let ratio = format.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1)
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw DictationError.transcriptionFailed("Could not allocate conversion buffer.")
        }

        let fed = OSAllocatedUnfairLock(initialState: false)
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            let alreadyFed = fed.withLock { current -> Bool in
                let was = current
                current = true
                return was
            }
            if alreadyFed {
                status.pointee = .noDataNow
                return nil
            }
            status.pointee = .haveData
            return buffer
        }
        if let conversionError {
            throw DictationError.transcriptionFailed(conversionError.localizedDescription)
        }
        return output
    }
}
