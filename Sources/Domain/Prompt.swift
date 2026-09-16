import Foundation

/// A reusable enhancement instruction applied to a transcript before injection.
/// `instructions` is fed to Foundation Models as the session's guidance.
struct Prompt: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var label: String
    var instructions: String

    init(id: UUID = UUID(), label: String, instructions: String) {
        self.id = id
        self.label = label
        self.instructions = instructions
    }
}

extension Prompt {
    /// Seed prompts offered on first launch.
    static let defaults: [Prompt] = [
        Prompt(label: "Clean up", instructions: "Fix grammar, punctuation, and capitalization. Preserve the original meaning and tone. Return only the corrected text."),
        Prompt(label: "Professional email", instructions: "Rewrite the text as a clear, professional email body. Return only the email text."),
        Prompt(label: "Bullet points", instructions: "Convert the text into concise bullet points. Return only the bullet points.")
    ]
}
