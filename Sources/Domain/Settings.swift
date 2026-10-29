import Foundation
import Carbon.HIToolbox

/// How the global hotkey drives recording.
enum RecordingMode: String, Codable, CaseIterable {
    /// Press once to start, press again to stop.
    case toggle
    /// Record while the hotkey is held; stop on release.
    case pushToTalk

    var displayName: String {
        switch self {
        case .toggle: return "Toggle (press to start/stop)"
        case .pushToTalk: return "Push to talk (hold)"
        }
    }
}

/// Where the recording HUD appears on screen.
enum HUDPosition: String, Codable, CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}

/// How long completed transcriptions are kept in history before being pruned.
enum HistoryExpiry: Int, Codable, CaseIterable {
    case never, sevenDays, thirtyDays, ninetyDays

    var displayName: String {
        switch self {
        case .never: return "Never"
        case .sevenDays: return "7 Days"
        case .thirtyDays: return "30 Days"
        case .ninetyDays: return "90 Days"
        }
    }

    /// Retention window in days, or nil to keep items forever.
    var days: Int? {
        switch self {
        case .never: return nil
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        }
    }
}

/// How many recent transcriptions the menu-bar "Recent History" submenu shows.
enum MenuHistoryCount: Int, Codable, CaseIterable {
    case ten = 10, twenty = 20, fifty = 50, hundred = 100

    var displayName: String { "\(rawValue)" }
}

/// How long after inserting text the clipboard is automatically cleared.
enum ClipboardAutoClear: Int, Codable, CaseIterable {
    case off, thirtySeconds, sixtySeconds, twoMinutes

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .thirtySeconds: return "30s"
        case .sixtySeconds: return "60s"
        case .twoMinutes: return "2 min"
        }
    }

    /// Delay before clearing the clipboard, or nil to leave it untouched.
    var seconds: TimeInterval? {
        switch self {
        case .off: return nil
        case .thirtySeconds: return 30
        case .sixtySeconds: return 60
        case .twoMinutes: return 120
        }
    }
}

/// A global hotkey binding. `keyCode` is a virtual key code (`kVK_*`);
/// `modifierFlags` is an `NSEvent.ModifierFlags` raw value.
struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt16
    var modifierFlags: UInt

    /// Default: ⌥ Space.
    static let `default` = HotkeyBinding(
        keyCode: UInt16(kVK_Space),
        modifierFlags: 1 << 19 // NSEvent.ModifierFlags.option.rawValue
    )
}

/// All persisted user preferences as one value type (one Codable round-trip).
struct AppSettings: Codable, Equatable {
    var localeIdentifier: String
    var recordingMode: RecordingMode
    var hotkey: HotkeyBinding
    var hotkeyEnabled: Bool
    var enhancementEnabled: Bool
    var activePromptID: UUID?
    var prompts: [Prompt]
    var autoEnter: Bool
    var showHUD: Bool
    var hudPosition: HUDPosition
    var saveHistoryEnabled: Bool
    var historyExpiry: HistoryExpiry
    var menuHistoryCount: MenuHistoryCount
    var clipboardAutoClear: ClipboardAutoClear
    var restoreClipboard: Bool
    var vocabulary: [VocabularyRule]

    static let `default` = AppSettings(
        localeIdentifier: "en-US",
        recordingMode: .toggle,
        hotkey: .default,
        hotkeyEnabled: true,
        enhancementEnabled: false,
        activePromptID: nil,
        prompts: Prompt.defaults,
        autoEnter: false,
        showHUD: true,
        hudPosition: .topRight,
        saveHistoryEnabled: true,
        historyExpiry: .never,
        menuHistoryCount: .ten,
        clipboardAutoClear: .off,
        restoreClipboard: false,
        vocabulary: []
    )

    /// The instructions of the active prompt, or nil when enhancement is off
    /// or no prompt is selected.
    var activeInstructions: String? {
        guard enhancementEnabled, let id = activePromptID,
              let prompt = prompts.first(where: { $0.id == id }) else {
            return nil
        }
        let trimmed = prompt.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
