import Foundation
import Observation

/// Observable owner of `Settings`. Persists the whole struct as one JSON blob.
@MainActor
@Observable
final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "settings.v1"

    var settings: AppSettings {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           var decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            // Normalize to BCP-47 ("en-US") so the value always matches the
            // Language picker's tags, which come from SpeechTranscriber.
            decoded.localeIdentifier = Locale(identifier: decoded.localeIdentifier).identifier(.bcp47)
            self.settings = decoded
        } else {
            self.settings = .default
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    // MARK: - Prompt management

    func addPrompt(label: String, instructions: String) -> Prompt {
        let prompt = Prompt(label: label, instructions: instructions)
        settings.prompts.append(prompt)
        if settings.activePromptID == nil {
            settings.activePromptID = prompt.id
        }
        return prompt
    }

    func updatePrompt(_ prompt: Prompt) {
        guard let index = settings.prompts.firstIndex(where: { $0.id == prompt.id }) else { return }
        settings.prompts[index] = prompt
    }

    func deletePrompt(id: UUID) {
        settings.prompts.removeAll { $0.id == id }
        if settings.activePromptID == id {
            settings.activePromptID = settings.prompts.first?.id
        }
    }

    func selectPrompt(id: UUID) {
        guard settings.prompts.contains(where: { $0.id == id }) else { return }
        settings.activePromptID = id
    }

    func resetToDefaults() {
        settings = .default
    }

    // MARK: - Vocabulary management

    @discardableResult
    func addRule(find: String, replace: String, wholeWord: Bool, caseSensitive: Bool) -> VocabularyRule {
        let rule = VocabularyRule(find: find, replace: replace, wholeWord: wholeWord, caseSensitive: caseSensitive)
        settings.vocabulary.append(rule)
        return rule
    }

    func updateRule(_ rule: VocabularyRule) {
        guard let index = settings.vocabulary.firstIndex(where: { $0.id == rule.id }) else { return }
        settings.vocabulary[index] = rule
    }

    func deleteRule(id: UUID) {
        settings.vocabulary.removeAll { $0.id == id }
    }
}
