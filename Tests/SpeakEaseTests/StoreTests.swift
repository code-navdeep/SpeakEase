import Testing
import Foundation
@testable import SpeakEase

private func isolatedDefaults() -> UserDefaults {
    let suite = "test-\(UUID().uuidString)"
    return UserDefaults(suiteName: suite)!
}

private func isolatedDirectory() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

@MainActor
struct SettingsStoreTests {
    @Test func startsFromDefaultsWhenEmpty() {
        let store = SettingsStore(defaults: isolatedDefaults())
        #expect(store.settings.recordingMode == .toggle)
        #expect(store.settings.prompts.count == Prompt.defaults.count)
        #expect(store.settings.menuHistoryCount == .ten)
        #expect(store.settings.restoreClipboard == false)
        #expect(store.settings.vocabulary.isEmpty)
        // BCP-47 form ("en-US"), matching the Language picker's tags.
        #expect(!store.settings.localeIdentifier.contains("_"))
    }

    @Test func persistsAcrossInstances() {
        let defaults = isolatedDefaults()
        let first = SettingsStore(defaults: defaults)
        first.settings.autoEnter = true
        first.settings.localeIdentifier = "fr_FR"

        let second = SettingsStore(defaults: defaults)
        #expect(second.settings.autoEnter == true)
        // Stored POSIX-form identifiers are normalized to BCP-47 on load.
        #expect(second.settings.localeIdentifier == "fr-FR")
    }

    @Test func addingPromptSelectsFirstWhenNoneActive() {
        let store = SettingsStore(defaults: isolatedDefaults())
        store.settings.prompts = []
        store.settings.activePromptID = nil

        let prompt = store.addPrompt(label: "Test", instructions: "Do the thing")
        #expect(store.settings.activePromptID == prompt.id)
    }

    @Test func deletingActivePromptReassignsSelection() {
        let store = SettingsStore(defaults: isolatedDefaults())
        let a = store.addPrompt(label: "A", instructions: "a")
        store.selectPrompt(id: a.id)
        store.deletePrompt(id: a.id)
        #expect(store.settings.activePromptID != a.id)
    }

    @Test func activeInstructionsRespectEnhancementToggle() {
        let store = SettingsStore(defaults: isolatedDefaults())
        let p = store.addPrompt(label: "Clean", instructions: "Fix grammar")
        store.selectPrompt(id: p.id)

        store.settings.enhancementEnabled = false
        #expect(store.settings.activeInstructions == nil)

        store.settings.enhancementEnabled = true
        #expect(store.settings.activeInstructions == "Fix grammar")
    }

    @Test func emptyInstructionsTreatedAsNoEnhancement() {
        let store = SettingsStore(defaults: isolatedDefaults())
        let p = store.addPrompt(label: "Blank", instructions: "   ")
        store.selectPrompt(id: p.id)
        store.settings.enhancementEnabled = true
        #expect(store.settings.activeInstructions == nil)
    }
}

@MainActor
struct HistoryStoreTests {
    @Test func addInsertsNewestFirst() {
        let store = HistoryStore(directory: isolatedDirectory())
        store.add(text: "one", source: .microphone)
        store.add(text: "two", source: .microphone)
        #expect(store.items.first?.text == "two")
        #expect(store.items.count == 2)
    }

    @Test func persistsAndReloads() {
        let directory = isolatedDirectory()
        let first = HistoryStore(directory: directory)
        first.add(text: "persisted", source: .file, filename: "a.m4a")

        let second = HistoryStore(directory: directory)
        #expect(second.items.first?.text == "persisted")
        #expect(second.items.first?.filename == "a.m4a")
    }

    @Test func clearRemovesEverything() {
        let store = HistoryStore(directory: isolatedDirectory())
        store.add(text: "x", source: .microphone)
        store.clear()
        #expect(store.items.isEmpty)
    }

    @Test func pruneRemovesItemsOlderThanExpiry() {
        let store = HistoryStore(directory: isolatedDirectory())
        store.add(text: "old", source: .microphone)
        store.add(text: "new", source: .microphone)
        store.prune(olderThan: .never)
        #expect(store.items.count == 2)
    }

    @Test func pruneRemovesOldItemsAndKeepsFresh() {
        let directory = isolatedDirectory()
        let store = HistoryStore(directory: directory)
        let oldDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        store.add(item: HistoryItem(text: "stale", source: .microphone, date: oldDate))
        store.add(text: "fresh", source: .microphone)

        store.prune(olderThan: .sevenDays)

        #expect(store.items.count == 1)
        #expect(store.items.first?.text == "fresh")

        // The pruned state must also be what persists.
        let reloaded = HistoryStore(directory: directory)
        #expect(reloaded.items.map(\.text) == ["fresh"])
    }
}

struct VocabularyRuleTests {
    @Test func wholeWordReplacementLeavesSubstringsAlone() {
        let rules = [VocabularyRule(find: "teh", replace: "the")]
        #expect(rules.apply(to: "teh cat ate tehran's food") == "the cat ate tehran's food")
    }

    @Test func caseInsensitiveByDefault() {
        let rules = [VocabularyRule(find: "speakease", replace: "SpeakEase")]
        #expect(rules.apply(to: "I use Speakease daily") == "I use SpeakEase daily")
    }

    @Test func caseSensitiveWhenRequested() {
        let rules = [VocabularyRule(find: "IT", replace: "Information Technology", caseSensitive: true)]
        #expect(rules.apply(to: "IT says it works") == "Information Technology says it works")
    }

    @Test func substringModeReplacesInsideWords() {
        let rules = [VocabularyRule(find: "colour", replace: "color", wholeWord: false)]
        #expect(rules.apply(to: "recolouring") == "recoloring")
    }

    @Test func regexMetacharactersAreLiteral() {
        let rules = [VocabularyRule(find: "c++", replace: "C++", wholeWord: false)]
        #expect(rules.apply(to: "I write c++ code") == "I write C++ code")
    }

    @Test func emptyFindIsSkipped() {
        let rules = [VocabularyRule(find: "", replace: "x")]
        #expect(rules.apply(to: "unchanged") == "unchanged")
    }
}

struct DictationStateTests {
    @Test func recordingExposesLiveTranscript() {
        let state = DictationState.recording(transcript: "hello")
        #expect(state.isRecording)
        #expect(state.isBusy)
        #expect(state.liveTranscript == "hello")
    }

    @Test func idleAndFailedAreNotBusy() {
        #expect(DictationState.idle.isBusy == false)
        #expect(DictationState.failed(.cancelled).isBusy == false)
    }

    @Test func transcribingIsBusyButNotRecording() {
        let state = DictationState.transcribing
        #expect(state.isBusy)
        #expect(state.isRecording == false)
        #expect(state.liveTranscript == nil)
    }
}
