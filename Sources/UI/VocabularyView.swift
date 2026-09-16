import SwiftUI

struct VocabularyView: View {
    @Environment(SettingsStore.self) private var settingsStore

    @State private var editing: VocabularyRule?
    @State private var isAdding = false

    var body: some View {
        @Bindable var store = settingsStore

        VStack(alignment: .leading, spacing: 12) {
            Text("Vocabulary").font(.title2).bold()

            Text("Corrections applied to every transcript before it's enhanced or inserted — fix names and jargon the recognizer mishears.")
                .font(.callout).foregroundStyle(.secondary)

            HStack {
                Text("Rules").font(.headline)
                Spacer()
                Button {
                    isAdding = true
                } label: {
                    Label("New Rule", systemImage: "plus")
                }
            }

            if store.settings.vocabulary.isEmpty {
                ContentUnavailableView(
                    "No rules yet",
                    systemImage: "character.book.closed",
                    description: Text("Add a rule like “teh → the” or “speak ease → SpeakEase”.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.settings.vocabulary) { rule in
                        VocabularyRow(
                            rule: rule,
                            onEdit: { editing = rule },
                            onDelete: { settingsStore.deleteRule(id: rule.id) }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .sheet(isPresented: $isAdding) {
            VocabularyEditor(title: "New Rule") { find, replace, wholeWord, caseSensitive in
                settingsStore.addRule(find: find, replace: replace, wholeWord: wholeWord, caseSensitive: caseSensitive)
            }
        }
        .sheet(item: $editing) { rule in
            VocabularyEditor(title: "Edit Rule", rule: rule) { find, replace, wholeWord, caseSensitive in
                settingsStore.updateRule(VocabularyRule(
                    id: rule.id, find: find, replace: replace,
                    wholeWord: wholeWord, caseSensitive: caseSensitive
                ))
            }
        }
    }
}

private struct VocabularyRow: View {
    let rule: VocabularyRule
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(rule.find) → \(rule.replace)")
                    .font(.headline)
                HStack(spacing: 8) {
                    if rule.wholeWord { Text("Whole word") }
                    if rule.caseSensitive { Text("Case-sensitive") }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit", action: onEdit).buttonStyle(.borderless)
            Button("Delete", role: .destructive, action: onDelete).buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

private struct VocabularyEditor: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var rule: VocabularyRule?
    let onSave: (String, String, Bool, Bool) -> Void

    @State private var find = ""
    @State private var replace = ""
    @State private var wholeWord = true
    @State private var caseSensitive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2).bold()
            TextField("Find", text: $find).textFieldStyle(.roundedBorder)
            TextField("Replace with", text: $replace).textFieldStyle(.roundedBorder)
            Toggle("Match whole words only", isOn: $wholeWord)
            Toggle("Case-sensitive", isOn: $caseSensitive)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    onSave(find, replace, wholeWord, caseSensitive)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(find.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 420, height: 240)
        .onAppear {
            if let rule {
                find = rule.find
                replace = rule.replace
                wholeWord = rule.wholeWord
                caseSensitive = rule.caseSensitive
            }
        }
    }
}
