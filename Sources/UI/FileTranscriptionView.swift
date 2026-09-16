import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct FileTranscriptionView: View {
    @Environment(DictationEngine.self) private var engine

    @State private var isImporting = false
    @State private var isWorking = false
    @State private var result = ""
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcribe an Audio File").font(.title2).bold()
            Text("Pick an audio file to transcribe with the same on-device engine.")
                .font(.callout).foregroundStyle(.secondary)

            HStack {
                Button {
                    isImporting = true
                } label: {
                    Label("Choose File…", systemImage: "folder")
                }
                .disabled(isWorking)

                if isWorking {
                    ProgressView().controlSize(.small)
                    Text("Transcribing…").foregroundStyle(.secondary)
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage).foregroundStyle(.red).font(.callout)
            }

            if !result.isEmpty {
                Divider()
                HStack {
                    Text("Result").font(.headline)
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result, forType: .string)
                    }
                }
                ScrollView {
                    Text(result)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { outcome in
            switch outcome {
            case .success(let urls):
                if let url = urls.first { transcribe(url) }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func transcribe(_ url: URL) {
        isWorking = true
        errorMessage = ""
        result = ""
        Task {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let outcome = await engine.transcribeFile(at: url)
            isWorking = false
            switch outcome {
            case .success(let text): result = text
            case .failure(let error): errorMessage = error.errorDescription ?? "Transcription failed."
            }
        }
    }
}
