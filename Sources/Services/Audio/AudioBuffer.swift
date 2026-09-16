import Foundation
import AVFoundation

/// A safe-to-hand-off wrapper around a non-`Sendable` `AVAudioPCMBuffer`.
///
/// The capture tap produces a fresh deep copy for each value, and each value is
/// consumed exactly once downstream, so sharing across concurrency domains is
/// safe in practice — hence `@unchecked Sendable`.
struct AudioBuffer: @unchecked Sendable {
    let pcm: AVAudioPCMBuffer
}

extension AVAudioPCMBuffer {
    /// Deep-copies this buffer's frames into a new buffer of the same format.
    /// Required because audio-tap buffers are only valid during the callback.
    func deepCopy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            return nil
        }
        copy.frameLength = frameLength
        let channels = Int(format.channelCount)
        let frames = Int(frameLength)
        if let src = floatChannelData, let dst = copy.floatChannelData {
            for ch in 0..<channels {
                dst[ch].update(from: src[ch], count: frames)
            }
        } else if let src = int16ChannelData, let dst = copy.int16ChannelData {
            for ch in 0..<channels {
                dst[ch].update(from: src[ch], count: frames)
            }
        }
        return copy
    }
}
