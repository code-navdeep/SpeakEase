import Foundation
import FoundationModels
import os

/// `EnhancementService` backed by Apple's on-device Foundation Models.
/// Degrades gracefully: when the system model is unavailable, callers get a
/// clear reason and fall back to the raw transcript.
actor FoundationModelEnhancer: EnhancementService {

    func availability() async -> EnhancementAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(Self.message(for: reason))
        @unknown default:
            return .unavailable("Text enhancement is unavailable on this device.")
        }
    }

    func enhance(text: String, instructions: String) async throws -> String {
        guard case .available = SystemLanguageModel.default.availability else {
            let availability = await availability()
            if case .unavailable(let reason) = availability {
                throw DictationError.modelUnavailable(reason)
            }
            throw DictationError.modelUnavailable("Text enhancement is unavailable.")
        }

        // Combine the user's instruction with a guardrail so the model returns
        // only the transformed text, not commentary.
        let sessionInstructions = """
        \(instructions)

        Apply the instruction above to the user's text. Return only the resulting \
        text with no preamble, explanation, or quotation marks.
        """

        do {
            let session = LanguageModelSession(instructions: sessionInstructions)
            let response = try await session.respond(to: text)
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isEmpty ? text : result
        } catch {
            Log.enhancement.error("Enhancement failed: \(error.localizedDescription, privacy: .public)")
            throw DictationError.enhancementFailed(error.localizedDescription)
        }
    }

    private static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence, so text enhancement is unavailable."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in System Settings to use text enhancement."
        case .modelNotReady:
            return "The on-device model is still downloading. Try again shortly."
        @unknown default:
            return "Text enhancement is unavailable on this device."
        }
    }
}
