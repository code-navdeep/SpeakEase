import Foundation

/// Whether on-device text enhancement can run right now.
enum EnhancementAvailability: Equatable {
    case available
    /// Not usable; carries a user-facing reason.
    case unavailable(String)

    var isAvailable: Bool { self == .available }
}

/// Abstraction over the text-rewriting model. Concrete implementation is
/// Apple's Foundation Models; the rest of the app depends only on this.
protocol EnhancementService: Sendable {
    func availability() async -> EnhancementAvailability

    /// Rewrite `text` according to `instructions`. Returns the rewritten text.
    func enhance(text: String, instructions: String) async throws -> String
}
