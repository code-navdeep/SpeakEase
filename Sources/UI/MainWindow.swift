import SwiftUI

/// The main utility window: History, file transcription, and prompts.
struct MainWindow: View {
    var body: some View {
        TabView {
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            FileTranscriptionView()
                .tabItem { Label("Audio File", systemImage: "doc.badge.plus") }
            PromptsView()
                .tabItem { Label("Prompts", systemImage: "text.bubble") }
            VocabularyView()
                .tabItem { Label("Vocabulary", systemImage: "character.book.closed") }
        }
        .padding()
    }
}
