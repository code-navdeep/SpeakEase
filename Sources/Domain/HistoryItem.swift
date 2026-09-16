import Foundation

enum TranscriptionSource: String, Codable {
    case microphone
    case file
}

/// A past transcription kept in the rolling history.
struct HistoryItem: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let text: String
    let source: TranscriptionSource
    let date: Date
    /// File name for file-sourced transcriptions; nil for microphone.
    let filename: String?

    init(id: UUID = UUID(), text: String, source: TranscriptionSource, date: Date = Date(), filename: String? = nil) {
        self.id = id
        self.text = text
        self.source = source
        self.date = date
        self.filename = filename
    }
}
