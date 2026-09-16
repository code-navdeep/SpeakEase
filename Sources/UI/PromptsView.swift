import SwiftUI

struct PromptsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(DictationEngine.self) private var engine

    @State private var availabilityNote: String?
    @State private var editing: Prompt?
    @State private var isAdding = false

    var body: some View {
        @Bindable var store = settingsStore

        VStack(alignment: .leading, spacing: 12) {
            Text("Enhancement Prompts").font(.title2).bold()

            Toggle("Enhance transcripts before inserting", isOn: $store.settings.enhancementEnabled)
                .toggleStyle(.switch)

            if let note = availabilityNote {
                Label(note, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            Text("When on, the active prompt rewrites your transcript using Apple's on-device model before it's inserted.")
                .font(.callout).foregroundStyle(.secondary)

            HStack {
                Text("Prompts").font(.headline)
                Spacer()
                Button {
                    isAdding = true
                } label: {
                    Label("New Prompt", systemImage: "plus")
                }
            }

            List {
                ForEach(store.settings.prompts) { prompt in
                    PromptRow(
                        prompt: prompt,
                        isActive: store.settings.activePromptID == prompt.id,
                        onSelect: { settingsStore.selectPrompt(id: prompt.id) },
                        onEdit: { editing = prompt },
                        onDelete: { settingsStore.deletePrompt(id: prompt.id) }
                    )
                }
            }
            .listStyle(.inset)
        }
        .padding()
        .task {
            let availability = await engine.enhancementAvailability()
            if case .unavailable(let reason) = availability { availabilityNote = reason }
        }
        .sheet(isPresented: $isAdding) {
            PromptEditor(title: "New Prompt") { label, instructions in
                _ = settingsStore.addPrompt(label: label, instructions: instructions)
            }
        }
        .sheet(item: $editing) { prompt in
            PromptEditor(title: "Edit Prompt", prompt: prompt) { label, instructions in
                settingsStore.updatePrompt(Prompt(id: prompt.id, label: label, instructions: instructions))
            }
        }
    }
}

private struct PromptRow: View {
    let prompt: Prompt
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(prompt.label).font(.headline)
                    if isActive {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                Text(prompt.instructions.isEmpty ? "No instructions" : prompt.instructions)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            if !isActive {
                Button("Use", action: onSelect).buttonStyle(.borderless)
            }
            Button("Edit", action: onEdit).buttonStyle(.borderless)
            Button("Delete", role: .destructive, action: onDelete).buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

private struct PromptEditor: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var prompt: Prompt?
    let onSave: (String, String) -> Void

    @State private var label = ""
    @State private var instructions = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2).bold()
            TextField("Name", text: $label).textFieldStyle(.roundedBorder)
            Text("Instructions").font(.headline)
            TextEditor(text: $instructions)
                .frame(minHeight: 120)
                .border(.quaternary)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    onSave(label, instructions)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 420, height: 320)
        .onAppear {
            if let prompt {
                label = prompt.label
                instructions = prompt.instructions
            }
        }
    }
}
