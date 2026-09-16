import SwiftUI
import AppKit

struct HistoryView: View {
    @Environment(HistoryStore.self) private var history
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(DictationEngine.self) private var engine

    @State private var query = ""
    @State private var expandedIDs: Set<UUID> = []

    private var filteredItems: [HistoryItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return history.items }
        return history.items.filter { item in
            item.text.localizedCaseInsensitiveContains(trimmed)
                || (item.filename?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History").font(.title2).bold()
                Spacer()
                Button("Clear All") { history.clear() }
                    .disabled(history.items.isEmpty)
            }

            TextField("Search history", text: $query)
                .textFieldStyle(.roundedBorder)

            if history.items.isEmpty {
                ContentUnavailableView(
                    "No transcriptions yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Your dictations and file transcriptions will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredItems.isEmpty {
                ContentUnavailableView.search(text: query)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredItems) { item in
                        HistoryRow(
                            item: item,
                            isExpanded: expandedIDs.contains(item.id),
                            onToggleExpand: { toggleExpanded(item.id) },
                            onCopy: { copy(item.text) },
                            onInsert: { insert(item.text) },
                            onDelete: { history.remove(id: item.id) }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .onAppear {
            history.prune(olderThan: settingsStore.settings.historyExpiry)
        }
    }

    private func toggleExpanded(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Hand focus back to the previously frontmost app, then inject there.
    private func insert(_ text: String) {
        NSApp.hide(nil)
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            engine.insert(text: text)
        }
    }
}

private struct HistoryRow: View {
    let item: HistoryItem
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onCopy: () -> Void
    let onInsert: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.text)
                .lineLimit(isExpanded ? nil : 3)
                .textSelection(.enabled)
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleExpand)
            HStack(spacing: 8) {
                Label(item.source == .file ? (item.filename ?? "File") : "Microphone",
                      systemImage: item.source == .file ? "doc" : "mic")
                Text(item.date, style: .date)
                Text(item.date, style: .time)
                Spacer()
                Button("Insert", action: onInsert).buttonStyle(.borderless)
                Button("Copy", action: onCopy).buttonStyle(.borderless)
                Button("Delete", role: .destructive, action: onDelete).buttonStyle(.borderless)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
